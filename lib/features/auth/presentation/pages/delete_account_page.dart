import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../provider/auth_provider.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  String? _lastMessage;
  String? _lastWebUrl;

  @override
  Widget build(BuildContext context) {
    const bg = AppColors.primary;
    const card = AppColors.cardDark;
    const gold = AppColors.secondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Eliminar cuenta'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.authTop),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: AppRadius.extraLarge,
                  border: Border.all(color: gold.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.14),
                        borderRadius: AppRadius.full,
                      ),
                      child: const Text(
                        'Cuenta de cliente',
                        style: TextStyle(
                          color: gold,
                          fontSize: AppTextSize.label,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'Esta acción elimina el acceso a tu cuenta en la app Hábito.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.headlineMedium,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Antes de continuar, ten en cuenta lo siguiente:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: AppTextSize.base,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _DeleteAccountPoint(
                      icon: Icons.event_busy_outlined,
                      text:
                          'Las citas futuras asociadas a tu cuenta serán canceladas.',
                    ),
                    const _DeleteAccountPoint(
                      icon: Icons.notifications_off_outlined,
                      text:
                          'Tus sesiones y notificaciones push dejarán de estar activas.',
                    ),
                    const _DeleteAccountPoint(
                      icon: Icons.receipt_long_outlined,
                      text:
                          'Los pedidos o comprobantes ya emitidos se conservarán solo cuando exista una razón operativa o tributaria para hacerlo.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if ((_lastMessage ?? '').isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.formNotice),
                        decoration: BoxDecoration(
                          color: AppColors.successDark,
                          borderRadius: AppRadius.tile,
                          border: Border.all(
                            color: AppColors.successBorderDark,
                          ),
                        ),
                        child: Text(
                          _lastMessage!,
                          style: const TextStyle(
                            color: AppColors.successTextDark,
                            height: 1.45,
                          ),
                        ),
                      ),
                    if ((_lastMessage ?? '').isNotEmpty)
                      const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.deleteActionHeight,
                      child: ElevatedButton.icon(
                        onPressed: auth.isLoading ? null : _requestDeletion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                          ),
                        ),
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: AppIconSize.sm,
                                height: AppIconSize.sm,
                                child: CircularProgressIndicator(
                                  strokeWidth: AppSpacing.progressStroke,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.mail_outline_rounded),
                        label: Text(
                          auth.isLoading
                              ? 'Enviando confirmación...'
                              : 'Enviar enlace de eliminación',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: AppSpacing.deleteActionHeight,
                      child: OutlinedButton.icon(
                        onPressed: _openDeletionWebPage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                          ),
                        ),
                        icon: const Icon(Icons.open_in_browser_outlined),
                        label: const Text(
                          'Abrir página web de eliminación',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.formNotice),
                    const Text(
                      'Te enviaremos un enlace a tu correo para confirmar la eliminación. La cuenta seguirá activa hasta que completes esa confirmación.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: AppTextSize.body,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestDeletion() async {
    final response =
        await context.read<AuthProvider>().requestAccountDeletion();

    if (!mounted) return;

    if (response == null) {
      final message = _friendlyDeletionErrorMessage(
        context.read<AuthProvider>().error,
      );

      setState(() {
        _lastWebUrl = _defaultDeletionWebUrl;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    setState(() {
      _lastMessage = response['message'];
      _lastWebUrl = response['webUrl'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['message'] ??
              'Te enviamos un enlace para confirmar la eliminación.',
        ),
      ),
    );
  }

  Future<void> _openDeletionWebPage() async {
    final url = _lastWebUrl ?? _defaultDeletionWebUrl;
    final uri = Uri.tryParse(url);

    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir la página web de eliminación.'),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir la página web de eliminación.'),
      ),
    );
  }

  String _friendlyDeletionErrorMessage(String? error) {
    final normalizedError = (error ?? '').toLowerCase();
    final isRouteMissing = normalizedError.contains('ninguna ruta') ||
        normalizedError.contains('no route') ||
        normalizedError.contains('not found');

    if (isRouteMissing) {
      return 'No pudimos iniciar la solicitud desde la app. Puedes continuar desde la página web de eliminación.';
    }

    if (error != null && error.trim().isNotEmpty) {
      return error.trim();
    }

    return 'No pudimos iniciar la solicitud de eliminación.';
  }

  String get _defaultDeletionWebUrl => AppConfig.accountDeletionUrl;
}

class _DeleteAccountPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DeleteAccountPoint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppIconSize.optionBadge,
            height: AppIconSize.optionBadge,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: AppRadius.compact,
            ),
            child: Icon(
              icon,
              color: AppColors.secondary,
              size: AppIconSize.compact,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: AppTextSize.base,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
