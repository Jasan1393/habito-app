import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                            : const Icon(Icons.delete_forever_outlined),
                        label: Text(
                          auth.isLoading
                              ? 'Eliminando cuenta...'
                              : 'Eliminar mi cuenta',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.formNotice),
                    const Text(
                      'La eliminación se completa desde esta app. No necesitas abrir enlaces, escribir por correo ni contactar soporte.',
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
    final confirmed = await _confirmDeletion();
    if (!confirmed || !mounted) return;

    final response =
        await context.read<AuthProvider>().requestAccountDeletion();

    if (!mounted) return;

    if (response == null) {
      final message = _friendlyDeletionErrorMessage(
        context.read<AuthProvider>().error,
      );

      setState(() {
        _lastMessage = null;
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['message'] ?? 'Tu cuenta fue eliminada correctamente.',
        ),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _friendlyDeletionErrorMessage(String? error) {
    if (error != null && error.trim().isNotEmpty) {
      return error.trim();
    }

    return 'No pudimos eliminar la cuenta en este momento.';
  }

  Future<bool> _confirmDeletion() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text(
              'Eliminar cuenta',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Esta acción eliminará tu cuenta de la app, cerrará tu sesión y cancelará citas futuras asociadas. Esta acción no se puede deshacer.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar cuenta'),
              ),
            ],
          ),
        ) ??
        false;
  }
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
