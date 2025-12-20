import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart' as g;
import 'i_location_service.dart';

/// Geolocator-backed implementation of [ILocationService].
class GeolocatorLocationService implements ILocationService {
  // Controllers (broadcast so many listeners can subscribe)
  final _positionController = StreamController<LocationPosition>.broadcast();
  final _stateController = StreamController<LocationServiceState>.broadcast();
  final _errorController = StreamController<LocationServiceError?>.broadcast();

  final Stream<g.Position> Function()? _positionStreamFactory;
  final Future<g.LocationPermission> Function()? _permissionChecker;
  final Future<bool> Function()? _serviceEnabledChecker;

  // Subscription to the plugin stream
  StreamSubscription<g.Position>? _geoSub;

  // Internal buffer for smoothing positions
  final List<LocationPosition> _recentPositions = [];

  LocationPosition? _lastEmitted;

  @override
  LocationPosition? get lastPosition => _lastEmitted;

  // Internal bookkeeping (not exposed by the interface)
  DateTime? _startTime;
  double _totalDistanceMeters = 0.0;

  // Configuration (tweakable)
  final int smoothingWindow;
  final double accuracyThresholdMeters;
  final double minDeltaMetersToAccumulate;

  // Exposed streams required by ILocationService
  @override
  Stream<LocationPosition> get positionStream => _positionController.stream;

  @override
  Stream<LocationServiceState> get stateStream => _stateController.stream;

  @override
  Stream<LocationServiceError?> get errorStream => _errorController.stream;

  @override
  Future<bool> isLocationServiceEnabled() =>
      _serviceEnabledChecker?.call() ?? g.Geolocator.isLocationServiceEnabled();

  GeolocatorLocationService({
    this.smoothingWindow = 4,
    this.accuracyThresholdMeters = 50.0,
    this.minDeltaMetersToAccumulate = 0.3,
    Stream<g.Position> Function()? positionStreamFactory,
    Future<g.LocationPermission> Function()? permissionChecker,
    Future<bool> Function()? serviceEnabledChecker,
  }) : _positionStreamFactory = positionStreamFactory,
       _permissionChecker = permissionChecker,
       _serviceEnabledChecker = serviceEnabledChecker;

  @override
  Future<bool> requestPermission() async {
    _stateController.add(LocationServiceState.requestingPermission);

    try {
      var perm =
          await (_permissionChecker?.call() ?? g.Geolocator.checkPermission());
      if (perm == g.LocationPermission.denied) {
        perm = await g.Geolocator.requestPermission();
      }

      if (perm == g.LocationPermission.denied ||
          perm == g.LocationPermission.deniedForever) {
        final err = LocationServiceError(
          code: 'permission_denied',
          message: 'Location Permission Denied',
        );
        _errorController.add(err);
        _stateController.add(LocationServiceState.error);
        return false;
      }

      _errorController.add(null);
      _stateController.add(LocationServiceState.idle);
      return true;
    } catch (e) {
      final err = LocationServiceError(
        code: 'permission_error',
        message: 'Permission request failed: $e',
      );
      _errorController.add(err);
      _stateController.add(LocationServiceState.error);
      return false;
    }
  }

  // @override
  // Future<bool> isLocationServiceEnabled() =>
  //     g.Geolocator.isLocationServiceEnabled();

  @override
  Future<void> start() async {
    // Request permission first (this also sets state)
    _stateController.add(LocationServiceState.requestingPermission);
    final granted = await requestPermission();
    if (!granted) return;

    final enabled = await isLocationServiceEnabled();
    if (!enabled) {
      final err = LocationServiceError(
        code: 'gps_disabled',
        message: 'Location services are disabled.',
      );
      _errorController.add(err);
      _stateController.add(LocationServiceState.error);
      return;
    }

    _startTime = DateTime.now();
    _totalDistanceMeters = 0.0;
    _recentPositions.clear();
    _lastEmitted = null;
    _errorController.add(null);
    _stateController.add(LocationServiceState.tracking);

    // Subscribe to Geolocator's position stream
    _geoSub =
        (_positionStreamFactory?.call() ??
                g.Geolocator.getPositionStream(
                  locationSettings: const g.LocationSettings(
                    accuracy: g.LocationAccuracy.best,
                    distanceFilter:
                        1, // 1 meter; tune for battery/perf tradeoff
                  ),
                ))
            .listen(
              _onGeoPosition,
              onError: (err) {
                final error = LocationServiceError(
                  code: 'gps_stream_error',
                  message: 'GPS stream error: $err',
                );
                _errorController.add(error);
                _stateController.add(LocationServiceState.error);
              },
            );
  }

  @override
  Future<void> pause() async {
    if (_geoSub != null) {
      _geoSub!.pause();
      _stateController.add(LocationServiceState.paused);
    }
  }

  @override
  Future<void> resume() async {
    if (_geoSub != null) {
      _geoSub!.resume();
      _stateController.add(LocationServiceState.tracking);
    } else {
      // If there's no subscription (e.g., after stop), start fresh
      await start();
    }
  }

  @override
  Future<void> stop() async {
    _stateController.add(LocationServiceState.stopped);
    await _geoSub?.cancel();
    _geoSub = null;
  }

  @override
  Future<void> dispose() async {
    await _geoSub?.cancel();
    await _stateController.close();
    await _positionController.close();
    await _errorController.close();
  }

  @override
  void injectTestPosition(LocationPosition position) {
    // Directly emit to the position stream for testing
    _positionController.add(position);
    _lastEmitted = position;
  }

  void _onGeoPosition(g.Position raw) {
    try {
      final lp = _convertToLocationPosition(raw);

      // If we have accuracy info and it's too poor, skip this point.
      if (lp.accuracyMeters != null &&
          lp.accuracyMeters! > accuracyThresholdMeters) {
        // skip noisy point
        return;
      }

      // Add to smoothing buffer
      _recentPositions.add(lp);
      if (_recentPositions.length > smoothingWindow) {
        _recentPositions.removeAt(0);
      }

      final smoothed = _computeSmoothedPosition(_recentPositions);

      // Update distance using last emitted position
      if (_lastEmitted != null) {
        final d = _haversineDistance(
          _lastEmitted!.latitude,
          _lastEmitted!.longitude,
          smoothed.latitude,
          smoothed.longitude,
        );

        if (d.isFinite && d > minDeltaMetersToAccumulate) {
          _totalDistanceMeters += d;
        }
      }

      _positionController.add(smoothed);
      _lastEmitted = smoothed;
    } catch (e) {
      final err = LocationServiceError(
        code: 'processing_error',
        message: 'Error processing GPS sample: $e',
      );
      _errorController.add(err);
      _stateController.add(LocationServiceState.error);
    }
  }

  LocationPosition _convertToLocationPosition(g.Position p) {
    return LocationPosition(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracyMeters: p.accuracy,
      speedMetersPerSecond: (p.speed.isFinite && p.speed >= 0) ? p.speed : null,
      headingDegrees: (p.heading.isFinite && p.heading >= 0) ? p.heading : null,
      timestamp: p.timestamp,
    );
  }

  LocationPosition _computeSmoothedPosition(List<LocationPosition> buffer) {
    if (buffer.isEmpty) {
      throw StateError('No positions to smooth');
    }

    double latSum = 0.0, lonSum = 0.0;
    double speedSum = 0.0;
    int speedCount = 0;
    double accSum = 0.0;
    int accCount = 0;
    DateTime latestTs = buffer.last.timestamp;
    double? latestHeading = buffer.last.headingDegrees;

    for (var p in buffer) {
      latSum += p.latitude;
      lonSum += p.longitude;
      if (p.speedMetersPerSecond != null) {
        speedSum += p.speedMetersPerSecond!;
        speedCount++;
      }
      if (p.accuracyMeters != null) {
        accSum += p.accuracyMeters!;
        accCount++;
      }
    }

    final n = buffer.length;
    return LocationPosition(
      latitude: latSum / n,
      longitude: lonSum / n,
      accuracyMeters: accCount > 0 ? (accSum / accCount) : null,
      speedMetersPerSecond: speedCount > 0 ? (speedSum / speedCount) : null,
      headingDegrees: latestHeading,
      timestamp: latestTs,
    );
  }

  double _degToRad(double deg) => deg * (pi / 180.0);

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
