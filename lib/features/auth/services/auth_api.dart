import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_result.dart';
import '../models/auth_user.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/friendly_errors.dart';

class AuthApi {
  static const String baseUrl = AppConfig.apiBaseUrl;
  static const Duration _timeout = AppConfig.authTimeout;

  final http.Client _client;

  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _postJson(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    return AuthResult.fromJson(_unwrapSuccess(response));
  }

  Future<AuthResult> register({
    required String firstName,
    required String middleName,
    required String lastName,
    required String email,
    required String phone,
    required String birthday,
    required String contactType,
    required String businessName,
    required String identificationType,
    required String taxNumber,
    required String province,
    required String city,
    required String address,
    required String password,
    String referralCode = '',
  }) async {
    final response = await _postJson(
      '/auth/register',
      body: {
        'first_name': _composeGivenNames(firstName, middleName),
        'middle_name': middleName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'birthday': birthday.trim(),
        'contact_type': contactType.trim(),
        'business_name': businessName.trim(),
        'identification_type': identificationType.trim(),
        'tax_number': taxNumber.trim(),
        'province': province.trim(),
        'city': city.trim(),
        'address': address.trim(),
        'password': password,
        if (referralCode.trim().isNotEmpty)
          'referral_code': referralCode.trim().toUpperCase(),
      },
    );

    return AuthResult.fromJson(_unwrapSuccess(response));
  }

  Future<String> forgotPassword({
    required String email,
  }) async {
    final response = await _postJson(
      '/auth/forgot-password',
      body: {'email': email.trim()},
    );

    final data = _unwrapSuccess(response);
    return _extractMessage(
      data,
      fallback: 'Te enviamos un enlace de recuperación a tu correo.',
    );
  }

  Future<AuthUser> getProfile(String token) async {
    final response = await _getJson(
      '/auth/me',
      token: token,
    );

    final data = _unwrapSuccess(response);
    return _extractUser(data);
  }

  Future<AuthUser> updateProfile({
    required String token,
    required String firstName,
    required String middleName,
    required String lastName,
    required String phone,
    required String birthday,
    required String contactType,
    required String businessName,
    required String identificationType,
    required String taxNumber,
    required String province,
    required String city,
    required String address,
    String? photoPath,
    required bool removePhoto,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/profile');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..fields.addAll({
        'first_name': _composeGivenNames(firstName, middleName),
        'middle_name': middleName.trim(),
        'last_name': lastName.trim(),
        'phone': phone.trim(),
        'birthday': birthday.trim(),
        'contact_type': contactType.trim(),
        'business_name': businessName.trim(),
        'identification_type': identificationType.trim(),
        'tax_number': taxNumber.trim(),
        'province': province.trim(),
        'city': city.trim(),
        'address': address.trim(),
        'remove_photo': removePhoto ? '1' : '0',
      });

    if (photoPath != null && photoPath.trim().isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photoPath.trim()),
      );
    }

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    final data = _unwrapSuccess(_decodeResponse(response));
    return _extractUser(data);
  }

  Future<AuthUser> updatePushNotificationsPreference({
    required String token,
    required bool enabled,
  }) async {
    final response = await _postJson(
      '/auth/profile',
      token: token,
      body: {
        'push_notifications_enabled': enabled,
      },
    );

    final data = _unwrapSuccess(response);
    return _extractUser(data);
  }

  Future<Map<String, String>> requestAccountDeletion({
    required String token,
  }) async {
    final response = await _postJson(
      '/auth/request-account-deletion',
      token: token,
      body: {
        'confirm': true,
      },
    );

    final data = _unwrapSuccess(response);
    final nestedData = data['data'];
    final webUrl = nestedData is Map ? nestedData['web_url']?.toString() : null;

    return {
      'message': _extractMessage(
        data,
        fallback: 'Tu cuenta fue eliminada correctamente.',
      ),
      if (webUrl != null && webUrl.trim().isNotEmpty) 'webUrl': webUrl.trim(),
    };
  }

  Future<void> logout(String token) async {
    try {
      await _postJson('/auth/logout', token: token);
    } catch (_) {
      // Aunque falle el backend, localmente igual cerramos sesión.
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    String? token,
  }) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token: token),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(token: token),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  Map<String, String> _headers({String? token}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
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
      'message': FriendlyErrors.clean(
        response.body,
        statusCode: response.statusCode,
        fallback: 'No se pudo interpretar la respuesta del servidor.',
      ),
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
        fallback: _fallbackMessageForStatus(statusCode),
      ),
    );
  }

  AuthUser _extractUser(Map<String, dynamic> data) {
    final raw = data['data'];
    if (raw is Map<String, dynamic>) {
      final user = raw['user'];
      if (user is Map<String, dynamic>) {
        return AuthUser.fromJson(user);
      }
      return AuthUser.fromJson(raw);
    }

    return AuthUser.fromJson(data);
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

    for (final value in candidates) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return FriendlyErrors.clean(
          text,
          fallback: fallback,
          statusCode:
              data['_statusCode'] is int ? data['_statusCode'] as int : null,
        );
      }
    }

    return fallback;
  }

  String _fallbackMessageForStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Tu sesión ya no es válida. Intenta nuevamente.';
    }
    if (statusCode >= 500) {
      return 'El servidor no pudo procesar la solicitud en este momento.';
    }
    return 'No se pudo completar la solicitud.';
  }

  String _composeGivenNames(String firstName, String middleName) {
    return '${firstName.trim()} ${middleName.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
