import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_navigator.dart';
import 'core/routes/app_routes.dart';
import 'core/services/app_logger.dart';
import 'core/services/push_notification_service.dart';
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

  try {
    await PushNotificationService.initialize();
  } catch (e) {
    AppLogger.error('Error inicializando PushNotificationService', error: e);
  }

  runApp(const HabitoApp());
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
          update: (_, auth, points) =>
              (points ?? PointsProvider())
                ..updateSession(token: auth.token, user: auth.user),
        ),
        ChangeNotifierProvider<ShopProvider>(
          create: (_) => ShopProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Hábito',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.main,
        routes: AppRoutes.routes,
      ),
    );
  }
}
