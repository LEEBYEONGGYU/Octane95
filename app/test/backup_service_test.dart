import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:octane95/model/car_profile.dart';
import 'package:octane95/model/octane_log.dart';
import 'package:octane95/services/backup_service.dart';

void main() {
  group('BackupService codec', () {
    test('round-trips an empty backup', () {
      final source = BackupDocument(
        appVersion: '1.0.2',
        exportedAt: DateTime.utc(2026, 8, 2, 14, 23),
        vehicle: null,
        records: const [],
        onboardingShown: null,
      );

      final restored = BackupService.decodeAndValidate(
        BackupService.encode(source),
      );

      expect(restored.vehicleCount, 0);
      expect(restored.recordCount, 0);
      expect(restored.includesSettings, isFalse);
    });

    test('round-trips vehicle, record, costs, and memo', () {
      final source = BackupDocument(
        appVersion: '1.0.2',
        exportedAt: DateTime.utc(2026, 8, 2, 14, 23),
        vehicle: CarProfile(
          name: '테스트 차량',
          year: 2024,
          recommendedOctane: 95,
          warningOctane: 92,
          tankCapacity: 60,
          photoBytes: Uint8List.fromList([1, 2, 3]),
        ),
        records: [
          OctaneLog(
            time: DateTime.utc(2026, 8, 1, 9, 30),
            type: 'mixed',
            result: 95.25,
            inputs: {
              'beforeLiter': '20',
              'beforeOctane': '94.5',
              'addLiter': '30',
              'addOctane': '97',
              'unitPrice': '1980',
              'totalCost': '59400',
            },
            memo: '장거리 주행 전 주유',
            stationName: '테스트 주유소',
            odometer: 171420,
            isFullTank: true,
          ),
        ],
        onboardingShown: true,
      );

      final json = source.toJson();
      final restored = BackupService.decodeAndValidate(
        BackupService.encode(source),
      );

      expect(json['includesImages'], isFalse);
      expect((json['vehicles'] as List).single, isNot(contains('photoBytes')));
      expect(restored.vehicle?.name, '테스트 차량');
      expect(restored.vehicle?.photoBytes, isNull);
      expect(restored.records.single.result, 95.25);
      expect(restored.records.single.inputs['totalCost'], '59400');
      expect(restored.records.single.memo, '장거리 주행 전 주유');
      expect(restored.records.single.stationName, '테스트 주유소');
      expect(restored.records.single.odometer, 171420);
      expect(restored.records.single.isFullTank, isTrue);
      expect(restored.onboardingShown, isTrue);
    });

    test('accepts older backups without new fuel-record fields', () {
      final restored = BackupService.decodeAndValidate('''
        {
          "appId": "premium_fuel_note",
          "backupFormatVersion": 1,
          "appVersion": "1.0.2",
          "exportedAt": "2026-08-02T14:23:00Z",
          "vehicles": [],
          "records": [{
            "time": "2026-08-02T14:23:00Z",
            "type": "mixed",
            "result": 95.0,
            "inputs": {},
            "memo": ""
          }],
          "settings": {}
        }
      ''');

      expect(restored.records.single.stationName, isNull);
      expect(restored.records.single.odometer, isNull);
      expect(restored.records.single.isFullTank, isFalse);
    });

    test('rejects malformed JSON and another app backup', () {
      expectInvalid('{not-json');
      expectInvalid('''
        {
          "appId": "another_app",
          "backupFormatVersion": 1,
          "appVersion": "1.0.2",
          "exportedAt": "2026-08-02T14:23:00Z",
          "vehicles": [],
          "records": [],
          "settings": {}
        }
      ''');
    });

    test('rejects missing fields and invalid record types', () {
      expectInvalid('''
        {
          "appId": "premium_fuel_note",
          "backupFormatVersion": 1,
          "appVersion": "1.0.2",
          "exportedAt": "invalid-date",
          "vehicles": [],
          "records": [],
          "settings": {}
        }
      ''');
      expectInvalid('''
        {
          "appId": "premium_fuel_note",
          "backupFormatVersion": 1,
          "appVersion": "1.0.2",
          "exportedAt": "2026-08-02T14:23:00Z",
          "vehicles": [],
          "records": [{
            "time": "2026-08-02T14:23:00Z",
            "type": "mixed",
            "result": "95.0",
            "inputs": {},
            "memo": ""
          }],
          "settings": {}
        }
      ''');
    });

    test('rejects unsupported future backup versions', () {
      expect(
        () => BackupService.decodeAndValidate('''
          {
            "appId": "premium_fuel_note",
            "backupFormatVersion": 2,
            "appVersion": "2.0.0",
            "exportedAt": "2026-08-02T14:23:00Z",
            "vehicles": [],
            "records": [],
            "settings": {}
          }
        '''),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.error,
            'error',
            BackupValidationError.unsupportedVersion,
          ),
        ),
      );
    });
  });
}

void expectInvalid(String source) {
  expect(
    () => BackupService.decodeAndValidate(source),
    throwsA(
      isA<BackupValidationException>().having(
        (error) => error.error,
        'error',
        BackupValidationError.invalidFile,
      ),
    ),
  );
}
