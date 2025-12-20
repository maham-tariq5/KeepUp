// to store run statistics such as duration, pace, etc.
// currently only used for local storage/single profile
// but can be extended for more complex use cases

//use Hive for local storage since it's lightweight and easy to use
// generate adapter with `flutter packages pub run build_runner build`
import 'package:hive/hive.dart';

part 'run_stats.g.dart';

@HiveType(typeId: 1)
class RunStats extends HiveObject {
  @HiveField(0)
  String? username;

  @HiveField(1)
  double? avgPace;

  @HiveField(2)
  double? bestPace;

  @HiveField(3)
  List<double> paceSamples;

  @HiveField(4)
  int durationSeconds;

  @HiveField(5)
  double paceGoalMinPerKm;

  @HiveField(6)
  DateTime timestamp;

  RunStats({
    required this.username,
    required this.avgPace,
    required this.bestPace,
    required this.paceSamples,
    required this.durationSeconds,
    required this.paceGoalMinPerKm,
    required this.timestamp,
  });
}
