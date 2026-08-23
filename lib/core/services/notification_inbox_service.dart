import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class NotificationInboxService {
  NotificationInboxService._();

  static const String _fileName = 'notification_inbox.json';
  static const int _maxItems = 80;
  static const String categoryAppointment = 'appointment';
  static const String categoryOrder = 'order';
  static const String categoryPromotion = 'promotion';
  static const String categorySchedule = 'schedule';
  static const String categoryAccount = 'account';
  static const String categoryGeneral = 'general';
  static final DateTime _minimumValidReceivedAt = DateTime(2024);
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static Future<List<Map<String, dynamic>>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        _setUnreadCount(const <Map<String, dynamic>>[]);
        return <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        _setUnreadCount(const <Map<String, dynamic>>[]);
        return <Map<String, dynamic>>[];
      }

      var shouldRewrite = false;
      final items = <Map<String, dynamic>>[];

      for (final rawItem in decoded.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final normalized = _normalizeStoredItem(item);

        if (!_isMeaningfulItem(normalized)) {
          shouldRewrite = true;
          continue;
        }

        if (_receivedAtNeedsRepair(item['received_at'])) {
          shouldRewrite = true;
        }

        items.add(normalized);
      }

      items.sort((a, b) {
        final aDate = DateTime.tryParse((a['received_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['received_at'] ?? '').toString());
        final aMs = aDate?.millisecondsSinceEpoch ?? 0;
        final bMs = bDate?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

      final normalizedItems = items.take(_maxItems).toList();
      if (shouldRewrite || normalizedItems.length != items.length) {
        await _save(normalizedItems);
      } else {
        _setUnreadCount(normalizedItems);
      }
      return normalizedItems;
    } catch (_) {
      _setUnreadCount(const <Map<String, dynamic>>[]);
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> refreshUnreadCount() async {
    await load();
  }

  static Future<void> record({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? messageId,
    DateTime? receivedAt,
  }) async {
    final normalizedTitle = title.trim().isEmpty ? 'Habito' : title.trim();
    final normalizedBody = body.trim();
    final normalizedData = _normalizeData(data);

    if (!_isMeaningfulPayload(
      title: normalizedTitle,
      body: normalizedBody,
      data: normalizedData,
    )) {
      return;
    }

    final storedAt = _safeReceivedAt(receivedAt);
    final category = inferCategory(
      title: normalizedTitle,
      body: normalizedBody,
      data: normalizedData,
    );
    final id = _buildId(
      messageId: messageId,
      title: normalizedTitle,
      body: normalizedBody,
      data: normalizedData,
      receivedAt: storedAt,
    );

    final items = await load();
    items.removeWhere((item) => item['id'] == id);
    items.insert(0, {
      'id': id,
      'title': normalizedTitle,
      'body': normalizedBody,
      'data': normalizedData,
      'category': category,
      'received_at': storedAt.toIso8601String(),
      'read': false,
    });

    await _save(items.take(_maxItems).toList());
  }

  static Future<List<Map<String, dynamic>>> syncRemoteItems(
    List<dynamic> remoteItems,
  ) async {
    if (remoteItems.isEmpty) {
      return load();
    }

    final localItems = await load();
    final byId = <String, Map<String, dynamic>>{};

    for (final item in localItems) {
      final id = (item['id'] ?? '').toString();
      if (id.isNotEmpty) {
        byId[id] = item;
      }
    }

    for (final rawItem in remoteItems) {
      if (rawItem is! Map) continue;

      final normalized = _normalizeRemoteItem(rawItem);
      if (!_isMeaningfulItem(normalized)) continue;

      final id = (normalized['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final existing = byId[id];
      if (existing != null && existing['read'] == true) {
        normalized['read'] = true;
      }

      byId[id] = normalized;
    }

    final merged = byId.values.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse((a['received_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['received_at'] ?? '').toString());
        final aMs = aDate?.millisecondsSinceEpoch ?? 0;
        final bMs = bDate?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

    final limited = merged.take(_maxItems).toList();
    await _save(limited);
    return limited;
  }

  static Future<void> markRead(String id) async {
    final items = await load();
    var changed = false;

    for (final item in items) {
      if (item['id'] == id && item['read'] != true) {
        item['read'] = true;
        changed = true;
      }
    }

    if (changed) {
      await _save(items);
    }
  }

  static Future<void> markAllRead() async {
    final items = await load();
    var changed = false;

    for (final item in items) {
      if (item['read'] != true) {
        item['read'] = true;
        changed = true;
      }
    }

    if (changed) {
      await _save(items);
    }
  }

  static Future<void> deleteById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;

    final items = await load();
    final nextItems =
        items.where((item) => item['id'] != normalizedId).toList();

    if (nextItems.length == items.length) return;
    await _save(nextItems);
  }

  static Future<void> clear() async {
    await _save(<Map<String, dynamic>>[]);
  }

  static String categoryForItem(Map<String, dynamic> item) {
    return _normalizeCategory(
      item['category'],
      title: (item['title'] ?? '').toString(),
      body: (item['body'] ?? '').toString(),
      data: _normalizeData(item['data']),
    );
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<void> _save(List<Map<String, dynamic>> items) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(items), flush: true);
    _setUnreadCount(items);
  }

  static void _setUnreadCount(List<Map<String, dynamic>> items) {
    final count = items.where((item) => item['read'] != true).length;
    if (unreadCountNotifier.value != count) {
      unreadCountNotifier.value = count;
    }
  }

  static String _buildId({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? messageId,
    DateTime? receivedAt,
  }) {
    final explicit = messageId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final linkedEntity = data['appointmentId'] ??
        data['appointment_id'] ??
        data['bookingId'] ??
        data['booking_id'] ??
        data['orderId'] ??
        data['order_id'] ??
        data['order'];
    final stamp = (receivedAt ?? DateTime.now()).millisecondsSinceEpoch;
    return '$stamp|$linkedEntity|$title|$body'.hashCode.toString();
  }

  static Map<String, dynamic> _normalizeStoredItem(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Habito').toString().trim();
    final body = (item['body'] ?? '').toString().trim();
    final data = _normalizeData(item['data']);
    final receivedAt = _safeReceivedAt(_parseReceivedAt(item['received_at']));

    return {
      ...item,
      'title': title.isEmpty ? 'Habito' : title,
      'body': body,
      'data': data,
      'received_at': receivedAt.toIso8601String(),
      'category': _normalizeCategory(
        item['category'],
        title: title,
        body: body,
        data: data,
      ),
      'read': item['read'] == true,
    };
  }

  static Map<String, dynamic> _normalizeRemoteItem(Map rawItem) {
    final data = _normalizeData(rawItem['data']);
    final targetScreen = (rawItem['target_screen'] ??
            rawItem['targetScreen'] ??
            data['target_screen'] ??
            data['targetScreen'] ??
            '')
        .toString()
        .trim();
    final rawId =
        (rawItem['id'] ?? rawItem['notification_id'] ?? '').toString().trim();
    final title =
        (rawItem['title'] ?? data['title'] ?? 'Habito').toString().trim();
    final body = (rawItem['body'] ?? data['body'] ?? data['message'] ?? '')
        .toString()
        .trim();
    final receivedAt = _safeReceivedAt(
      _parseReceivedAt(rawItem['received_at'] ?? rawItem['created_at']),
    );
    final remoteId = rawId.isNotEmpty
        ? 'remote:$rawId'
        : 'remote:${_buildId(
            title: title,
            body: body,
            data: data,
            receivedAt: receivedAt,
          )}';

    final normalizedData = {
      ...data,
      if (targetScreen.isNotEmpty) 'target_screen': targetScreen,
    };

    return {
      'id': remoteId,
      'title': title.isEmpty ? 'Habito' : title,
      'body': body,
      'data': normalizedData,
      'category': _normalizeCategory(
        rawItem['category'],
        title: title,
        body: body,
        data: normalizedData,
      ),
      'received_at': receivedAt.toIso8601String(),
      'read': rawItem['read'] == true,
    };
  }

  static Map<String, dynamic> _normalizeData(dynamic rawData) {
    Map<String, dynamic> normalized;

    if (rawData is Map<String, dynamic>) {
      normalized = rawData.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } else if (rawData is Map) {
      normalized = rawData.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } else {
      return <String, dynamic>{};
    }

    final rawPayload = normalized['payload']?.toString().trim() ?? '';
    if (rawPayload.isEmpty) return normalized;

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map) {
        final payloadData = decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
        return {
          ...payloadData,
          ...normalized,
        };
      }
    } catch (_) {
      // Algunas notificaciones no usan payload JSON; se conservan tal cual.
    }

    return normalized;
  }

  static bool _isMeaningfulItem(Map<String, dynamic> item) {
    return _isMeaningfulPayload(
      title: (item['title'] ?? '').toString(),
      body: (item['body'] ?? '').toString(),
      data: _normalizeData(item['data']),
    );
  }

  static bool _isMeaningfulPayload({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    if (body.trim().isNotEmpty || data.isNotEmpty) return true;

    final normalizedTitle = _foldForLooseCompare(title.trim());
    return normalizedTitle.isNotEmpty &&
        normalizedTitle != 'habito' &&
        normalizedTitle != 'hábito' &&
        normalizedTitle != 'habito barberia' &&
        normalizedTitle != 'hábito barbería';
  }

  static String _foldForLooseCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u00e1', 'a')
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00ed', 'i')
        .replaceAll('\u00f3', 'o')
        .replaceAll('\u00fa', 'u')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f1', 'n')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime _safeReceivedAt(DateTime? receivedAt) {
    final now = DateTime.now();
    if (receivedAt == null) return now;

    final local = receivedAt.toLocal();
    if (local.isBefore(_minimumValidReceivedAt)) return now;
    if (local.isAfter(now.add(const Duration(days: 1)))) return now;

    return local;
  }

  static bool _receivedAtNeedsRepair(dynamic value) {
    final parsed = _parseReceivedAt(value);
    if (parsed == null) return true;

    final local = parsed.toLocal();
    final now = DateTime.now();
    return local.isBefore(_minimumValidReceivedAt) ||
        local.isAfter(now.add(const Duration(days: 1)));
  }

  static DateTime? _parseReceivedAt(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  static String inferCategory({
    required Map<String, dynamic> data,
    String title = '',
    String body = '',
  }) {
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final target = (data['target_screen'] ??
            data['targetScreen'] ??
            data['screen'] ??
            data['target'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final text = '$title $body'.toLowerCase();
    final appointmentId = _parseInt(
      data['appointmentId'] ??
          data['appointment_id'] ??
          data['appointment'] ??
          data['bookingId'] ??
          data['booking_id'] ??
          data['booking'],
    );
    final orderId = _parseInt(
      data['orderId'] ?? data['order_id'] ?? data['order'],
    );

    if (appointmentId != null ||
        type.contains('booking') ||
        type.contains('appointment') ||
        type.contains('cita')) {
      return categoryAppointment;
    }

    if (orderId != null ||
        type.contains('order') ||
        type.contains('pedido') ||
        target == 'orders') {
      return categoryOrder;
    }

    if (type.contains('promo') ||
        type.contains('offer') ||
        type.contains('campaign') ||
        type.contains('discount') ||
        text.contains('promo') ||
        text.contains('oferta')) {
      return categoryPromotion;
    }

    if (type.contains('schedule') ||
        type.contains('holiday') ||
        type.contains('horario') ||
        type.contains('hours') ||
        target == 'locations') {
      return categorySchedule;
    }

    if (type.contains('account') ||
        type.contains('profile') ||
        type.contains('welcome') ||
        type.contains('auth') ||
        target == 'profile') {
      return categoryAccount;
    }

    return categoryGeneral;
  }

  static String _normalizeCategory(
    dynamic rawValue, {
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    final normalized = rawValue?.toString().trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'appointment':
      case 'appointments':
      case 'booking':
      case 'bookings':
      case 'cita':
      case 'citas':
        return categoryAppointment;
      case 'order':
      case 'orders':
      case 'pedido':
      case 'pedidos':
        return categoryOrder;
      case 'promotion':
      case 'promotions':
      case 'promo':
      case 'promos':
      case 'offer':
      case 'offers':
        return categoryPromotion;
      case 'schedule':
      case 'holiday':
      case 'hours':
      case 'horario':
      case 'operational':
        return categorySchedule;
      case 'account':
      case 'profile':
      case 'welcome':
        return categoryAccount;
      case 'general':
        return categoryGeneral;
      default:
        return inferCategory(title: title, body: body, data: data);
    }
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
