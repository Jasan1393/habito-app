import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'app_logger.dart';

class ReferralLinkService {
  ReferralLinkService._();

  static const String _pendingCodeKey = 'habito_pending_referral_code';
  static const String _pendingLinkKey = 'habito_pending_referral_link';
  static const String _pendingSourceKey = 'habito_pending_referral_source';
  static const String _pendingSavedAtKey = 'habito_pending_referral_saved_at';
  static const String _installReferrerCheckedKey =
      'habito_install_referrer_checked';
  static const MethodChannel _installReferrerChannel = MethodChannel(
    'com.habitobarberia.app/install_referrer',
  );
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

    await _readInstallReferrerOnce();

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
      await preferences.remove(_pendingLinkKey);
      await preferences.remove(_pendingSourceKey);
      await preferences.remove(_pendingSavedAtKey);
      return code;
    }

    return null;
  }

  static Future<void> savePendingReferralCode(
    String code, {
    String source = 'manual',
    Uri? link,
  }) async {
    final normalized = _normalizeCode(code);
    if (normalized.isEmpty) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingCodeKey, normalized);
    await preferences.setString(_pendingSourceKey, source);
    await preferences.setString(
      _pendingSavedAtKey,
      DateTime.now().toIso8601String(),
    );

    if (link != null) {
      await preferences.setString(_pendingLinkKey, link.toString());
    }

    unawaited(AnalyticsService.logReferralCodeSaved(source: source));
  }

  static Future<void> _readInstallReferrerOnce() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final preferences = await SharedPreferences.getInstance();
    final alreadyChecked =
        preferences.getBool(_installReferrerCheckedKey) ?? false;
    if (alreadyChecked) return;

    final existingPendingCode = preferences.getString(_pendingCodeKey)?.trim();
    if (existingPendingCode != null && existingPendingCode.isNotEmpty) {
      await preferences.setBool(_installReferrerCheckedKey, true);
      return;
    }

    var shouldMarkChecked = false;

    try {
      final payload = await _installReferrerChannel
          .invokeMapMethod<String, dynamic>('getInstallReferrer')
          .timeout(const Duration(seconds: 4));
      final responseCode = payload?['responseCode'] as int?;
      final rawReferrer =
          (payload?['installReferrer'] as String?)?.trim() ?? '';

      // SERVICE_UNAVAILABLE is transient; retry on the next app start.
      shouldMarkChecked = responseCode != 1;

      if (rawReferrer.isNotEmpty) {
        final code = _extractReferralCodeFromRawReferrer(rawReferrer);
        if (code.isNotEmpty) {
          await savePendingReferralCode(
            code,
            source: 'install_referrer',
            link: Uri(
              scheme: 'https',
              host: 'play.google.com',
              path: '/store/apps/details',
              queryParameters: {
                'id': 'com.habitobarberia.app',
                'referrer': rawReferrer,
              },
            ),
          );
        }
      }
    } on TimeoutException catch (e) {
      AppLogger.error('Timeout leyendo Play Install Referrer', error: e);
    } on PlatformException catch (e) {
      AppLogger.error('No se pudo leer Play Install Referrer', error: e);
    } catch (e) {
      AppLogger.error('Error inesperado leyendo Play Install Referrer',
          error: e);
    } finally {
      if (shouldMarkChecked) {
        await preferences.setBool(_installReferrerCheckedKey, true);
      }
    }
  }

  static Future<void> _persistReferralCodeFromUri(Uri uri) async {
    final code = _extractReferralCode(uri);
    if (code.isEmpty) return;
    await savePendingReferralCode(code, source: 'link', link: uri);
  }

  static String _extractReferralCodeFromRawReferrer(String rawReferrer) {
    final decoded = Uri.decodeComponent(rawReferrer);
    final uri = Uri.tryParse(
      decoded.contains('://')
          ? decoded
          : 'https://habitobarberia.com/?$decoded',
    );

    if (uri == null) return '';
    return _extractReferralCode(uri);
  }

  static String _extractReferralCode(Uri uri, {int depth = 0}) {
    final pathSegments = uri.pathSegments;
    final referIndex = pathSegments.indexWhere(
      (segment) => segment.toLowerCase() == 'referir',
    );

    if (referIndex >= 0 && pathSegments.length > referIndex + 1) {
      return _normalizeCode(pathSegments[referIndex + 1]);
    }

    final queryCode = uri.queryParameters['codigo'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['ref'] ??
        uri.queryParameters['referral_code'];
    final directCode = _normalizeCode(queryCode ?? '');
    if (directCode.isNotEmpty) return directCode;

    final referrer = uri.queryParameters['referrer'];
    if (depth < 2 && referrer != null && referrer.trim().isNotEmpty) {
      final decoded = Uri.decodeComponent(referrer);
      final nestedUri = Uri.tryParse(
        decoded.contains('://')
            ? decoded
            : 'https://habitobarberia.com/?$decoded',
      );

      if (nestedUri != null) {
        return _extractReferralCode(nestedUri, depth: depth + 1);
      }
    }

    return '';
  }

  static String _normalizeCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }
}
