import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as g;

import 'package:keepup/services/location/geolocator_location_service.dart';
import 'package:keepup/services/location/i_location_service.dart';
import 'package:keepup/services/pace/pace_smoother.dart';
import 'package:keepup/services/pace/pace_calc.dart';

/// Helper to create a fake g.Position (same as geolocator_location_service_test.dart)
g.Position fakeGPos({
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
    accuracy: accuracy,
    timestamp: timestamp ?? DateTime.now(),
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: heading,
    headingAccuracy: 0.0,
    speed: speed,
    speedAccuracy: 0.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<g.Position> controller;
  late GeolocatorLocationService locationService;
  late PaceSmoother paceSmoother;

  StreamSubscription<PaceResult>? paceSub;

  tearDown(() async {
    await paceSub?.cancel();
    await paceSmoother.dispose();
    await locationService.dispose();
    await controller.close();
  });

  test('PaceSmoother calculates correct pace from fake GPS speeds', () async {
    controller = StreamController<g.Position>();

    // Inject fake GPS stream
    locationService = GeolocatorLocationService(
      positionStreamFactory: () => controller.stream,
      permissionChecker: () async => g.LocationPermission.always,
      serviceEnabledChecker: () async => true,
      smoothingWindow: 1, // let pace smoother handle smoothing
      accuracyThresholdMeters: 1000,
    );

    // Pace smoother: avg of last 3 samples
    paceSmoother = PaceSmoother(windowSize: 3);
    paceSmoother.attach(locationService.positionStream);

    final emitted = <PaceResult>[];

    paceSub = paceSmoother.paceStream.listen(emitted.add);

    await locationService.start();

    final t0 = DateTime.now();

    //
    // Send fake speeds:
    // 3 m/s  (~3:20 per km)
    // 4 m/s  (~2:30 per km)
    // 5 m/s  (~2:00 per km)
    //
    controller.add(fakeGPos(speed: 3.0, timestamp: t0));
    controller.add(fakeGPos(speed: 4.0, timestamp: t0.add(const Duration(seconds: 1))));
    controller.add(fakeGPos(speed: 5.0, timestamp: t0.add(const Duration(seconds: 2))));

    await Future.delayed(const Duration(milliseconds: 200));

    expect(emitted, isNotEmpty);

    // Last smoothed speed = average(3,4,5) = 4 m/s
    final last = emitted.last;

    expect(last.speedMps, closeTo(4.0, 0.01));
    expect(last.kmh, closeTo(14.4, 0.1));

    // Expected pace = 1000m / 4 m/s = 250 sec = 4.166 min → 4.17
    expect(last.paceMinutesPerKm, closeTo(4.17, 0.05));
    expect(last.paceString, equals("4'10\" /km")); // (rounded seconds)
  });
}
