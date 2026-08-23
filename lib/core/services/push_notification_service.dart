import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/shop/data/services/habito_booking_api.dart';
import '../navigation/app_navigator.dart';
import '../routes/app_routes.dart';
import 'app_logger.dart';
import 'notification_inbox_service.dart';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  final notification = message.notification;
  final title =
      notification?.title ?? message.data['title']?.toString() ?? 'Habito';
  final body = notification?.body ??
      message.data['body']?.toString() ??
      message.data['message']?.toString() ??
      '';

  try {
    await NotificationInboxService.record(
      title: title,
      body: body,
      data: message.data,
      messageId: message.messageId,
      receivedAt: message.sentTime,
    );
  } catch (_) {
    // No bloqueamos el manejo del push si el inbox local no se pudo guardar.
  }

  // El sistema operativo muestra la notificacion remota cuando corresponde.
  // No navegamos desde background para evitar abrir pantallas sin contexto.
}

class PushNotificationDiagnostics {
  final String authorizationStatus;
  final bool apnsTokenAvailable;
  final bool fcmTokenAvailable;
  final bool backendSaved;
  final String? fcmToken;
  final String? error;

  const PushNotificationDiagnostics({
    required this.authorizationStatus,
    required this.apnsTokenAvailable,
    required this.fcmTokenAvailable,
    required this.backendSaved,
    this.fcmToken,
    this.error,
  });
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'habito_citas';
  static const String _channelName = 'Mis Citas';
  static const String _channelDesc =
      'Actualizaciones sobre el estado de tus reservas';
  static const String _deviceFileName = 'push_device_id.txt';
  static const String _pushImageFolderName = 'push_images';
  static const String _androidNotificationIcon =
      '@drawable/ic_stat_habito_notification';
  static const int _tokenRegistrationMaxAttempts = 6;
  static const int _deferredTokenRegistrationMaxAttempts = 30;
  static const Duration _tokenRegistrationRetryDelay = Duration(seconds: 2);
  static const Duration _deferredTokenRegistrationDelay = Duration(seconds: 10);

  static String? _currentAuthToken;
  static String? _cachedDeviceId;
  static String? _cachedAppVersion;
  static bool _deferredTokenRegistrationRunning = false;
  static String? _deferredTokenRegistrationAuthToken;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    await _requestNotificationPermission();

    final androidNotifications =
        _localNotif.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidNotifications?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidNotifications?.requestNotificationsPermission();

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings(_androidNotificationIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotif.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _recordInboxItem(message);
      _navigateFromData(message.data);
    });

    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      await _recordInboxItem(initial);
      Future.delayed(
        const Duration(milliseconds: 800),
        () => _navigateFromData(initial.data),
      );
    }

    _fcm.onTokenRefresh.listen((newToken) async {
      final authToken = _currentAuthToken;
      if (authToken == null || authToken.isEmpty) return;

      try {
        await _saveToken(newToken, authToken);
      } catch (e, stackTrace) {
        AppLogger.warning(
          'No se pudo guardar el token FCM refrescado.',
          error: e,
          stackTrace: stackTrace,
        );
        _scheduleDeferredTokenRegistration(authToken);
      }
    });
  }

  static Future<String?> getToken({bool waitForApns = false}) async {
    try {
      if (waitForApns && Platform.isIOS) {
        final apnsToken = await _waitForApnsToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          return null;
        }
      }

      return await _fcm.getToken();
    } catch (e, stackTrace) {
      AppLogger.warning(
        'No se pudo obtener el token FCM.',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<void> registerToken({
    required String authToken,
  }) async {
    _currentAuthToken = authToken;

    final fcmToken = await _getTokenWithRetry();
    if (fcmToken == null || fcmToken.isEmpty) {
      AppLogger.warning('No se obtuvo token FCM para registrar en backend.');
      _scheduleDeferredTokenRegistration(authToken);
      return;
    }

    try {
      await _saveToken(fcmToken, authToken);
    } catch (e, stackTrace) {
      AppLogger.warning(
        'No se pudo guardar el token FCM en el backend.',
        error: e,
        stackTrace: stackTrace,
      );
      _scheduleDeferredTokenRegistration(authToken);
    }
  }

  static Future<PushNotificationDiagnostics> runDiagnostics({
    required String authToken,
  }) async {
    _currentAuthToken = authToken;

    var authorizationStatus = 'unknown';
    var apnsTokenAvailable = !Platform.isIOS;
    var backendSaved = false;
    String? fcmToken;
    String? error;

    try {
      final settings = await _requestNotificationPermission();
      authorizationStatus = settings.authorizationStatus.name;

      if (Platform.isIOS) {
        final apnsToken = await _waitForApnsToken();
        apnsTokenAvailable = apnsToken != null && apnsToken.isNotEmpty;
      }

      if (apnsTokenAvailable) {
        fcmToken = await getToken();
      }

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _saveToken(fcmToken, authToken);
        backendSaved = true;
      }
    } catch (e, stackTrace) {
      error = e.toString().replaceFirst('Exception: ', '');
      AppLogger.warning(
        'Error ejecutando diagnostico de notificaciones push.',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return PushNotificationDiagnostics(
      authorizationStatus: authorizationStatus,
      apnsTokenAvailable: apnsTokenAvailable,
      fcmTokenAvailable: fcmToken != null && fcmToken.isNotEmpty,
      backendSaved: backendSaved,
      fcmToken: fcmToken,
      error: error,
    );
  }

  static void clearSession() {
    _currentAuthToken = null;
  }

  static Future<void> _saveToken(String fcmToken, String authToken) async {
    await HabitoBookingApi.saveFcmToken(
      fcmToken: fcmToken,
      authToken: authToken,
      platform: _getPlatform(),
      deviceId: await _getDeviceId(),
      deviceName: _buildDeviceName(),
      appVersion: await _getAppVersion(),
    );
  }

  static void _scheduleDeferredTokenRegistration(String authToken) {
    if (authToken.isEmpty) {
      return;
    }

    _deferredTokenRegistrationAuthToken = authToken;

    if (_deferredTokenRegistrationRunning) {
      return;
    }

    unawaited(_runDeferredTokenRegistration());
  }

  static Future<void> _runDeferredTokenRegistration() async {
    _deferredTokenRegistrationRunning = true;

    try {
      while (_deferredTokenRegistrationAuthToken != null) {
        final authToken = _deferredTokenRegistrationAuthToken;
        _deferredTokenRegistrationAuthToken = null;

        if (authToken == null || authToken.isEmpty) {
          return;
        }

        for (var attempt = 0;
            attempt < _deferredTokenRegistrationMaxAttempts;
            attempt++) {
          if (_currentAuthToken != authToken) {
            break;
          }

          await Future.delayed(_deferredTokenRegistrationDelay);

          if (_currentAuthToken != authToken) {
            break;
          }

          final fcmToken = await getToken(waitForApns: Platform.isIOS);
          if (fcmToken == null || fcmToken.isEmpty) {
            continue;
          }

          try {
            await _saveToken(fcmToken, authToken);
            AppLogger.info('Token FCM registrado en reintento diferido.');
            return;
          } catch (e, stackTrace) {
            AppLogger.warning(
              'No se pudo guardar el token FCM en reintento diferido.',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      }
    } finally {
      _deferredTokenRegistrationRunning = false;
    }
  }

  static Future<NotificationSettings> _requestNotificationPermission() {
    return _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  static Future<String?> _getTokenWithRetry() async {
    await _requestNotificationPermission();

    for (var attempt = 0; attempt < _tokenRegistrationMaxAttempts; attempt++) {
      final token = await getToken(waitForApns: Platform.isIOS);
      if (token != null && token.isNotEmpty) {
        return token;
      }

      if (attempt < _tokenRegistrationMaxAttempts - 1) {
        await Future.delayed(_tokenRegistrationRetryDelay);
      }
    }

    return null;
  }

  static Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < _tokenRegistrationMaxAttempts; attempt++) {
      final token = await _fcm.getAPNSToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }

      if (attempt < _tokenRegistrationMaxAttempts - 1) {
        await Future.delayed(_tokenRegistrationRetryDelay);
      }
    }

    AppLogger.warning(
      'iOS no entrego APNs token; FCM no se puede registrar todavia.',
    );
    return null;
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'Habito Barberia';
    final body = notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        'Tienes una actualizacion importante.';

    await _recordInboxItem(message, titleOverride: title, bodyOverride: body);

    final notificationDetails = await _buildForegroundNotificationDetails(
      message: message,
      title: title,
      body: body,
    );

    await _localNotif.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: _encodePayload(message.data),
    );
  }

  static Future<NotificationDetails> _buildForegroundNotificationDetails({
    required RemoteMessage message,
    required String title,
    required String body,
  }) async {
    final imageUrl = _extractPushImageUrl(message);
    final imagePath =
        imageUrl.isNotEmpty ? await _cachePushImage(imageUrl) : null;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: _androidNotificationIcon,
      styleInformation: imagePath != null
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(imagePath),
              contentTitle: title,
              summaryText: body,
              hideExpandedLargeIcon: true,
            )
          : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: imagePath != null
          ? DarwinNotificationDetails(
              attachments: [
                DarwinNotificationAttachment(
                  imagePath,
                  identifier: 'habito-push-image',
                ),
              ],
            )
          : const DarwinNotificationDetails(),
    );
  }

  static void _onLocalNotifTap(NotificationResponse response) {
    _navigateFromData(_decodePayload(response.payload));
  }

  static Future<void> _recordInboxItem(
    RemoteMessage message, {
    String? titleOverride,
    String? bodyOverride,
  }) async {
    final notification = message.notification;
    await NotificationInboxService.record(
      title: titleOverride ??
          notification?.title ??
          message.data['title']?.toString() ??
          'Habito',
      body: bodyOverride ??
          notification?.body ??
          message.data['body']?.toString() ??
          message.data['message']?.toString() ??
          '',
      data: message.data,
      messageId: message.messageId,
      receivedAt: message.sentTime,
    );
  }

  static void _navigateFromData(Map<String, dynamic> data) {
    final normalized = _normalizePushData(data);
    final type = (normalized['type'] ?? '').toString().toLowerCase();
    final targetScreen = _normalizeTargetScreen(
      normalized['target_screen'] ??
          normalized['targetScreen'] ??
          normalized['screen'] ??
          normalized['target'],
    );
    final appointmentId = _parseInt(normalized['appointmentId']);
    final bookingId = _parseInt(normalized['bookingId']);
    final orderId = _parseInt(
      normalized['orderId'] ?? normalized['order_id'] ?? normalized['order'],
    );
    final status = (normalized['status'] ?? '').toString();

    final isAppointmentNotification = type.contains('booking') ||
        type.contains('appointment') ||
        type.contains('cita') ||
        appointmentId != null ||
        bookingId != null;
    final isOrderNotification =
        type.contains('order') || type.contains('pedido') || orderId != null;

    if (isAppointmentNotification) {
      _safeNavigateToPushAppointment({
        'appointmentId': appointmentId,
        'bookingId': bookingId,
        'status': status,
        'openFromPush': true,
      });
      return;
    }

    if (isOrderNotification) {
      _safeNavigateToOrders({
        'orderId': orderId,
        'status': status,
        'openFromPush': true,
        'selectedNavIndex': 1,
      });
      return;
    }

    final actionUrl = _firstNotificationActionUrl(normalized);
    if (actionUrl.isNotEmpty &&
        (_isSriDocumentData(normalized, type) ||
            targetScreen == 'notifications')) {
      _safeLaunchExternalUrl(actionUrl);
      return;
    }

    switch (targetScreen) {
      case 'shop':
        _safeNavigateToMainTab(1);
        return;
      case 'points':
        _safeNavigateToMainTab(3);
        return;
      case 'profile':
        _safeNavigateToMainTab(4);
        return;
      case 'home':
        _safeNavigateToMainTab(0);
        return;
      case 'bookings':
        _safeNavigateToNamedRoute(AppRoutes.bookings);
        return;
      case 'locations':
        _safeNavigateToNamedRoute(
          AppRoutes.locations,
          arguments: {'selectedNavIndex': 0},
        );
        return;
      case 'notifications':
        _safeNavigateToNamedRoute(AppRoutes.notifications);
        return;
      case 'orders':
        _safeNavigateToOrders({
          'orderId': orderId,
          'status': status,
          'openFromPush': true,
          'selectedNavIndex': 1,
        });
        return;
    }
  }

  static Map<String, dynamic> _normalizePushData(Map<String, dynamic> data) {
    int? appointmentId = _parseInt(
      data['appointmentId'] ??
          data['appointment_id'] ??
          data['appointment'] ??
          data['id'],
    );
    int? bookingId = _parseInt(
      data['bookingId'] ?? data['booking_id'] ?? data['booking'],
    );
    int? orderId = _parseInt(
      data['orderId'] ?? data['order_id'] ?? data['order'],
    );
    var payloadData = <String, dynamic>{};

    final rawPayload = data['payload'];
    if (rawPayload is String && rawPayload.trim().isNotEmpty) {
      final decoded = _decodePayload(rawPayload);
      payloadData = decoded;
      appointmentId ??= _parseInt(
        decoded['appointmentId'] ??
            decoded['appointment_id'] ??
            decoded['appointment'] ??
            decoded['id'],
      );
      bookingId ??= _parseInt(
        decoded['bookingId'] ?? decoded['booking_id'] ?? decoded['booking'],
      );
      orderId ??= _parseInt(
        decoded['orderId'] ?? decoded['order_id'] ?? decoded['order'],
      );
    } else if (rawPayload is Map) {
      final payloadMap = rawPayload.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      payloadData = payloadMap;
      appointmentId ??= _parseInt(
        payloadMap['appointmentId'] ??
            payloadMap['appointment_id'] ??
            payloadMap['appointment'] ??
            payloadMap['id'],
      );
      bookingId ??= _parseInt(
        payloadMap['bookingId'] ??
            payloadMap['booking_id'] ??
            payloadMap['booking'],
      );
      orderId ??= _parseInt(
        payloadMap['orderId'] ?? payloadMap['order_id'] ?? payloadMap['order'],
      );
    }

    return {
      ...payloadData,
      ...data,
      'appointmentId': appointmentId,
      'bookingId': bookingId,
      'orderId': orderId,
    };
  }

  static String _firstNotificationActionUrl(Map<String, dynamic> data) {
    const keys = [
      'ride_url',
      'download_url',
      'document_url',
      'url',
      'link',
      'external_url',
    ];

    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      final uri = Uri.tryParse(value);
      if (uri != null && _isHttpUri(uri)) return value;
    }

    return '';
  }

  static bool _isSriDocumentData(Map<String, dynamic> data, String type) {
    return type.contains('sri') ||
        type.contains('electronic_document') ||
        data.containsKey('sri_number') ||
        data.containsKey('sriNumber') ||
        data.containsKey('access_key') ||
        data.containsKey('document_type');
  }

  static bool _isHttpUri(Uri uri) {
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.trim().isNotEmpty;
  }

  static void _safeLaunchExternalUrl(String url) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_launchExternalUrl(url));
    });
  }

  static Future<void> _launchExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_isHttpUri(uri)) return;

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        AppLogger.warning('No se pudo abrir el enlace del push: $url');
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'No se pudo abrir el enlace externo del push.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _safeNavigateToPushAppointment(Map<String, dynamic> arguments) {
    void doNavigate() {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        Future.delayed(
          const Duration(milliseconds: 400),
          () => _safeNavigateToPushAppointment(arguments),
        );
        return;
      }

      navigator.pushNamed(
        AppRoutes.pushAppointment,
        arguments: arguments,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static void _safeNavigateToOrders(Map<String, dynamic> arguments) {
    void doNavigate() {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        Future.delayed(
          const Duration(milliseconds: 400),
          () => _safeNavigateToOrders(arguments),
        );
        return;
      }

      navigator.pushNamed(
        AppRoutes.orders,
        arguments: arguments,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static void _safeNavigateToMainTab(int index) {
    requestMainTabNavigation(index);

    void doNavigate() {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        Future.delayed(
          const Duration(milliseconds: 400),
          () => _safeNavigateToMainTab(index),
        );
        return;
      }

      if (navigator.canPop()) {
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.main,
          (route) => false,
          arguments: {'initialIndex': index},
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static void _safeNavigateToNamedRoute(
    String routeName, {
    Map<String, dynamic>? arguments,
  }) {
    void doNavigate() {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        Future.delayed(
          const Duration(milliseconds: 400),
          () => _safeNavigateToNamedRoute(
            routeName,
            arguments: arguments,
          ),
        );
        return;
      }

      navigator.pushNamed(routeName, arguments: arguments);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doNavigate();
    });
  }

  static String _encodePayload(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return '{}';
    }
  }

  static Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Ignorar payload invalido.
    }

    return <String, dynamic>{};
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String _extractPushImageUrl(RemoteMessage message) {
    final dataUrl = [
      message.data['image_url'],
      message.data['imageUrl'],
      message.data['image'],
    ].map((value) => value?.toString().trim() ?? '').firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );

    if (dataUrl.isNotEmpty) return dataUrl;

    final androidUrl = message.notification?.android?.imageUrl?.trim() ?? '';
    if (androidUrl.isNotEmpty) return androidUrl;

    final appleUrl = message.notification?.apple?.imageUrl?.trim() ?? '';
    if (appleUrl.isNotEmpty) return appleUrl;

    return '';
  }

  static Future<String?> _cachePushImage(String imageUrl) async {
    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null || !uri.hasScheme) return null;

      final directory = await getTemporaryDirectory();
      final imageDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}$_pushImageFolderName',
      );
      if (!await imageDirectory.exists()) {
        await imageDirectory.create(recursive: true);
      }

      final extension = _guessImageExtension(imageUrl);
      final file = File(
        '${imageDirectory.path}${Platform.pathSeparator}${imageUrl.hashCode.abs()}$extension',
      );

      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }

      final response = await http.get(uri, headers: const {
        'Accept': 'image/*'
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;

      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static String _guessImageExtension(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final path = uri?.path.toLowerCase() ?? imageUrl.toLowerCase();

    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.webp')) return '.webp';
    if (path.endsWith('.gif')) return '.gif';
    return '.jpg';
  }

  static String _normalizeTargetScreen(dynamic value) {
    final normalized =
        value?.toString().trim().toLowerCase().replaceAll('-', '_');

    switch (normalized) {
      case 'store':
      case 'tienda':
        return 'shop';
      case 'booking':
      case 'reservas':
      case 'citas':
        return 'bookings';
      case 'location':
      case 'branch':
      case 'sucursales':
        return 'locations';
      case 'notification':
        return 'notifications';
      case 'pedido':
        return 'orders';
      case 'inicio':
        return 'home';
      case 'perfil':
        return 'profile';
      case 'puntos':
        return 'points';
      default:
        return normalized ?? '';
    }
  }

  static String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  static Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$_deviceFileName');

      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved.isNotEmpty) {
          _cachedDeviceId = saved;
          return saved;
        }
      }

      final generated = _generateDeviceId();
      await file.writeAsString(generated, flush: true);
      _cachedDeviceId = generated;
      return generated;
    } catch (_) {
      _cachedDeviceId ??= _generateDeviceId();
      return _cachedDeviceId!;
    }
  }

  static String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final encoded =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${_getPlatform()}_habito_$encoded';
  }

  static Future<String> _getAppVersion() async {
    if (_cachedAppVersion != null && _cachedAppVersion!.isNotEmpty) {
      return _cachedAppVersion!;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.trim();
      final version = build.isEmpty ? info.version : '${info.version}+$build';
      _cachedAppVersion = version;
      return version;
    } catch (_) {
      return 'unknown';
    }
  }

  static String _buildDeviceName() {
    if (Platform.isAndroid) return 'Android ${Platform.operatingSystemVersion}';
    if (Platform.isIOS) return 'iOS ${Platform.operatingSystemVersion}';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}
