import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../models/points_history_entry.dart';
import '../../models/points_summary.dart';

class PointsApi {
  static const String _baseUrl = AppConfig.apiBaseUrl;
  static const Duration _timeout = AppConfig.authTimeout;

  final http.Client _client;

  PointsApi({http.Client? client}) : _client = client ?? http.Client();

  Future<({
    PointsSummary summary,
    List<PointsHistoryEntry> history,
    int historyTotal,
  })> getSummary({
    required String token,
    int historyLimit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/points/summary').replace(
      queryParameters: {
        'history_limit': historyLimit.toString(),
      },
    );

    final response = await _client
        .get(uri, headers: _headers(token))
        .timeout(_timeout);
    final data = _unwrapSuccess(_decodeResponse(response));
    final payload = _asMap(data['data']);
    final summary = PointsSummary.fromJson(_asMap(payload['summary']));
    final historyPayload = _asMap(payload['history']);
    final items = historyPayload['items'] is List
        ? List<dynamic>.from(historyPayload['items'])
        : const <dynamic>[];

    return (
      summary: summary,
      history: items
          .whereType<Map>()
          .map((item) => PointsHistoryEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      historyTotal: _parseInt(historyPayload['total']) ?? items.length,
    );
  }

  Future<List<PointsHistoryEntry>> getHistory({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/points/history').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    final response = await _client
        .get(uri, headers: _headers(token))
        .timeout(_timeout);
    final data = _unwrapSuccess(_decodeResponse(response));
    final payload = _asMap(data['data']);
    final items = payload['items'] is List
        ? List<dynamic>.from(payload['items'])
        : const <dynamic>[];

    return items
        .whereType<Map>()
        .map(
          (item) => PointsHistoryEntry.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Map<String, String> _headers(String token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return {
          ...decoded,
          '_statusCode': response.statusCode,
        };
      }
    } catch (_) {
      // handled below
    }

    return {
      'success': false,
      '_statusCode': response.statusCode,
      'message': 'No se pudo interpretar la respuesta del servidor.',
      'raw': response.body,
    };
  }

  Map<String, dynamic> _unwrapSuccess(Map<String, dynamic> data) {
    final statusCode =
        data['_statusCode'] is int ? data['_statusCode'] as int : 0;
    final success = data['success'] == true ||
        (statusCode >= 200 && statusCode < 300 && data['error'] == null);

    if (success) {
      return data;
    }

    throw Exception(
      _extractMessage(
        data,
        fallback: statusCode >= 500
            ? 'No pudimos cargar tus puntos en este momento.'
            : 'No pudimos consultar tu saldo de puntos.',
      ),
    );
  }

  String _extractMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final nestedData = data['data'];
    final candidates = [
      data['message'],
      data['error'],
      nestedData is Map ? nestedData['message'] : null,
      nestedData is Map ? nestedData['error'] : null,
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }

    return fallback;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
