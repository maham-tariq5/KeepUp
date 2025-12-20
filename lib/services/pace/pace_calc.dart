import 'dart:math';

// data container containing all the metrics
class PaceResult {
  final double speedMps; // meters per second
  final double kmh; // km/h
  final double paceMinutesPerKm; // minutes per km
  final String paceString; // formatted pace "5'32\" /km"

  PaceResult({
    required this.speedMps,
    required this.kmh,
    required this.paceMinutesPerKm,
    required this.paceString,
  });
}

// method to return the results
// this uses the GPS reported speed from geolocator
// using GPS stream
class PaceCalculator {
  static PaceResult fromSpeed(double speedMps) {
    final kmh = _computeKmh(speedMps);
    final pace = _computePace(speedMps);
    final paceString = _formatPaceString(pace);

    return PaceResult(
      speedMps: speedMps,
      kmh: kmh,
      paceMinutesPerKm: pace,
      paceString: paceString,
    );
  }
}

// helper to compute km/h from m/s
double _computeKmh(double speedMps) {
  return speedMps * 3.6;
}

// helper to compute pace (min/km) from m/s
double _computePace(double speedMps) {
  if (speedMps <= 0) {
    return double.infinity; // infinite pace for zero or negative speed
  }
  final paceSecondsPerKm = 1000 / speedMps;
  return paceSecondsPerKm / 60; // convert to minutes
}

// helper to format pace string
_formatPaceString(double paceMinutesPerKm) {
  if (!paceMinutesPerKm.isFinite || paceMinutesPerKm <= 0) {
    return "∞ /km";
  }

  final totalSeconds = (paceMinutesPerKm * 60).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  final secStr = seconds.toString().padLeft(2, '0');

  return "$minutes'$secStr\" /km";
}
