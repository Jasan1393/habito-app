import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_navigator.dart';
import 'core/routes/app_routes.dart';
import 'core/services/analytics_service.dart';
import 'core/services/app_logger.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/referral_link_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/provider/auth_provider.dart';
import 'features/points/provider/points_provider.dart';
import 'features/shop/provider/shop_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(AnalyticsService.recordFlutterError(details, fatal: true));
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      AnalyticsService.recordError(error, stackTrace, fatal: true),
    );
    return true;
  };

  runApp(const HabitoApp());
  _initializeDeferredStartupServices();
}

void _initializeDeferredStartupServices() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      try {
        await AnalyticsService.initialize();
      } catch (e, stackTrace) {
        AppLogger.error(
          'Error inicializando AnalyticsService',
          error: e,
          stackTrace: stackTrace,
        );
      }

      await Future.wait([
        _initializePushNotifications(),
        _initializeReferralLinks(),
      ]);
    }());
  });
}

Future<void> _initializePushNotifications() async {
  try {
    await PushNotificationService.initialize();
  } catch (e) {
    AppLogger.error('Error inicializando PushNotificationService', error: e);
  }
}

Future<void> _initializeReferralLinks() async {
  try {
    await ReferralLinkService.initialize();
  } catch (e) {
    AppLogger.error('Error inicializando ReferralLinkService', error: e);
  }
}

class HabitoApp extends StatelessWidget {
  const HabitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PointsProvider>(
          create: (_) => PointsProvider(),
          update: (_, auth, points) => (points ?? PointsProvider())
            ..updateSession(token: auth.token, user: auth.user),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
          create: (_) => ShopProvider()..hydrate(),
          update: (_, auth, shop) => (shop ?? (ShopProvider()..hydrate()))
            ..updateAuthState(isLoggedIn: auth.isLoggedIn),
        ),
      ],
      child: MaterialApp(
        title: 'Hábito',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        navigatorObservers: [AnalyticsService.observer],
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.main,
        routes: AppRoutes.routes,
      ),
    );
  }
}
