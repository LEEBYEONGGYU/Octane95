// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'octane_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OctaneLogAdapter extends TypeAdapter<OctaneLog> {
  @override
  final int typeId = 0;

  @override
  OctaneLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OctaneLog(
      time: fields[0] as DateTime,
      type: fields[1] as String,
      result: fields[2] as double,
      inputs: (fields[3] as Map).cast<String, dynamic>(),
      memo: fields[4] as String,
      stationName: fields[5] as String?,
      odometer: (fields[6] as num?)?.toDouble(),
      isFullTank: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, OctaneLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.time)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.result)
      ..writeByte(3)
      ..write(obj.inputs)
      ..writeByte(4)
      ..write(obj.memo)
      ..writeByte(5)
      ..write(obj.stationName)
      ..writeByte(6)
      ..write(obj.odometer)
      ..writeByte(7)
      ..write(obj.isFullTank);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctaneLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
