import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:octane95/model/car_profile.dart';
import 'package:octane95/model/octane_log.dart';

void main() {
  group('vehicle and fuel-record persistence', () {
    late Directory directory;

    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('octane95_hive_test_');
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(OctaneLogAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CarProfileAdapter());
      }
    });

    tearDownAll(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    test(
      'persists vehicle and simple, tank, and target fuel records',
      () async {
        final carBox = await Hive.openBox<CarProfile>('car_profile_test');
        final logBox = await Hive.openBox<OctaneLog>('octane_logs_test');

        await carBox.put(
          'main',
          CarProfile(
            name: '테스트 차량',
            year: 2024,
            recommendedOctane: 95,
            warningOctane: 92,
            tankCapacity: 60,
          ),
        );
        await logBox.addAll([
          OctaneLog(
            time: DateTime.utc(2026, 8, 31, 10),
            type: 'average',
            result: 97,
            inputs: const {
              'highLiter': '20',
              'regularLiter': '10',
              'highOctane': '100',
              'regularOctane': '91',
            },
            stationName: '고급유 주유소',
            odometer: 171420,
            isFullTank: true,
          ),
          OctaneLog(
            time: DateTime.utc(2026, 8, 31, 11),
            type: 'mixed',
            result: 96.5,
            inputs: const {
              'beforeLiter': '15',
              'beforeOctane': '95.3',
              'addLiter': '20',
              'addOctane': '97.4',
            },
            odometer: 171460,
          ),
          OctaneLog(
            time: DateTime.utc(2026, 8, 31, 12),
            type: 'target',
            result: 98,
            inputs: const {
              'targetOctane': '98',
              'requiredLiter': '15.0',
              'expectedFinalOctane': '98.00',
            },
          ),
        ]);

        await carBox.close();
        await logBox.close();

        final restoredCarBox = await Hive.openBox<CarProfile>(
          'car_profile_test',
        );
        final restoredLogBox = await Hive.openBox<OctaneLog>(
          'octane_logs_test',
        );

        expect(restoredCarBox.get('main')?.tankCapacity, 60);
        expect(restoredLogBox.values.map((log) => log.type), [
          'average',
          'mixed',
          'target',
        ]);
        expect(restoredLogBox.values.first.stationName, '고급유 주유소');
        expect(restoredLogBox.values.first.odometer, 171420);
        expect(restoredLogBox.values.first.isFullTank, isTrue);
        expect(restoredLogBox.values.elementAt(1).inputs['addLiter'], '20');
        expect(restoredLogBox.values.last.inputs['requiredLiter'], '15.0');

        await restoredCarBox.close();
        await restoredLogBox.close();
      },
    );
  });
}
