import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/main_navigation_scope.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../../../auth/provider/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final isLoggedIn = auth.isLoggedIn;

        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            title: const Text('Perfil'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: AppSpacing.none,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: isLoggedIn
              ? ListView(
                  padding: AppSpacing.screen,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: AppRadius.card,
                      ),
                      padding: const EdgeInsets.all(
                        AppSpacing.lg + AppSpacing.xxs,
                      ),
                      child: Row(
                        children: [
                          _ProfileAvatar(
                            photoUrl: user?.photoUrl ?? '',
                            radius: AppIconSize.successIcon,
                          ),
                          const SizedBox(width: AppSpacing.cartItemGap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName.isNotEmpty == true
                                      ? user!.displayName
                                      : 'Usuario',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTextSize.titleLarge,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  user?.email ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                                if ((user?.phone ?? '').isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    user!.phone,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ProfileOptionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Mis datos personales',
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          AppRoutes.editProfile,
                        );
                      },
                    ),
                    _ProfileOptionCard(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Mis pedidos',
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.orders);
                      },
                    ),
                    _ProfileOptionCard(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notificaciones',
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.notifications);
                      },
                    ),
                    _PushNotificationsOptionCard(auth: auth),
                    _ProfileOptionCard(
                      icon: Icons.system_update_alt_rounded,
                      title: 'Actualizar app',
                      onTap: () async {
                        final foundUpdate =
                            await AppUpdateService.checkNowAndPrompt(context);

                        if (!context.mounted || foundUpdate) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ya tienes la versión más reciente disponible.',
                            ),
                          ),
                        );
                      },
                    ),
                    _ProfileOptionCard(
                      icon: Icons.storefront_outlined,
                      title: 'Sucursales',
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.locations,
                          arguments: {'selectedNavIndex': 4},
                        );
                      },
                    ),
                    _ProfileOptionCard(
                      icon: Icons.calendar_month_outlined,
                      title: 'Mis citas',
                      onTap: () async {
                        final mainNavigation =
                            MainNavigationScope.maybeOf(context);

                        if (mainNavigation != null) {
                          await mainNavigation.selectTab(
                            2,
                            refreshMyAppointments: true,
                          );
                          return;
                        }

                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.main,
                          (route) => false,
                          arguments: {
                            'initialIndex': 2,
                            'myAppointmentsArguments': {
                              'refreshMyBookings': true,
                            },
                          },
                        );
                      },
                    ),
                    _ProfileOptionCard(
                      icon: Icons.stars_outlined,
                      title: 'Mis puntos',
                      onTap: () async {
                        final mainNavigation =
                            MainNavigationScope.maybeOf(context);

                        if (mainNavigation != null) {
                          await mainNavigation.selectTab(3);
                          return;
                        }

                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.main,
                          (route) => false,
                          arguments: {
                            'initialIndex': 3,
                          },
                        );
                      },
                    ),
                    _ProfileOptionCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de privacidad',
                      onTap: () => _openExternalUrl(AppConfig.privacyPolicyUrl),
                    ),
                    _ProfileOptionCard(
                      icon: Icons.delete_outline_rounded,
                      title: 'Eliminar cuenta',
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.deleteAccount);
                      },
                      iconColor: AppColors.dangerSoft,
                    ),
                    _BiometricOptionCard(auth: auth),
                    const _AppVersionCard(),
                    const SizedBox(height: AppIconSize.lg),
                    SizedBox(
                      height: AppIconSize.successBadge,
                      child: ElevatedButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                await context.read<AuthProvider>().logout();

                                if (!context.mounted) return;

                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.main,
                                  (route) => false,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                          ),
                        ),
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: AppIconSize.action,
                                height: AppIconSize.action,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppSpacing.progressStroke,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.logout),
                        label: Text(
                          auth.isLoading
                              ? 'Cerrando sesión...'
                              : 'Cerrar sesión',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: AppSpacing.screen,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: AppRadius.extraLarge,
                      ),
                      padding: AppSpacing.section,
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: AppIconSize.quantityButton,
                            backgroundColor: AppColors.secondary,
                            child: Icon(
                              Icons.person_outline,
                              size: AppIconSize.quantityButton,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            'Tu perfil Hábito',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTextSize.headlineSmall,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                              height: AppSpacing.sm + AppSpacing.xxs),
                          const Text(
                            'Inicia sesión para ver tus citas, tus puntos y acceder más rápido a tus reservas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: AppTextSize.base,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            height: AppIconSize.successBadge,
                            child: ElevatedButton(
                              onPressed: () async {
                                await Navigator.pushNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.medium,
                                ),
                              ),
                              child: const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTextSize.titleMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            height: AppIconSize.successBadge,
                            child: OutlinedButton(
                              onPressed: () async {
                                await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.secondary,
                                side: const BorderSide(
                                  color: AppColors.secondary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.medium,
                                ),
                              ),
                              child: const Text(
                                'Crear cuenta',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTextSize.titleMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ProfileOptionCard(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de privacidad',
                      onTap: () => _openExternalUrl(AppConfig.privacyPolicyUrl),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _AppVersionCard(),
                  ],
                ),
        );
      },
    );
  }
}

class _AppVersionCard extends StatefulWidget {
  const _AppVersionCard();

  @override
  State<_AppVersionCard> createState() => _AppVersionCardState();
}

class _AppVersionCardState extends State<_AppVersionCard> {
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version.trim() ?? '';
        final build = info?.buildNumber.trim() ?? '';
        final versionLabel = version.isEmpty
            ? 'Versión no disponible'
            : build.isEmpty
                ? 'Versión $version'
                : 'Versión $version ($build)';

        return Card(
          color: AppColors.cardDark,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.tile,
          ),
          child: ListTile(
            leading: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.secondary,
            ),
            title: const Text(
              'Versión de la app',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              versionLabel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String photoUrl;
  final double radius;

  const _ProfileAvatar({
    required this.photoUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final image = habitoCachedImageProvider(photoUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.secondary,
      backgroundImage: image,
      child: image == null
          ? Icon(
              Icons.person,
              color: Colors.black,
              size: radius,
            )
          : null,
    );
  }
}

class _ProfileOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;

  const _ProfileOptionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor = AppColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.tile,
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }
}

class _BiometricOptionCard extends StatelessWidget {
  final AuthProvider auth;

  const _BiometricOptionCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final available = auth.biometricAvailable;

    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.tile,
      ),
      child: SwitchListTile(
        value: available && auth.biometricEnabled,
        onChanged: !available
            ? null
            : (value) async {
                await context.read<AuthProvider>().setBiometricEnabled(value);
              },
        secondary: const Icon(
          Icons.fingerprint_rounded,
          color: AppColors.secondary,
        ),
        activeThumbColor: AppColors.secondary,
        activeTrackColor: AppColors.secondary.withValues(alpha: 0.35),
        title: const Text(
          'Huella digital',
          style: TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          available
              ? 'Solicitar al abrir la app'
              : 'Tu dispositivo no tiene biometria disponible',
          style: TextStyle(
            color: available ? Colors.white70 : Colors.white54,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
    );
  }
}

class _PushNotificationsOptionCard extends StatelessWidget {
  final AuthProvider auth;

  const _PushNotificationsOptionCard({required this.auth});

  Future<void> _runDiagnostics(BuildContext context) async {
    final authToken = auth.token?.trim() ?? '';
    if (authToken.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Inicia sesión para verificar notificaciones.'),
          ),
        );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final diagnostics = await PushNotificationService.runDiagnostics(
      authToken: authToken,
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final fcmToken = diagnostics.fcmToken?.trim() ?? '';
        final tokenPreview = fcmToken.isEmpty
            ? 'No disponible'
            : fcmToken.length <= 24
                ? fcmToken
                : '${fcmToken.substring(0, 12)}...${fcmToken.substring(fcmToken.length - 8)}';

        return AlertDialog(
          title: const Text('Diagnóstico push'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permiso: ${diagnostics.authorizationStatus}'),
              Text(
                'APNs: ${diagnostics.apnsTokenAvailable ? 'OK' : 'No disponible'}',
              ),
              Text(
                'FCM: ${diagnostics.fcmTokenAvailable ? 'OK' : 'No disponible'}',
              ),
              Text(
                'Backend: ${diagnostics.backendSaved ? 'Guardado' : 'No guardado'}',
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText('Token: $tokenPreview'),
              if ((diagnostics.error ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Error: ${diagnostics.error}'),
              ],
            ],
          ),
          actions: [
            if (fcmToken.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: fcmToken));
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Token FCM copiado.')),
                    );
                },
                child: const Text('Copiar token'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardDark,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.tile,
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: auth.user?.pushNotificationsEnabled ?? true,
            onChanged: auth.isLoading
                ? null
                : (value) async {
                    final ok = await context
                        .read<AuthProvider>()
                        .setPushNotificationsEnabled(value);

                    if (!context.mounted || ok) return;

                    final error = context.read<AuthProvider>().error;
                    if (error == null || error.trim().isEmpty) return;

                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: AppColors.primaryMuted,
                        ),
                      );
                  },
            secondary: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.secondary,
            ),
            activeThumbColor: AppColors.secondary,
            activeTrackColor: AppColors.secondary.withValues(alpha: 0.35),
            title: const Text(
              'Notificaciones push',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              (auth.user?.pushNotificationsEnabled ?? true)
                  ? 'Recibir avisos de citas, pedidos y novedades.'
                  : 'Notificaciones silenciadas en este perfil.',
              style: const TextStyle(color: Colors.white70),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      auth.isLoading ? null : () => _runDiagnostics(context),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Verificar notificaciones'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
