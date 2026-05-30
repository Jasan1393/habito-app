import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AnalyticsService {
  const AnalyticsService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);
  static final FacebookAppEvents _facebook = FacebookAppEvents();
  static const MethodChannel _tiktok = MethodChannel(
    'com.habitobarberia.app/tiktok_events',
  );

  static const bool _forceCrashlyticsInDebug =
      bool.fromEnvironment('HABITO_CRASHLYTICS_DEBUG');
  static const bool _facebookEventsEnabled = bool.fromEnvironment(
    'HABITO_FACEBOOK_EVENTS_ENABLED',
    defaultValue: true,
  );
  static const bool _facebookAdTrackingEnabled = bool.fromEnvironment(
    'HABITO_FACEBOOK_AD_TRACKING_ENABLED',
    defaultValue: true,
  );
  static const String _facebookAppId = String.fromEnvironment(
    'HABITO_FACEBOOK_APP_ID',
    defaultValue: '13459473576995552',
  );
  static const bool _tiktokEventsEnabled = bool.fromEnvironment(
    'HABITO_TIKTOK_EVENTS_ENABLED',
    defaultValue: true,
  );
  static const String _tiktokAppId = String.fromEnvironment(
    'HABITO_TIKTOK_APP_ID',
    defaultValue: '7645715146475700242',
  );
  static const String _currency = 'USD';

  static Future<void> initialize() async {
    await analytics.setAnalyticsCollectionEnabled(true);
    await _initializeFacebook();

    if (kIsWeb) return;

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode || _forceCrashlyticsInDebug,
    );
  }

  static Future<void> identifyUser({
    int? userId,
    String email = '',
    String phone = '',
    String displayName = '',
    bool hasAmeliaLink = false,
    bool hasWooLink = false,
    String contactType = 'unknown',
    bool pointsEnabled = false,
  }) async {
    final analyticsUserId = userId != null && userId > 0 ? '$userId' : null;

    await analytics.setUserId(id: analyticsUserId);
    await _syncFacebookUser(analyticsUserId);
    await _syncTikTokUser(
      userId: analyticsUserId,
      email: email,
      phone: phone,
      displayName: displayName,
    );

    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setUserIdentifier(
        analyticsUserId ?? '',
      );
    }

    if (analyticsUserId == null) return;

    await Future.wait([
      analytics.setUserProperty(
        name: 'has_amelia_link',
        value: hasAmeliaLink.toString(),
      ),
      analytics.setUserProperty(
        name: 'has_woo_link',
        value: hasWooLink.toString(),
      ),
      analytics.setUserProperty(
        name: 'contact_type',
        value: _safeText(contactType, fallback: 'unknown'),
      ),
      analytics.setUserProperty(
        name: 'points_enabled',
        value: pointsEnabled.toString(),
      ),
    ]);
  }

  static Future<void> logLogin({String method = 'email'}) async {
    final safeMethod = _safeText(method);
    await Future.wait([
      analytics.logLogin(loginMethod: safeMethod),
      _logFacebookEvent('login', parameters: {'method': safeMethod}),
      _logTikTokEvent('login', parameters: {'method': safeMethod}),
    ]);
  }

  static Future<void> logSignUp({
    String method = 'email',
    bool hasReferral = false,
  }) async {
    final signUpMethod = hasReferral ? '${method}_referral' : method;
    final safeMethod = _safeText(signUpMethod);

    await Future.wait([
      analytics.logSignUp(signUpMethod: safeMethod),
      _safeFacebook(
        () => _facebook.logCompletedRegistration(
          registrationMethod: safeMethod,
          parameters: {'has_referral': hasReferral ? 1 : 0},
        ),
      ),
      _logTikTokEvent(
        'complete_registration',
        parameters: {
          'method': safeMethod,
          'has_referral': hasReferral ? 1 : 0,
        },
      ),
    ]);
  }

  static Future<void> logReferralCodeSaved({
    required String source,
  }) {
    return logEvent(
      'referral_code_saved',
      parameters: {'source': _safeText(source)},
    );
  }

  static Future<void> logReferralCodeApplied({
    required String source,
  }) {
    return logEvent(
      'referral_code_applied',
      parameters: {'source': _safeText(source)},
    );
  }

  static Future<void> logBookingCreated({
    required int serviceId,
    required int employeeId,
    required int locationId,
    required String paymentMethod,
    required double total,
    required double redeemedPoints,
    required double birthdayPoints,
  }) {
    return logEvent(
      'booking_created',
      parameters: {
        'service_id': serviceId,
        'employee_id': employeeId,
        'location_id': locationId,
        'content_id': serviceId,
        'content_type': 'service',
        'content_category': 'booking',
        'content_name': 'habito_service_$serviceId',
        'brand': 'habito',
        'payment_method': _safeText(paymentMethod),
        'value': _roundMoney(total),
        'redeemed_points': redeemedPoints.round(),
        'birthday_points': birthdayPoints.round(),
      },
      facebookValueToSum: _roundMoney(total),
    );
  }

  static Future<void> logOrderCreated({
    required int itemCount,
    required String fulfillmentMethod,
    required String paymentMethod,
    required double total,
    required double redeemedPoints,
  }) {
    return logEvent(
      'order_created',
      parameters: {
        'item_count': itemCount,
        'content_id': 'habito_order',
        'content_type': 'product',
        'content_category': 'shop',
        'content_name': 'habito_shop_order',
        'brand': 'habito',
        'quantity': itemCount,
        'fulfillment_method': _safeText(fulfillmentMethod),
        'payment_method': _safeText(paymentMethod),
        'value': _roundMoney(total),
        'redeemed_points': redeemedPoints.round(),
      },
      facebookValueToSum: _roundMoney(total),
    );
  }

  static Future<void> logPaymentProofUploaded({
    required int orderId,
  }) {
    return logEvent(
      'payment_proof_uploaded',
      parameters: {'order_id': orderId},
    );
  }

  static Future<void> logFailure(
    String eventName, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> parameters = const {},
    bool recordCrashlytics = true,
  }) async {
    await logEvent('${eventName}_failed', parameters: parameters);
    if (recordCrashlytics && error != null) {
      await recordError(error, stackTrace, fatal: false);
    }
  }

  static Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) {
    if (kIsWeb) return Future.value();
    return fatal
        ? FirebaseCrashlytics.instance.recordFlutterFatalError(details)
        : FirebaseCrashlytics.instance.recordFlutterError(details);
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) {
    if (kIsWeb) return Future.value();
    return FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      fatal: fatal,
    );
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const {},
    double? facebookValueToSum,
  }) async {
    final safeName = _safeEventName(name);
    final sanitized = _sanitizeParameters(parameters);

    await Future.wait([
      analytics.logEvent(name: safeName, parameters: sanitized),
      _logFacebookEvent(
        safeName,
        parameters: sanitized,
        valueToSum: facebookValueToSum,
      ),
      _logTikTokEvent(
        safeName,
        parameters: sanitized,
        valueToSum: facebookValueToSum,
      ),
    ]);
  }

  static bool get _isFacebookAvailable => !kIsWeb && _facebookEventsEnabled;
  static bool get _isTikTokAvailable =>
      !kIsWeb && _tiktokEventsEnabled && _tiktokAppId.trim().isNotEmpty;

  static Future<void> _initializeFacebook() async {
    if (!_isFacebookAvailable) return;

    final appId = _facebookAppId.trim();
    if (appId.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Meta App Events disabled: missing HABITO_FACEBOOK_APP_ID.',
        );
      }
      return;
    }

    await _safeFacebook(() async {
      await _facebook.setGraphApiVersion('v24.0');
      await _facebook.setAdvertiserTracking(
        enabled: _facebookAdTrackingEnabled,
        collectId: _facebookAdTrackingEnabled,
      );
      await _facebook.setAutoLogAppEventsEnabled(true);
      await _facebook.activateApp(applicationId: appId);
    });
  }

  static Future<void> _syncFacebookUser(String? userId) {
    return _safeFacebook(() {
      if (userId == null) return _facebook.clearUserID();
      return _facebook.setUserID(userId);
    });
  }

  static Future<void> _syncTikTokUser({
    required String? userId,
    required String email,
    required String phone,
    required String displayName,
  }) {
    return _safeTikTok(() async {
      if (userId == null) {
        await _tiktok.invokeMethod<void>('logout');
        return;
      }

      await _tiktok.invokeMethod<void>('identify', {
        'externalId': userId,
        'externalUserName': displayName.trim(),
        'phoneNumber': _digitsOnly(phone),
        'email': email.trim().toLowerCase(),
      });
    });
  }

  static Future<void> _logFacebookEvent(
    String name, {
    Map<String, Object?> parameters = const {},
    double? valueToSum,
  }) {
    return _safeFacebook(() {
      final sanitized = _sanitizeParameters(parameters);
      if (valueToSum != null) {
        sanitized[FacebookAppEvents.paramNameCurrency] = _currency;
      }

      return _facebook.logEvent(
        name: _safeEventName(name),
        parameters: sanitized,
        valueToSum: valueToSum,
      );
    });
  }

  static Future<void> _safeFacebook(Future<void> Function() action) async {
    if (!_isFacebookAvailable) return;

    try {
      await action();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Meta App Events ignored: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static Future<void> _logTikTokEvent(
    String name, {
    Map<String, Object?> parameters = const {},
    double? valueToSum,
  }) {
    return _safeTikTok(() async {
      final sanitized = _sanitizeParameters(parameters);
      if (valueToSum != null) {
        sanitized['currency'] = _currency;
        sanitized['value'] = _roundMoney(valueToSum);
      }

      await _tiktok.invokeMethod<void>('trackEvent', {
        'name': _mapTikTokEventName(name),
        'parameters': sanitized,
      });
    });
  }

  static Future<void> _safeTikTok(Future<void> Function() action) async {
    if (!_isTikTokAvailable) return;

    try {
      await action();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('TikTok Events ignored: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static String _mapTikTokEventName(String value) {
    final safeName = _safeEventName(value);
    switch (safeName) {
      case 'login':
        return 'Login';
      case 'complete_registration':
      case 'sign_up':
        return 'CompleteRegistration';
      case 'booking_created':
      case 'schedule':
        return 'Schedule';
      case 'order_created':
      case 'purchase':
        return 'Purchase';
      case 'payment_proof_uploaded':
      case 'add_payment_info':
        return 'AddPaymentInfo';
      case 'search':
      case 'product_search':
      case 'product_searched':
        return 'Search';
      case 'view_content':
      case 'product_viewed':
        return 'ViewContent';
      case 'add_to_cart':
      case 'product_added_to_cart':
        return 'AddToCart';
      case 'checkout_started':
      case 'initiate_checkout':
        return 'InitiateCheckout';
      case 'contact':
        return 'Contact';
      case 'find_location':
      case 'branch_directions':
        return 'FindLocation';
      default:
        return _toPascalEventName(safeName);
    }
  }

  static String _toPascalEventName(String value) {
    final parts = value.split('_').where((part) => part.isNotEmpty);
    final name = parts
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join();
    if (name.isEmpty) return 'AppEvent';
    if (name.length <= 40) return name;
    return name.substring(0, 40);
  }

  static Map<String, Object> _sanitizeParameters(
    Map<String, Object?> parameters,
  ) {
    final sanitized = <String, Object>{};
    parameters.forEach((key, value) {
      if (value == null) return;
      if (value is num || value is bool) {
        sanitized[key] = value;
        return;
      }

      final text = value.toString().trim();
      if (text.isEmpty) return;
      sanitized[key] = _safeText(text);
    });
    return sanitized;
  }

  static String _safeEventName(String value) {
    final safeName = _safeText(value, fallback: 'app_event');
    if (safeName.length <= 40) return safeName;
    return safeName.substring(0, 40);
  }

  static String _safeText(String value, {String fallback = 'unknown'}) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return fallback;
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D+'), '');
  }
}
