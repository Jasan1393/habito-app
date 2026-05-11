import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class ReferralLinkService {
  ReferralLinkService._();

  static const String _pendingCodeKey = 'habito_pending_referral_code';
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;

  static Future<void> initialize() async {
    if (_subscription != null) return;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _persistReferralCodeFromUri(initialUri);
      }
    } catch (e) {
      AppLogger.error('No se pudo leer el link inicial de referido', error: e);
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(_persistReferralCodeFromUri(uri));
      },
      onError: (Object error) {
        AppLogger.error('Error escuchando links de referido', error: error);
      },
    );
  }

  static Future<String?> getPendingReferralCode() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_pendingCodeKey)?.trim();
    return code == null || code.isEmpty ? null : code;
  }

  static Future<String?> consumePendingReferralCode() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_pendingCodeKey)?.trim();

    if (code != null && code.isNotEmpty) {
      await preferences.remove(_pendingCodeKey);
      return code;
    }

    return null;
  }

  static Future<void> savePendingReferralCode(String code) async {
    final normalized = _normalizeCode(code);
    if (normalized.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingCodeKey, normalized);
  }

  static Future<void> _persistReferralCodeFromUri(Uri uri) async {
    final code = _extractReferralCode(uri);
    if (code.isEmpty) return;
    await savePendingReferralCode(code);
  }

  static String _extractReferralCode(Uri uri) {
    final pathSegments = uri.pathSegments;
    final referIndex = pathSegments.indexWhere(
      (segment) => segment.toLowerCase() == 'referir',
    );

    if (referIndex >= 0 && pathSegments.length > referIndex + 1) {
      return _normalizeCode(pathSegments[referIndex + 1]);
    }

    final queryCode = uri.queryParameters['codigo'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['ref'];
    return _normalizeCode(queryCode ?? '');
  }

  static String _normalizeCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }
}
