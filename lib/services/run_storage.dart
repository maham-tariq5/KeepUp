import 'package:hive_flutter/hive_flutter.dart';
import '../models/run_stats.dart';
import 'dart:developer' as developer;

// service to handle saving RunStats and profile to Hive
class RunStorage {
  static const _boxName = 'stats';
  static const _profileKey = 'profile';

  /// ensures the Hive box is open and the adapter is registered
  static Future<Box<RunStats>> _openBoxIfNeeded() async {
    if (!Hive.isAdapterRegistered(RunStatsAdapter().typeId)) {
      Hive.registerAdapter(RunStatsAdapter());
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<RunStats>(_boxName);
    }
    return await Hive.openBox<RunStats>(_boxName);
  }

  /// saves a RunStats object to Hive (for regular runs)
  static Future<void> saveRun(RunStats stats) async {
    try {
      final box = await _openBoxIfNeeded();
      await box.add(stats);
      developer.log('Run saved to Hive: ${stats.timestamp}');
    } catch (e, st) {
      developer.log('Failed saving RunStats: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// returns the profile object (creates default if missing)
  static Future<RunStats> getProfile() async {
    final box = await _openBoxIfNeeded();
    if (!box.containsKey(_profileKey)) {
      final defaultProfile = RunStats(
        username: 'Runner',
        avgPace: null,
        bestPace: null,
        paceSamples: [],
        durationSeconds: 0,
        paceGoalMinPerKm: 0,
        timestamp: DateTime.now(),
      );
      await box.put(_profileKey, defaultProfile);
      return defaultProfile;
    }
    return box.get(_profileKey)!;
  }

  /// updates the username in the profile and saves
  static Future<void> updateUsername(String username) async {
    final profile = await getProfile();
    profile.username = username;
    await profile.save();
    developer.log('Updated username to "$username" in Hive');
  }

  // get the list of all saved runs
  static Future<List<RunStats>> getAllRuns() async {
    final box = await _openBoxIfNeeded();
    return box.values.where((run) => run.key != _profileKey).toList();
  }

  // clears all data from storage (both profile and runs)
  static Future<void> clearAllData() async {
    final box = await _openBoxIfNeeded();
    await box.clear();
    developer.log('All data cleared from Hive storage');
  }
}
