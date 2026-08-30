import 'package:hive/hive.dart';

part 'octane_log.g.dart';

@HiveType(typeId: 0)
class OctaneLog {
  @HiveField(0)
  DateTime time;

  @HiveField(1)
  String type; // average | mixed

  @HiveField(2)
  double result;

  @HiveField(3)
  Map<String, dynamic> inputs;

  @HiveField(4)
  String memo;

  /// Optional fuel-station name. Kept separate from [inputs] so future fuel
  /// cost analysis can use it without depending on a calculation mode.
  @HiveField(5)
  String? stationName;

  /// Odometer in kilometres at the time of refuelling.
  @HiveField(6)
  double? odometer;

  /// Whether this entry represents a full tank. Older records default to
  /// false when this field is absent from Hive.
  @HiveField(7)
  bool isFullTank;

  OctaneLog({
    required this.time,
    required this.type,
    required this.result,
    required this.inputs,
    this.memo = "",
    this.stationName,
    this.odometer,
    this.isFullTank = false,
  });
}
