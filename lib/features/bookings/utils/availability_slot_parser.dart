class AvailabilitySlotParser {
  const AvailabilitySlotParser._();

  static List<String> extractAvailableSlots(
    dynamic data, {
    required String selectedDateKey,
  }) {
    final slots = <String>{};

    void addSlot(String value) {
      final time = normalizeSlotTime(value, selectedDateKey: selectedDateKey);
      if (time != null) slots.add(time);
    }

    void collect(dynamic node, {bool slotContext = false, String? keyHint}) {
      if (node == null) return;

      if (node is String) {
        if (slotContext || _isTimeLikeKey(keyHint)) addSlot(node);
        return;
      }

      if (node is List) {
        for (final item in node) {
          collect(item, slotContext: slotContext, keyHint: keyHint);
        }
        return;
      }

      if (node is! Map) return;

      final map = Map<dynamic, dynamic>.from(node);
      if (slotContext && _isExplicitlyUnavailable(map)) return;

      if (map.containsKey(selectedDateKey)) {
        collect(map[selectedDateKey], slotContext: true);
      }

      for (final key in _slotContainerKeys) {
        if (map.containsKey(key)) {
          collect(map[key], slotContext: true, keyHint: key);
        }
      }

      for (final entry in map.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;

        if (key == selectedDateKey || _slotContainerKeys.contains(key)) {
          continue;
        }

        final keyTime = normalizeSlotTime(key, selectedDateKey: selectedDateKey);
        if (keyTime != null) {
          if (!_isExplicitlyUnavailable(value)) slots.add(keyTime);
          if (value is Map || value is List) {
            collect(value, slotContext: true, keyHint: key);
          }
          continue;
        }

        if (_isMetadataKey(key)) continue;

        collect(
          value,
          slotContext: slotContext || _isAvailabilityBranchKey(key),
          keyHint: key,
        );
      }
    }

    collect(data);

    return slots.toList()..sort();
  }

  static String? normalizeSlotTime(
    String value, {
    required String selectedDateKey,
  }) {
    final text = value.trim();

    final directMatch =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (directMatch != null) {
      final hour = int.tryParse(directMatch.group(1) ?? '');
      if (hour == null || hour > 23) return null;
      return '${hour.toString().padLeft(2, '0')}:${directMatch.group(2)}';
    }

    if (text.startsWith(selectedDateKey)) {
      final dateTimeMatch =
          RegExp(r'^\d{4}-\d{2}-\d{2}[ T](\d{1,2}):(\d{2})')
              .firstMatch(text);
      if (dateTimeMatch != null) {
        final hour = int.tryParse(dateTimeMatch.group(1) ?? '');
        if (hour == null || hour > 23) return null;
        return '${hour.toString().padLeft(2, '0')}:${dateTimeMatch.group(2)}';
      }
    }

    return null;
  }

  static bool _isExplicitlyUnavailable(dynamic value) {
    if (value == null) return false;
    if (value == false) return true;
    if (value is num) return value <= 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'false' ||
          normalized == '0' ||
          normalized == 'unavailable' ||
          normalized == 'busy' ||
          normalized == 'booked';
    }
    if (value is Map) {
      final map = Map<dynamic, dynamic>.from(value);
      for (final key in const [
        'available',
        'is_available',
        'isAvailable',
        'free',
        'enabled',
      ]) {
        if (map.containsKey(key)) return !_truthy(map[key]);
      }
      for (final key in const ['status', 'state']) {
        final normalized = map[key]?.toString().trim().toLowerCase();
        if (normalized == 'unavailable' ||
            normalized == 'busy' ||
            normalized == 'booked') {
          return true;
        }
      }
    }
    return false;
  }

  static bool _truthy(dynamic value) {
    if (value == true) return true;
    if (value is num) return value > 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'available' ||
        normalized == 'free';
  }

  static bool _isMetadataKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'habito' ||
        normalized == 'meta' ||
        normalized == 'metadata' ||
        normalized.contains('minimum_booking') ||
        normalized.contains('notice') ||
        normalized.contains('cutoff') ||
        normalized.contains('timezone');
  }

  static bool _isAvailabilityBranchKey(String key) {
    final normalized = key.trim().toLowerCase();
    return normalized == 'data' ||
        normalized == 'availability' ||
        normalized == 'result' ||
        normalized == 'results' ||
        normalized == 'days' ||
        normalized == 'dates' ||
        normalized == 'providers' ||
        normalized == 'employees' ||
        normalized == 'locations' ||
        normalized == 'appointments';
  }

  static bool _isTimeLikeKey(String? key) {
    final normalized = key?.trim().toLowerCase();
    return normalized == 'time' ||
        normalized == 'start' ||
        normalized == 'start_time' ||
        normalized == 'starttime' ||
        normalized == 'datetime' ||
        normalized == 'date_time' ||
        normalized == 'booking_start' ||
        normalized == 'bookingstart';
  }

  static const Set<String> _slotContainerKeys = {
    'slots',
    'availableSlots',
    'available_slots',
    'freeSlots',
    'free_slots',
    'times',
    'timeSlots',
    'time_slots',
    'available',
    'appointments',
    'periods',
    'intervals',
  };
}
