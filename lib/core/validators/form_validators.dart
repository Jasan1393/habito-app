class FormValidators {
  FormValidators._();

  static const int longTextMaxLength = 250;

  static final RegExp _emailRegex = RegExp(
    r"^(?=.{6,254}$)[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+[A-Z]{2,63}$",
    caseSensitive: false,
  );

  static String? requiredText(
    String? value, {
    required String field,
  }) {
    if ((value ?? '').trim().isEmpty) {
      return 'Ingresa $field.';
    }
    return null;
  }

  static bool isValidEmail(String value) {
    return _emailRegex.hasMatch(value.trim());
  }

  static String? email(
    String? value, {
    String field = 'tu correo electronico',
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresa $field.';
    if (!isValidEmail(text)) {
      return 'Ingresa un correo electrónico válido.';
    }
    return null;
  }

  static String normalizedPhoneDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValidPhone(String value) {
    final digits = normalizedPhoneDigits(value);
    if (digits.length == 10 && digits.startsWith('09')) return true;
    if (digits.length == 9 && digits.startsWith('9')) return true;
    if (digits.length == 12 && digits.startsWith('5939')) return true;
    return false;
  }

  static String? phone(
    String? value, {
    String field = 'tu celular',
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresa $field.';
    if (!isValidPhone(text)) {
      return 'Ingresa un celular ecuatoriano válido.';
    }
    return null;
  }

  static String? maxLength(
    String? value, {
    required int max,
    required String field,
  }) {
    if ((value ?? '').trim().length > max) {
      return '$field no puede superar $max caracteres.';
    }
    return null;
  }

  static String? requiredMaxLength(
    String? value, {
    required String field,
    int max = longTextMaxLength,
  }) {
    return requiredText(value, field: field) ??
        maxLength(value, max: max, field: field);
  }
}
