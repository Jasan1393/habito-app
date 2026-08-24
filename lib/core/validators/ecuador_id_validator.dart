class EcuadorIdValidator {
  EcuadorIdValidator._();

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValid({
    required String identificationType,
    required String value,
  }) {
    final type = identificationType.trim().toLowerCase();

    if (type == 'cedula') {
      return isValidCedula(value);
    }

    if (type == 'ruc') {
      return isValidRuc(value);
    }

    if (type == 'pasaporte') {
      return value.trim().length >= 5;
    }

    return value.trim().isNotEmpty;
  }

  static String? validate({
    required String identificationType,
    required String? value,
    String emptyMessage = 'Ingresa tu documento.',
  }) {
    final text = (value ?? '').trim();
    final type = identificationType.trim().toLowerCase();

    if (text.isEmpty) {
      return emptyMessage;
    }

    if (type == 'cedula') {
      final digits = digitsOnly(text);
      if (!_hasOnlyDigits(text)) {
        return 'La cédula debe contener solo números.';
      }
      if (digits.length != 10) {
        return 'La cédula debe tener 10 dígitos.';
      }
      if (!isValidCedula(text)) {
        return 'La cédula ingresada no es válida.';
      }
      return null;
    }

    if (type == 'ruc') {
      final digits = digitsOnly(text);
      if (!_hasOnlyDigits(text)) {
        return 'El RUC debe contener solo números.';
      }
      if (digits.length != 13) {
        return 'El RUC debe tener 13 dígitos.';
      }
      if (!isValidRuc(text)) {
        return 'El RUC ingresado no es válido.';
      }
      return null;
    }

    if (type == 'pasaporte') {
      if (text.length < 5) {
        return 'Ingresa un pasaporte válido.';
      }
      return null;
    }

    return null;
  }

  static bool isValidCedula(String value) {
    final text = value.trim();
    if (!_hasOnlyDigits(text)) return false;

    final digits = digitsOnly(text);
    if (digits.length != 10 || _allDigitsEqual(digits)) return false;
    if (!_hasValidProvinceCode(digits)) return false;

    final thirdDigit = int.parse(digits[2]);
    if (thirdDigit > 5) return false;

    var sum = 0;
    for (var index = 0; index < 9; index++) {
      var digit = int.parse(digits[index]);
      if (index.isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }

    final checkDigit = sum % 10 == 0 ? 0 : 10 - (sum % 10);
    return checkDigit == int.parse(digits[9]);
  }

  static bool isValidRuc(String value) {
    final text = value.trim();
    if (!_hasOnlyDigits(text)) return false;

    final digits = digitsOnly(text);
    if (digits.length != 13 || _allDigitsEqual(digits)) return false;
    if (!_hasValidProvinceCode(digits)) return false;

    final thirdDigit = int.parse(digits[2]);

    if (thirdDigit <= 5) {
      return isValidCedula(digits.substring(0, 10)) &&
          _hasValidEstablishmentCode(digits.substring(10, 13));
    }

    if (thirdDigit == 6) {
      return _isValidModulo11(
            digits: digits,
            coefficients: const [3, 2, 7, 6, 5, 4, 3, 2],
            checkDigitIndex: 8,
          ) &&
          _hasValidEstablishmentCode(digits.substring(9, 13));
    }

    if (thirdDigit == 9) {
      return _isValidModulo11(
            digits: digits,
            coefficients: const [4, 3, 2, 7, 6, 5, 4, 3, 2],
            checkDigitIndex: 9,
          ) &&
          _hasValidEstablishmentCode(digits.substring(10, 13));
    }

    return false;
  }

  static bool _isValidModulo11({
    required String digits,
    required List<int> coefficients,
    required int checkDigitIndex,
  }) {
    var sum = 0;
    for (var index = 0; index < coefficients.length; index++) {
      sum += int.parse(digits[index]) * coefficients[index];
    }

    final remainder = sum % 11;
    final checkDigit = remainder == 0 ? 0 : 11 - remainder;
    if (checkDigit == 10) return false;

    return checkDigit == int.parse(digits[checkDigitIndex]);
  }

  static bool _hasValidProvinceCode(String digits) {
    final province = int.tryParse(digits.substring(0, 2)) ?? 0;
    return (province >= 1 && province <= 24) || province == 30;
  }

  static bool _hasValidEstablishmentCode(String digits) {
    return (int.tryParse(digits) ?? 0) > 0;
  }

  static bool _hasOnlyDigits(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  static bool _allDigitsEqual(String digits) {
    return RegExp(r'^(\d)\1+$').hasMatch(digits);
  }
}
