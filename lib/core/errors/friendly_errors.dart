import 'dart:convert';

class FriendlyErrors {
  FriendlyErrors._();

  static String clean(
    Object? error, {
    required String fallback,
    int? statusCode,
  }) {
    final raw = _normalizeRaw(error);
    final decoded = fromResponseBody(raw, statusCode: statusCode);
    final candidate = decoded ?? _stripTechnicalNoise(raw);

    if (candidate.isEmpty || _looksTechnical(candidate)) {
      return _fallbackForStatus(statusCode, fallback);
    }

    return candidate;
  }

  static String? fromResponseBody(String body, {int? statusCode}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      final message = _messageFromDecoded(decoded);
      if (message != null && message.trim().isNotEmpty) {
        return clean(message, fallback: _fallbackForStatus(statusCode, ''));
      }
    } catch (_) {
      // Some endpoints return HTML or plain text. The public cleaner handles it.
    }

    return null;
  }

  static String checkout(Object? error) {
    return clean(
      error,
      fallback:
          'No pudimos confirmar tu pedido ahora. Revisa tu conexión e intenta nuevamente.',
    );
  }

  static String cancelAppointment(Object? error) {
    return clean(
      error,
      fallback:
          'No pudimos cancelar la cita ahora. Intenta nuevamente o contacta a la barbería.',
    );
  }

  static String rescheduleAppointment(Object? error) {
    return clean(
      error,
      fallback:
          'No pudimos reagendar la cita ahora. Revisa el horario elegido e intenta nuevamente.',
    );
  }

  static String paymentProof(Object? error) {
    return clean(
      error,
      fallback:
          'No pudimos subir el comprobante. Revisa la imagen y vuelve a intentarlo.',
    );
  }

  static String points(Object? error) {
    return clean(
      error,
      fallback:
          'No pudimos consultar tus puntos en este momento. Intenta nuevamente en unos segundos.',
    );
  }

  static String loadData(Object? error, {String? fallback}) {
    return clean(
      error,
      fallback:
          fallback ?? 'No pudimos cargar la información. Intenta nuevamente.',
    );
  }

  static String _normalizeRaw(Object? error) {
    return (error ?? '').toString().trim();
  }

  static String _stripTechnicalNoise(String raw) {
    var message = raw.trim();
    final prefixes = [
      'Exception:',
      'FormatException:',
      'ClientException:',
      'SocketException:',
      'HttpException:',
      'Error:',
    ];

    for (final prefix in prefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
      }
    }

    message = message
        .replaceFirst(
            RegExp(r'^Error\s+\d+\s+del servidor\.\s+Respuesta:\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return message;
  }

  static String? _messageFromDecoded(dynamic decoded) {
    if (decoded is String) return decoded;

    if (decoded is Map) {
      final candidates = [
        decoded['message'],
        decoded['error_description'],
        decoded['error'],
        decoded['detail'],
        decoded['details'],
      ];

      for (final candidate in candidates) {
        final message = _messageFromDecoded(candidate);
        if (message != null && message.trim().isNotEmpty) return message;
      }

      final data = decoded['data'];
      final nestedMessage = _messageFromDecoded(data);
      if (nestedMessage != null && nestedMessage.trim().isNotEmpty) {
        return nestedMessage;
      }

      final response = data is Map ? data['response'] : null;
      final responseMessage = _messageFromDecoded(response);
      if (responseMessage != null && responseMessage.trim().isNotEmpty) {
        return responseMessage;
      }
    }

    return null;
  }

  static bool _looksTechnical(String message) {
    final lower = message.toLowerCase();
    if (message.length > 220) return true;
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection reset') ||
        lower.contains('connection refused')) {
      return true;
    }
    if (lower.contains('<html') || lower.contains('<!doctype')) return true;
    if (lower.contains('sqlstate') || lower.contains('stack trace')) {
      return true;
    }
    if (lower.contains('undefined index') ||
        lower.contains('undefined variable')) {
      return true;
    }
    if (lower.contains('no query results for model')) return true;
    if (lower.contains('response.body')) return true;
    if (message.contains('{') && message.contains('}')) return true;
    return false;
  }

  static String _fallbackForStatus(int? statusCode, String fallback) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Tu sesión ya no está disponible. Inicia sesión nuevamente.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'El servidor no pudo procesar la solicitud en este momento. Intenta más tarde.';
    }
    return fallback.isEmpty
        ? 'No pudimos completar la solicitud. Intenta nuevamente.'
        : fallback;
  }
}
