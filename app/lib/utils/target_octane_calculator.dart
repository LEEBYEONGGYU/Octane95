class TargetOctaneCalculation {
  final double? requiredLiter;
  final double? totalLiter;
  final double? finalOctane;
  final String message;
  final bool isPossible;

  const TargetOctaneCalculation._({
    required this.requiredLiter,
    required this.totalLiter,
    required this.finalOctane,
    required this.message,
    required this.isPossible,
  });

  const TargetOctaneCalculation.invalid(String message)
    : this._(
        requiredLiter: null,
        totalLiter: null,
        finalOctane: null,
        message: message,
        isPossible: false,
      );

  const TargetOctaneCalculation.impossible(String message)
    : this._(
        requiredLiter: null,
        totalLiter: null,
        finalOctane: null,
        message: message,
        isPossible: false,
      );

  const TargetOctaneCalculation.success({
    required double requiredLiter,
    required double totalLiter,
    required double finalOctane,
    required String message,
  }) : this._(
         requiredLiter: requiredLiter,
         totalLiter: totalLiter,
         finalOctane: finalOctane,
         message: message,
         isPossible: true,
       );
}

class TargetOctaneCalculator {
  static TargetOctaneCalculation calculate({
    required double? target,
    required double? currentLiter,
    required double? currentOctane,
    required double? fuelOctane,
  }) {
    if (target == null ||
        currentLiter == null ||
        currentOctane == null ||
        fuelOctane == null ||
        target <= 0 ||
        currentLiter <= 0 ||
        currentOctane <= 0 ||
        fuelOctane <= 0) {
      return const TargetOctaneCalculation.invalid(
        '목표 옥탄가, 현재 잔량, 현재 연료 옥탄가, 새 연료 옥탄가에 0보다 큰 숫자를 입력해 주세요.',
      );
    }

    if (currentOctane >= target) {
      return TargetOctaneCalculation.success(
        requiredLiter: 0,
        totalLiter: currentLiter,
        finalOctane: currentOctane,
        message: '현재 연료가 이미 목표 옥탄가를 충족합니다. 추가 주유는 필요하지 않습니다.',
      );
    }

    if (fuelOctane <= currentOctane) {
      return const TargetOctaneCalculation.impossible(
        '새 연료의 옥탄가가 현재 연료보다 높아야 목표 옥탄가까지 올릴 수 있습니다.',
      );
    }

    if (target > fuelOctane) {
      return const TargetOctaneCalculation.impossible(
        '목표 옥탄가가 새 연료의 옥탄가보다 높습니다. 목표보다 높은 RON의 연료를 선택해 주세요.',
      );
    }

    if (target == fuelOctane) {
      return const TargetOctaneCalculation.impossible(
        '새 연료의 옥탄가가 목표와 같습니다. 유한한 주유량으로 목표에 도달하려면 목표보다 높은 RON의 연료가 필요합니다.',
      );
    }

    final requiredLiter =
        ((target - currentOctane) * currentLiter) / (fuelOctane - target);
    final totalLiter = currentLiter + requiredLiter;
    final finalOctane =
        ((currentLiter * currentOctane) + (requiredLiter * fuelOctane)) /
        totalLiter;
    return TargetOctaneCalculation.success(
      requiredLiter: requiredLiter,
      totalLiter: totalLiter,
      finalOctane: finalOctane,
      message:
          '${fuelOctane.toStringAsFixed(1)} RON 연료를 ${requiredLiter.toStringAsFixed(1)}L 넣으면 목표 ${target.toStringAsFixed(1)} RON에 도달합니다.',
    );
  }
}
