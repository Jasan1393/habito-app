class AppointmentData {
  static final List<Map<String, dynamic>> _appointments = [];

  static List<Map<String, dynamic>> get appointments {
    return _appointments
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static List<Map<String, dynamic>> getAppointments() {
    return _appointments
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic>? getAppointmentById(String id) {
    try {
      final item = _appointments.firstWhere(
        (appointment) => appointment['id'] == id,
      );
      return Map<String, dynamic>.from(item);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? getAppointmentByBackendId(int appointmentId) {
    try {
      final item = _appointments.firstWhere(
        (appointment) => _asInt(appointment['appointmentId']) == appointmentId,
      );
      return Map<String, dynamic>.from(item);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? getAppointmentByBookingId(int bookingId) {
    try {
      final item = _appointments.firstWhere(
        (appointment) => _asInt(appointment['bookingId']) == bookingId,
      );
      return Map<String, dynamic>.from(item);
    } catch (_) {
      return null;
    }
  }

  static void addAppointment(Map<String, dynamic> appointment) {
    final normalized = Map<String, dynamic>.from(appointment);

    final appointmentId = _asInt(normalized['appointmentId']);
    final bookingId = _asInt(normalized['bookingId']);
    final localId = normalized['id']?.toString();

    if (appointmentId != null) {
      final existingIndex = _appointments.indexWhere(
        (item) => _asInt(item['appointmentId']) == appointmentId,
      );

      if (existingIndex != -1) {
        _appointments[existingIndex] = {
          ..._appointments[existingIndex],
          ...normalized,
        };
        return;
      }
    }

    if (bookingId != null) {
      final existingIndex = _appointments.indexWhere(
        (item) => _asInt(item['bookingId']) == bookingId,
      );

      if (existingIndex != -1) {
        _appointments[existingIndex] = {
          ..._appointments[existingIndex],
          ...normalized,
        };
        return;
      }
    }

    if (localId != null && localId.isNotEmpty) {
      final existingIndex = _appointments.indexWhere(
        (item) => item['id']?.toString() == localId,
      );

      if (existingIndex != -1) {
        _appointments[existingIndex] = {
          ..._appointments[existingIndex],
          ...normalized,
        };
        return;
      }
    }

    _appointments.add(normalized);
  }

  static void updateAppointment(String id, Map<String, dynamic> updatedData) {
    final index = _appointments.indexWhere((item) => item['id'] == id);

    if (index != -1) {
      _appointments[index] = {
        ..._appointments[index],
        ...updatedData,
      };
    }
  }

  static void updateAppointmentByBackendId(
    int appointmentId,
    Map<String, dynamic> updatedData,
  ) {
    final index = _appointments.indexWhere(
      (item) => _asInt(item['appointmentId']) == appointmentId,
    );

    if (index != -1) {
      _appointments[index] = {
        ..._appointments[index],
        ...updatedData,
      };
    }
  }

  static void updateAppointmentByBookingId(
    int bookingId,
    Map<String, dynamic> updatedData,
  ) {
    final index = _appointments.indexWhere(
      (item) => _asInt(item['bookingId']) == bookingId,
    );

    if (index != -1) {
      _appointments[index] = {
        ..._appointments[index],
        ...updatedData,
      };
    }
  }

  static void deleteAppointment(String id) {
    _appointments.removeWhere((item) => item['id'] == id);
  }

  static void deleteAppointmentByBackendId(int appointmentId) {
    _appointments.removeWhere(
      (item) => _asInt(item['appointmentId']) == appointmentId,
    );
  }

  static void deleteAppointmentByBookingId(int bookingId) {
    _appointments.removeWhere(
      (item) => _asInt(item['bookingId']) == bookingId,
    );
  }

  static void clearAppointments() {
    _appointments.clear();
  }

  static bool existsById(String id) {
    return _appointments.any((item) => item['id'] == id);
  }

  static bool existsByBackendId(int appointmentId) {
    return _appointments.any(
      (item) => _asInt(item['appointmentId']) == appointmentId,
    );
  }

  static bool existsByBookingId(int bookingId) {
    return _appointments.any(
      (item) => _asInt(item['bookingId']) == bookingId,
    );
  }

  static String generateId() {
    int max = 0;

    for (final item in _appointments) {
      final id = item['id']?.toString() ?? '';
      final match = RegExp(r'^APT-(\d+)$').firstMatch(id);

      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '');
        if (value != null && value > max) {
          max = value;
        }
      }
    }

    final next = max + 1;
    return 'APT-${next.toString().padLeft(3, '0')}';
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
