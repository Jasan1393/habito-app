import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  const AnalyticsService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  static const bool _forceCrashlyticsInDebug =
      bool.fromEnvironment('HABITO_CRASHLYTICS_DEBUG');

  static Future<void> initialize() async {
    await analytics.setAnalyticsCollectionEnabled(true);
    if (kIsWeb) return;

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode || _forceCrashlyticsInDebug,
    );
  }

  static Future<void> identifyUser({
    int? userId,
    bool hasAmeliaLink = false,
    bool hasWooLink = false,
    String contactType = 'unknown',
    bool pointsEnabled = false,
  }) async {
    final analyticsUserId = userId != null && userId > 0 ? '$userId' : null;

    await analytics.setUserId(id: analyticsUserId);
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

  static Future<void> logLogin({String method = 'email'}) {
    return analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp({
    String method = 'email',
    bool hasReferral = false,
  }) {
    return analytics.logSignUp(
      signUpMethod: hasReferral ? '${method}_referral' : method,
    );
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
        'payment_method': _safeText(paymentMethod),
        'value': _roundMoney(total),
        'redeemed_points': redeemedPoints.round(),
        'birthday_points': birthdayPoints.round(),
      },
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
        'fulfillment_method': _safeText(fulfillmentMethod),
        'payment_method': _safeText(paymentMethod),
        'value': _roundMoney(total),
        'redeemed_points': redeemedPoints.round(),
      },
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
  }) {
    return analytics.logEvent(
      name: name,
      parameters: _sanitizeParameters(parameters),
    );
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
}
