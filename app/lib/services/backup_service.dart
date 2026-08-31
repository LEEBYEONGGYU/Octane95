import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/car_profile.dart';
import '../model/octane_log.dart';

enum BackupValidationError { invalidFile, unsupportedVersion }

class BackupValidationException implements Exception {
  final BackupValidationError error;

  const BackupValidationException(this.error);
}

class BackupOperationException implements Exception {
  final String failureStage;

  const BackupOperationException(this.failureStage);
}

enum BackupExportResult { completed, cancelled }

class BackupFileSaveResult {
  final String fileName;
  final String displayLocation;

  const BackupFileSaveResult({
    required this.fileName,
    required this.displayLocation,
  });
}

class BackupDocument {
  final String appVersion;
  final DateTime exportedAt;
  final CarProfile? vehicle;
  final List<OctaneLog> records;
  final bool? onboardingShown;

  const BackupDocument({
    required this.appVersion,
    required this.exportedAt,
    required this.vehicle,
    required this.records,
    required this.onboardingShown,
  });

  int get vehicleCount => vehicle == null ? 0 : 1;
  int get recordCount => records.length;
  bool get includesSettings => onboardingShown != null;

  Map<String, dynamic> toJson() {
    return {
      'appId': BackupService.appId,
      'backupFormatVersion': BackupService.currentBackupFormatVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'includesImages': false,
      'vehicles': [if (vehicle != null) _vehicleToJson(vehicle!)],
      'records': records.map(_recordToJson).toList(),
      'settings': {
        if (onboardingShown != null) 'onboardingShown': onboardingShown,
      },
    };
  }

  static Map<String, dynamic> _vehicleToJson(CarProfile vehicle) {
    return {
      'id': 'main',
      'name': vehicle.name,
      'year': vehicle.year,
      'recommendedOctane': vehicle.recommendedOctane,
      'warningOctane': vehicle.warningOctane,
      'tankCapacity': vehicle.tankCapacity,
    };
  }

  static Map<String, dynamic> _recordToJson(OctaneLog record) {
    return {
      'time': record.time.toIso8601String(),
      'type': record.type,
      'result': record.result,
      'inputs': Map<String, dynamic>.from(record.inputs),
      'memo': record.memo,
      'stationName': record.stationName,
      'odometer': record.odometer,
      'isFullTank': record.isFullTank,
    };
  }
}

class BackupMigrator {
  static Map<String, dynamic> migrate({
    required int sourceVersion,
    required int targetVersion,
    required Map<String, dynamic> data,
  }) {
    if (sourceVersion > targetVersion) {
      throw const BackupValidationException(
        BackupValidationError.unsupportedVersion,
      );
    }
    if (sourceVersion != 1 || targetVersion != 1) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }
    return data;
  }
}

class BackupService {
  static const String appId = 'premium_fuel_note';
  static const int currentBackupFormatVersion = 1;
  static const String currentAppVersion = '1.0.3';
  static const String onboardingPreferenceKey = 'onboarding_shown_v1';
  static const int _maximumBackupBytes = 25 * 1024 * 1024;
  static const MethodChannel _backupStorageChannel = MethodChannel(
    'com.octane.octane95/backup_storage',
  );

  static Future<BackupDocument> captureCurrentData() async {
    final prefs = await SharedPreferences.getInstance();
    final car = Hive.box<CarProfile>('car_profile').get('main');
    final records = Hive.box<OctaneLog>('octane_logs').values.map(_copyLog);

    return BackupDocument(
      appVersion: currentAppVersion,
      exportedAt: DateTime.now(),
      vehicle: car == null ? null : _copyCar(car, includePhoto: false),
      records: records.toList(),
      onboardingShown:
          prefs.containsKey(onboardingPreferenceKey)
              ? prefs.getBool(onboardingPreferenceKey)
              : null,
    );
  }

  static String encode(BackupDocument document) {
    return const JsonEncoder.withIndent('  ').convert(document.toJson());
  }

  static BackupDocument decodeAndValidate(String source) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }

    final root = _stringMap(decoded);
    if (root == null || root['appId'] != appId) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }

    final sourceVersion = _integer(root['backupFormatVersion']);
    if (sourceVersion == null) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }
    final migrated = BackupMigrator.migrate(
      sourceVersion: sourceVersion,
      targetVersion: currentBackupFormatVersion,
      data: root,
    );

    final appVersion = migrated['appVersion'];
    final exportedAtText = migrated['exportedAt'];
    final vehicles = migrated['vehicles'];
    final records = migrated['records'];
    final settings = _stringMap(migrated['settings']);
    if (appVersion is! String ||
        appVersion.trim().isEmpty ||
        exportedAtText is! String ||
        vehicles is! List ||
        records is! List ||
        settings == null ||
        vehicles.length > 1) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }

    final exportedAt = DateTime.tryParse(exportedAtText);
    if (exportedAt == null) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }

    final vehicle =
        vehicles.isEmpty ? null : _vehicleFromJson(_stringMap(vehicles.first));
    final parsedRecords = <OctaneLog>[];
    for (final rawRecord in records) {
      parsedRecords.add(_recordFromJson(_stringMap(rawRecord)));
    }

    final onboarding = settings['onboardingShown'];
    if (onboarding != null && onboarding is! bool) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }

    return BackupDocument(
      appVersion: appVersion,
      exportedAt: exportedAt,
      vehicle: vehicle,
      records: parsedRecords,
      onboardingShown: onboarding as bool?,
    );
  }

  static Future<BackupExportResult> export(BackupDocument document) async {
    try {
      final file = await _writeTemporaryBackupFile(document);
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: '고급유 노트 데이터 백업',
        text: '백업 파일에는 차량 정보와 주유 기록이 포함될 수 있습니다. 안전한 위치에 보관해 주세요.',
      );
      return result.status == ShareResultStatus.dismissed
          ? BackupExportResult.cancelled
          : BackupExportResult.completed;
    } catch (_) {
      throw const BackupOperationException('write');
    }
  }

  /// Saves through Android's MediaStore rather than writing an absolute public
  /// path. Android 10+ exposes the result in Downloads/고급유노트 without a
  /// broad storage permission.
  static Future<BackupFileSaveResult> saveToDownloads(
    BackupDocument document,
  ) async {
    File? temporaryFile;
    try {
      temporaryFile = await _writeTemporaryBackupFile(document);
      final fileName = _fileName(document.exportedAt);
      final displayLocation = await _backupStorageChannel.invokeMethod<String>(
        'saveBackupFileToDownloads',
        {'sourcePath': temporaryFile.path, 'fileName': fileName},
      );
      if (displayLocation == null || displayLocation.trim().isEmpty) {
        throw const BackupOperationException('external_storage');
      }
      return BackupFileSaveResult(
        fileName: fileName,
        displayLocation: displayLocation,
      );
    } on PlatformException catch (error) {
      throw BackupOperationException(
        error.code == 'unsupported_android_version'
            ? 'unsupported_android_version'
            : 'external_storage',
      );
    } on BackupOperationException {
      rethrow;
    } catch (_) {
      throw const BackupOperationException('external_storage');
    } finally {
      final file = temporaryFile;
      if (file != null) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  static Future<BackupDocument?> pickAndValidate() async {
    FilePickerResult? selection;
    try {
      selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
    } catch (_) {
      throw const BackupOperationException('file_select');
    }
    if (selection == null) return null;

    final selected = selection.files.single;
    if (!selected.name.toLowerCase().endsWith('.json')) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }

    try {
      final bytes =
          selected.bytes ??
          (selected.path == null
              ? null
              : await File(selected.path!).readAsBytes());
      if (bytes == null || bytes.length > _maximumBackupBytes) {
        throw const BackupValidationException(
          BackupValidationError.invalidFile,
        );
      }
      return decodeAndValidate(utf8.decode(bytes));
    } on BackupValidationException {
      rethrow;
    } on FormatException {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    } catch (_) {
      throw const BackupOperationException('file_read');
    }
  }

  static Future<void> restore(BackupDocument document) async {
    final logBox = Hive.box<OctaneLog>('octane_logs');
    final carBox = Hive.box<CarProfile>('car_profile');
    final prefs = await SharedPreferences.getInstance();
    final previous = _captureLocalSnapshot(logBox, carBox, prefs);

    File? automaticBackup;
    try {
      automaticBackup = await _writeAutomaticBackup();
      await _replaceData(document, logBox, carBox, prefs);
    } catch (_) {
      try {
        await _restoreLocalSnapshot(previous, logBox, carBox, prefs);
      } catch (_) {}
      throw const BackupOperationException('write');
    }

    try {
      if (await automaticBackup.exists()) {
        await automaticBackup.delete();
      }
    } catch (_) {}
  }

  static Future<void> deleteAllData() async {
    final logBox = Hive.box<OctaneLog>('octane_logs');
    final carBox = Hive.box<CarProfile>('car_profile');
    final prefs = await SharedPreferences.getInstance();
    final previous = _captureLocalSnapshot(logBox, carBox, prefs);
    try {
      await logBox.clear();
      await carBox.clear();
      await prefs.clear();
      await carBox.flush();
      await logBox.flush();
    } catch (_) {
      try {
        await _restoreLocalSnapshot(previous, logBox, carBox, prefs);
      } catch (_) {}
      throw const BackupOperationException('write');
    }
  }

  static _LocalSnapshot _captureLocalSnapshot(
    Box<OctaneLog> logBox,
    Box<CarProfile> carBox,
    SharedPreferences prefs,
  ) {
    final currentCar = carBox.get('main');
    return _LocalSnapshot(
      vehicle:
          currentCar == null ? null : _copyCar(currentCar, includePhoto: true),
      records: logBox.values.map(_copyLog).toList(),
      preferences: {
        for (final key in prefs.getKeys())
          if (prefs.get(key) != null) key: prefs.get(key)!,
      },
    );
  }

  static Future<void> _replaceData(
    BackupDocument document,
    Box<OctaneLog> logBox,
    Box<CarProfile> carBox,
    SharedPreferences prefs,
  ) async {
    await logBox.clear();
    await carBox.clear();
    await prefs.remove(onboardingPreferenceKey);

    if (document.vehicle != null) {
      await carBox.put(
        'main',
        _copyCar(document.vehicle!, includePhoto: false),
      );
    }
    if (document.records.isNotEmpty) {
      await logBox.addAll(document.records.map(_copyLog));
    }
    if (document.onboardingShown != null) {
      await prefs.setBool(onboardingPreferenceKey, document.onboardingShown!);
    }
    await carBox.flush();
    await logBox.flush();
  }

  static Future<void> _restoreLocalSnapshot(
    _LocalSnapshot snapshot,
    Box<OctaneLog> logBox,
    Box<CarProfile> carBox,
    SharedPreferences prefs,
  ) async {
    await logBox.clear();
    await carBox.clear();
    await prefs.clear();
    if (snapshot.vehicle != null) {
      await carBox.put('main', _copyCar(snapshot.vehicle!, includePhoto: true));
    }
    if (snapshot.records.isNotEmpty) {
      await logBox.addAll(snapshot.records.map(_copyLog));
    }
    for (final entry in snapshot.preferences.entries) {
      await _setPreference(prefs, entry.key, entry.value);
    }
    await carBox.flush();
    await logBox.flush();
  }

  static Future<File> _writeAutomaticBackup() async {
    final directory = await getTemporaryDirectory();
    final timestamp = _compactTimestamp(DateTime.now());
    final file = File(
      '${directory.path}${Platform.pathSeparator}auto_backup_before_restore_$timestamp.json',
    );
    final current = await captureCurrentData();
    return file.writeAsString(encode(current), flush: true);
  }

  static Future<void> _setPreference(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  static CarProfile _vehicleFromJson(Map<String, dynamic>? json) {
    final name = json?['name'];
    final year = _integer(json?['year']);
    final recommended = _finiteDouble(json?['recommendedOctane']);
    final warning = _finiteDouble(json?['warningOctane']);
    final rawTank = json?['tankCapacity'];
    final tank = rawTank == null ? null : _finiteDouble(rawTank);
    if (json == null ||
        json['id'] != 'main' ||
        name is! String ||
        name.trim().isEmpty ||
        year == null ||
        recommended == null ||
        warning == null ||
        (rawTank != null && tank == null)) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }
    return CarProfile(
      name: name,
      year: year,
      recommendedOctane: recommended,
      warningOctane: warning,
      tankCapacity: tank,
    );
  }

  static OctaneLog _recordFromJson(Map<String, dynamic>? json) {
    final timeText = json?['time'];
    final type = json?['type'];
    final result = _finiteDouble(json?['result']);
    final inputs = _stringMap(json?['inputs']);
    final memo = json?['memo'];
    final stationName = json?['stationName'];
    final rawOdometer = json?['odometer'];
    final odometer = rawOdometer == null ? null : _finiteDouble(rawOdometer);
    final isFullTank = json?['isFullTank'] ?? false;
    final time = timeText is String ? DateTime.tryParse(timeText) : null;
    if (json == null ||
        time == null ||
        type is! String ||
        !const {'average', 'mixed', 'target'}.contains(type) ||
        result == null ||
        inputs == null ||
        memo is! String ||
        (stationName != null && stationName is! String) ||
        (rawOdometer != null && (odometer == null || odometer < 0)) ||
        isFullTank is! bool ||
        !inputs.values.every(_isJsonScalar)) {
      throw const BackupValidationException(BackupValidationError.invalidFile);
    }
    return OctaneLog(
      time: time,
      type: type,
      result: result,
      inputs: inputs,
      memo: memo,
      stationName:
          stationName is String && stationName.trim().isNotEmpty
              ? stationName.trim()
              : null,
      odometer: odometer,
      isFullTank: isFullTank,
    );
  }

  static bool _isJsonScalar(Object? value) {
    return value == null || value is String || value is bool || value is num;
  }

  static Map<String, dynamic>? _stringMap(Object? value) {
    if (value is! Map) return null;
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  static double? _finiteDouble(Object? value) {
    if (value is! num || !value.isFinite) return null;
    return value.toDouble();
  }

  static CarProfile _copyCar(CarProfile source, {required bool includePhoto}) {
    return CarProfile(
      name: source.name,
      year: source.year,
      recommendedOctane: source.recommendedOctane,
      warningOctane: source.warningOctane,
      tankCapacity: source.tankCapacity,
      photoBytes: includePhoto ? source.photoBytes : null,
    );
  }

  static OctaneLog _copyLog(OctaneLog source) {
    return OctaneLog(
      time: source.time,
      type: source.type,
      result: source.result,
      inputs: Map<String, dynamic>.from(source.inputs),
      memo: source.memo,
      stationName: source.stationName,
      odometer: source.odometer,
      isFullTank: source.isFullTank,
    );
  }

  static Future<File> _writeTemporaryBackupFile(BackupDocument document) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_fileName(document.exportedAt)}',
    );
    return file.writeAsString(encode(document), flush: true);
  }

  static String _fileName(DateTime time) {
    final date =
        '${time.year}${time.month.toString().padLeft(2, '0')}${time.day.toString().padLeft(2, '0')}';
    return 'premium_fuel_note_backup_${date}_${_compactTime(time)}.json';
  }

  static String _compactTimestamp(DateTime time) {
    final date =
        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    return '${date}_${_compactTime(time)}';
  }

  static String _compactTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}${time.minute.toString().padLeft(2, '0')}';
  }
}

class _LocalSnapshot {
  final CarProfile? vehicle;
  final List<OctaneLog> records;
  final Map<String, Object> preferences;

  const _LocalSnapshot({
    required this.vehicle,
    required this.records,
    required this.preferences,
  });
}
