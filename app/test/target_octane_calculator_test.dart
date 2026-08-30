import 'package:flutter_test/flutter_test.dart';
import 'package:octane95/utils/target_octane_calculator.dart';

void main() {
  group('TargetOctaneCalculator', () {
    test('calculates required fuel, total fuel, and final octane', () {
      final result = TargetOctaneCalculator.calculate(
        target: 95,
        currentLiter: 15,
        currentOctane: 92,
        fuelOctane: 98,
      );

      expect(result.isPossible, isTrue);
      expect(result.requiredLiter, closeTo(15, 0.0001));
      expect(result.totalLiter, closeTo(30, 0.0001));
      expect(result.finalOctane, closeTo(95, 0.0001));
    });

    test('reports impossible when the new fuel cannot raise octane', () {
      final result = TargetOctaneCalculator.calculate(
        target: 95,
        currentLiter: 15,
        currentOctane: 92,
        fuelOctane: 92,
      );

      expect(result.isPossible, isFalse);
      expect(result.message, contains('현재 연료보다 높아야'));
    });

    test('reports impossible when the target exceeds new fuel octane', () {
      final result = TargetOctaneCalculator.calculate(
        target: 99,
        currentLiter: 15,
        currentOctane: 92,
        fuelOctane: 98,
      );

      expect(result.isPossible, isFalse);
      expect(result.message, contains('새 연료의 옥탄가보다 높습니다'));
    });

    test('reports impossible when target equals new fuel octane', () {
      final result = TargetOctaneCalculator.calculate(
        target: 98,
        currentLiter: 15,
        currentOctane: 92,
        fuelOctane: 98,
      );

      expect(result.isPossible, isFalse);
      expect(result.message, contains('목표와 같습니다'));
    });

    test('treats invalid and already-achieved values explicitly', () {
      final invalid = TargetOctaneCalculator.calculate(
        target: 95,
        currentLiter: 0,
        currentOctane: 92,
        fuelOctane: 98,
      );
      final achieved = TargetOctaneCalculator.calculate(
        target: 95,
        currentLiter: 15,
        currentOctane: 96,
        fuelOctane: 98,
      );

      expect(invalid.isPossible, isFalse);
      expect(invalid.message, contains('0보다 큰 숫자'));
      expect(achieved.isPossible, isTrue);
      expect(achieved.requiredLiter, 0);
      expect(achieved.totalLiter, 15);
      expect(achieved.finalOctane, 96);
    });
  });
}
