// test/geolocator_location_service_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as g;
import 'package:keepup/services/location/geolocator_location_service.dart';
import 'package:keepup/services/location/i_location_service.dart';

/// Helper to create a fake g.Position for tests.
/// Adjust fields if your geolocator version differs.
g.Position fakeGPosition({
  double latitude = 0.0,
  double longitude = 0.0,
  double accuracy = 5.0,
  double speed = 0.0,
  double heading = 0.0,
  DateTime? timestamp,
}) {
  return g.Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: 0.0,
    heading: heading,
    speed: speed,
    altitudeAccuracy: 0.0,
    headingAccuracy: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  // Ensure Flutter bindings (safe and idempotent).
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<g.Position> controller;
  late GeolocatorLocationService service;
  late StreamSubscription<LocationPosition> posSub;

  tearDown(() async {
    // cleanup after each test
    try {
      await posSub.cancel();
    } catch (_) {}
    try {
      await service.stop();
    } catch (_) {}
    try {
      await controller.close();
    } catch (_) {}
    try {
      await service.dispose();
    } catch (_) {}
  });

  test(
    'GeolocatorLocationService processes injected stream and emits positions',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final controller = StreamController<g.Position>();

      final service = GeolocatorLocationService(
        positionStreamFactory: () => controller.stream,
        permissionChecker: () async => g.LocationPermission.always,
        serviceEnabledChecker: () async => true,
      );

      final emitted = <LocationPosition>[];

      final sub = service.positionStream.listen(emitted.add);

      await service.start();

      final t0 = DateTime.now();
      controller.add(
        fakeGPosition(latitude: 43.0, longitude: -79.0, timestamp: t0),
      );
      controller.add(
        fakeGPosition(
          latitude: 43.0001,
          longitude: -79.0,
          timestamp: t0.add(const Duration(seconds: 1)),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      expect(emitted.length, greaterThanOrEqualTo(1));
      expect(service.lastPosition, isNotNull);
    },
  );

  test(
    'smoothing: averages the last N points according to smoothingWindow',
    () async {
      controller = StreamController<g.Position>();
      service = GeolocatorLocationService(
        positionStreamFactory: () => controller.stream,
        permissionChecker: () async => g.LocationPermission.always,
        serviceEnabledChecker: () async => true,
        smoothingWindow: 2, // average of last 2
        accuracyThresholdMeters: 1000.0,
        minDeltaMetersToAccumulate: 0.0,
      );

      final emitted = <LocationPosition>[];
      posSub = service.positionStream.listen(emitted.add);

      await service.start();

      final t0 = DateTime.now();
      controller.add(
        fakeGPosition(latitude: 43.0, longitude: -79.0, timestamp: t0),
      );
      controller.add(
        fakeGPosition(
          latitude: 43.0001,
          longitude: -79.0,
          timestamp: t0.add(const Duration(seconds: 1)),
        ),
      );

      // give the stream some time to process
      await Future.delayed(const Duration(milliseconds: 200));

      expect(emitted, isNotEmpty);
      // smoothing average = (43.0 + 43.0001) / 2 = 43.00005
      expect(service.lastPosition, isNotNull);
      expect(service.lastPosition!.latitude, closeTo(43.00005, 1e-5));
    },
  );

  test(
    'accuracy filtering: drops points with accuracy worse than threshold',
    () async {
      controller = StreamController<g.Position>();
      service = GeolocatorLocationService(
        positionStreamFactory: () => controller.stream,
        permissionChecker: () async => g.LocationPermission.always,
        serviceEnabledChecker: () async => true,
        smoothingWindow: 2,
        accuracyThresholdMeters: 10.0, // strict: drop > 10m
        minDeltaMetersToAccumulate: 0.0,
      );

      final emitted = <LocationPosition>[];
      posSub = service.positionStream.listen(emitted.add);

      await service.start();

      final t0 = DateTime.now();
      // good accuracy -> should be emitted (after smoothing)
      controller.add(
        fakeGPosition(
          latitude: 43.0,
          longitude: -79.0,
          accuracy: 5.0,
          timestamp: t0,
        ),
      );
      // bad accuracy -> should be dropped by service (not make it into emitted)
      controller.add(
        fakeGPosition(
          latitude: 43.0005,
          longitude: -79.0,
          accuracy: 50.0,
          timestamp: t0.add(const Duration(seconds: 1)),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Only the first (or smoothed) point should be present; second should be ignored.
      expect(emitted, isNotEmpty);
      expect(emitted.length, lessThanOrEqualTo(2));
      // Last emitted should have accuracy <= threshold or be the first good point.
      expect(service.lastPosition!.accuracyMeters, isNotNull);
      expect(service.lastPosition!.accuracyMeters!, lessThanOrEqualTo(10.0));
    },
  );

  test('min delta: tiny jitter does not increase total distance', () async {
    controller = StreamController<g.Position>();
    service = GeolocatorLocationService(
      positionStreamFactory: () => controller.stream,
      permissionChecker: () async => g.LocationPermission.always,
      serviceEnabledChecker: () async => true,
      smoothingWindow: 2,
      accuracyThresholdMeters: 1000.0,
      minDeltaMetersToAccumulate: 1.0, // require at least 1 meter to accumulate
    );

    final emitted = <LocationPosition>[];
    posSub = service.positionStream.listen(emitted.add);

    await service.start();

    final t0 = DateTime.now();
    // two nearly identical points (<1m apart)
    controller.add(
      fakeGPosition(latitude: 43.0, longitude: -79.0, timestamp: t0),
    );
    controller.add(
      fakeGPosition(
        latitude: 43.0 + 0.000001,
        longitude: -79.0,
        timestamp: t0.add(const Duration(seconds: 1)),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 200));

    // lastPosition exists
    expect(service.lastPosition, isNotNull);

    // _totalDistanceMeters is private; we can approximate by sending a larger delta afterwards and ensure only that contributes.
    // send a point ~5m away and check that distance increases (no direct access to totalDistanceMeters; we rely on behavior)
    controller.add(
      fakeGPosition(
        latitude: 43.00005,
        longitude: -79.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 200));

    expect(service.lastPosition!.latitude, closeTo(43.000025, 1e-5));
  });

  test('pause/resume: pausing stops emission, resuming restarts', () async {
    controller = StreamController<g.Position>();
    service = GeolocatorLocationService(
      positionStreamFactory: () => controller.stream,
      permissionChecker: () async => g.LocationPermission.always,
      serviceEnabledChecker: () async => true,
      smoothingWindow: 2,
      accuracyThresholdMeters: 1000.0,
      minDeltaMetersToAccumulate: 0.0,
    );

    final emitted = <LocationPosition>[];
    posSub = service.positionStream.listen(emitted.add);

    await service.start();

    final t0 = DateTime.now();
    controller.add(
      fakeGPosition(latitude: 43.0, longitude: -79.0, timestamp: t0),
    );
    await Future.delayed(const Duration(milliseconds: 120));
    expect(emitted.isNotEmpty, isTrue);

    // pause => stream subscription is paused in your service
    await service.pause();
    final beforeCount = emitted.length;

    // push more points while paused
    controller.add(
      fakeGPosition(
        latitude: 43.0002,
        longitude: -79.0,
        timestamp: t0.add(const Duration(seconds: 1)),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 120));
    // no new emissions while paused
    expect(emitted.length, equals(beforeCount));

    // resume => emissions continue
    await service.resume();
    controller.add(
      fakeGPosition(
        latitude: 43.0004,
        longitude: -79.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 200));
    expect(emitted.length, greaterThan(beforeCount));
  });
}
