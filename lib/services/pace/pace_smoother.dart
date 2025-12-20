import 'dart:async';
import 'package:flutter/material.dart';

import '../location/i_location_service.dart';
import 'pace_calc.dart';

class PaceSmoother {
  final int windowSize;
  final List<double> _recentSpeeds = [];

  final _paceController = StreamController<PaceResult>.broadcast();
  Stream<PaceResult> get paceStream => _paceController.stream;

  StreamSubscription<LocationPosition>? _posSub;

  PaceSmoother({this.windowSize = 9});

  void attach(Stream<LocationPosition> positionStream) {
    _posSub = positionStream.listen(_onNewPosition);
  }

  /// Manually inject a position (useful for testing)
  void injectPosition(LocationPosition pos) {
    _onNewPosition(pos);
  }

  void _onNewPosition(LocationPosition pos) {
    final speed = pos.speedMetersPerSecond;

    if (speed == null || !speed.isFinite) {
      debugPrint('PaceSmoother: speed is null or not finite');
      return;
    }

    // Filter unrealistic GPS noise and stationary
    // for testing reason we accept lower speeds (such as walking speed)
    //if (speed < 1) {
      //debugPrint('PaceSmoother: speed too low ($speed m/s), ignoring');
      //return; // ignore stationary(< 1.5 m/s = < ~11:00 min/km)
    //}
    if (speed > 10.0) {
      debugPrint('PaceSmoother: speed too high ($speed m/s), ignoring');
      return; // > 10 m/s = ~36 km/h (very fast running)
    }

    debugPrint('PaceSmoother: valid speed $speed m/s');

    // keep sliding window
    _recentSpeeds.add(speed);
    if (_recentSpeeds.length > windowSize) {
      _recentSpeeds.removeAt(0);
    }

    // compute smoothed average speed
    final avgSpeed =
        _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;

    // compute pace from this averaged speed
    final result = PaceCalculator.fromSpeed(avgSpeed);

    _paceController.add(result);
  }

  Future<void> dispose() async {
    await _posSub?.cancel();
    await _paceController.close();
  }
}
