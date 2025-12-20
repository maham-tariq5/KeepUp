// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'run_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RunStatsAdapter extends TypeAdapter<RunStats> {
  @override
  final int typeId = 1;

  @override
  RunStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RunStats(
      username: fields[0] as String?,
      avgPace: fields[1] as double?,
      bestPace: fields[2] as double?,
      paceSamples: (fields[3] as List).cast<double>(),
      durationSeconds: fields[4] as int,
      paceGoalMinPerKm: fields[5] as double,
      timestamp: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RunStats obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.avgPace)
      ..writeByte(2)
      ..write(obj.bestPace)
      ..writeByte(3)
      ..write(obj.paceSamples)
      ..writeByte(4)
      ..write(obj.durationSeconds)
      ..writeByte(5)
      ..write(obj.paceGoalMinPerKm)
      ..writeByte(6)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
