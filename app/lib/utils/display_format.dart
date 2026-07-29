class DisplayFormat {
  static double? asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().replaceAll(',', '').trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static bool hasValue(Object? value) {
    if (value == null) return false;
    return value.toString().trim().isNotEmpty;
  }

  static String decimal(double value, int fractionDigits) {
    return value.toStringAsFixed(fractionDigits);
  }

  static String ron(double value, {bool detail = false}) {
    return '${decimal(value, detail ? 2 : 1)} RON';
  }

  static String liter(double value) => '${decimal(value, 1)} L';

  static String won(double value) => '${groupedInteger(value)}원';

  static String unitPrice(double value) => '${groupedInteger(value)}원/L';

  static String groupedInteger(double value) {
    final text = value.round().toString();
    final sign = text.startsWith('-') ? '-' : '';
    final digits = sign.isEmpty ? text : text.substring(1);
    final buffer = StringBuffer(sign);

    for (var index = 0; index < digits.length; index++) {
      buffer.write(digits[index]);
      final remaining = digits.length - index - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static String inputValue(String key, Object? rawValue) {
    final value = asDouble(rawValue);
    if (value == null) return rawValue?.toString().trim() ?? '';

    if (_unitPriceKeys.contains(key)) return unitPrice(value);
    if (_totalCostKeys.contains(key)) return won(value);
    if (_literKeys.contains(key)) return liter(value);
    if (_octaneKeys.contains(key)) return '${decimal(value, 2)} RON';
    return rawValue.toString().trim();
  }

  static const _unitPriceKeys = {
    'unitPrice',
    'highUnitPrice',
    'regularUnitPrice',
  };

  static const _totalCostKeys = {
    'totalCost',
    'highTotalCost',
    'regularTotalCost',
  };

  static const _literKeys = {
    'highLiter',
    'regularLiter',
    'beforeLiter',
    'addLiter',
    'tankCapacity',
    'currentLiter',
    'requiredLiter',
  };

  static const _octaneKeys = {
    'beforeOctane',
    'addOctane',
    'targetOctane',
    'currentOctane',
    'fuelOctane',
  };
}
