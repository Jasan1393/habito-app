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

      final items = decoded
          .whereType<Map>()
          .map((item) => _normalizeStoredItem(Map<String, dynamic>.from(item)))
          .toList();

      items.sort((a, b) {
        final aDate = DateTime.tryParse((a['received_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['received_at'] ?? '').toString());
        final aMs = aDate?.millisecondsSinceEpoch ?? 0;
        final bMs = bDate?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

      _setUnreadCount(items);
      return items;
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
      receivedAt: receivedAt,
    );

    final items = await load();
    items.removeWhere((item) => item['id'] == id);
    items.insert(0, {
      'id': id,
      'title': normalizedTitle,
      'body': normalizedBody,
      'data': normalizedData,
      'category': category,
      'received_at': (receivedAt ?? DateTime.now()).toIso8601String(),
      'read': false,
    });

    await _save(items.take(_maxItems).toList());
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

    return {
      ...item,
      'title': title.isEmpty ? 'Habito' : title,
      'body': body,
      'data': data,
      'category': _normalizeCategory(
        item['category'],
        title: title,
        body: body,
        data: data,
      ),
      'read': item['read'] == true,
    };
  }

  static Map<String, dynamic> _normalizeData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
    if (rawData is Map) {
      return rawData.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
    return <String, dynamic>{};
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
