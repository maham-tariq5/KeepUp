import 'dart:async';

/// Represents the simplified location data produced by the service.
/// Use this instead of a plugin-specific Position type in app logic.
class LocationPosition {
  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Estimated horizontal accuracy in meters, or `null` if unknown.
  final double? accuracyMeters;

  /// Speed in meters/second, or `null` when not available.
  final double? speedMetersPerSecond;

  /// Heading / bearing in degrees, or `null` if unavailable.
  final double? headingDegrees;

  /// Timestamp for when this sample was captured.
  final DateTime timestamp;

  const LocationPosition({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'LocationPosition(lat: $latitude, lon: $longitude, speed: $speedMetersPerSecond, acc: $accuracyMeters)';
  }
}

/// High-level state of the location service. Consumers can react to these.
enum LocationServiceState {
  /// Service is not tracking (initial state).
  idle,

  /// Service is requesting permission from the user.
  requestingPermission,

  /// Service actively tracking and emitting location updates.
  tracking,

  /// Tracking paused (e.g., user pressed pause or app requested pause).
  paused,

  /// Service has been stopped / ended.
  stopped,

  /// A recoverable error (like permission denied or GPS disabled).
  error,
}

/// A lightweight error description produced by implementations when something
/// goes wrong. Keep it small and serializable for logging.
class LocationServiceError {
  final String code; // short error id, e.g. 'permission_denied'
  final String message; // human-friendly message

  LocationServiceError({required this.code, required this.message});

  @override
  String toString() => 'LocationServiceError($code): $message';
}

/// Interface / contract for location providers used across the app.
///
/// Implementations should:
///  - Translate plugin types into [LocationPosition].
///  - Emit smooth, debounced updates if desired (or leave raw updates).
///  - Not perform UI work or import Flutter widgets.
abstract class ILocationService {
  /// Stream of position updates. Broadcast so multiple listeners can subscribe.
  ///
  /// Implementations should:
  ///  - emit at a steady cadence (e.g., 1Hz or as configured),
  ///  - drop noisy/invalid points (e.g., accuracy too low) or mark them clearly.
  Stream<LocationPosition> get positionStream;

  /// Stream of high-level service state changes (tracking, paused, error, etc.)
  Stream<LocationServiceState> get stateStream;

  /// Stream of errors produced by the service.
  /// Implementations can emit errors like `permission_denied`, `gps_disabled`, etc.
  Stream<LocationServiceError?> get errorStream;

  /// Returns the most recently emitted position if available, otherwise null.
  LocationPosition? get lastPosition;

  /// Request necessary location permissions from the user.
  ///
  /// Returns `true` if permissions are granted (while-in-use or always as your
  /// app requires). Implementations must set stateStream appropriately.
  Future<bool> requestPermission();

  /// Returns whether location services (GPS) are enabled on the device.
  Future<bool> isLocationServiceEnabled();

  /// Start active location tracking. Should:
  ///  - check / request permissions if needed,
  ///  - begin emitting `positionStream`,
  ///  - set `stateStream` to `tracking`.
  ///
  /// Implementations should throw or emit an error via [errorStream] if
  /// tracking cannot be started.
  Future<void> start();

  /// Pause tracking (keep internal state so `resume()` can restart quickly).
  Future<void> pause();

  /// Resume tracking after a pause.
  Future<void> resume();

  /// Stop tracking and release resources. After stop, start() may be called again.
  Future<void> stop();

  /// Clean up any internal resources and close streams. After dispose, the
  /// instance is considered unusable.
  Future<void> dispose();

  /// Inject a test position (for testing/debugging purposes).
  /// Not all implementations may support this.
  void injectTestPosition(LocationPosition position) {
    // Default: no-op. Implementations can override.
  }
}
