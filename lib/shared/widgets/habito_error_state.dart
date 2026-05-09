import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icon_size.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_size.dart';

class HabitoErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool compact;

  const HabitoErrorState({
    super.key,
    this.title = 'No pudimos cargar esta información',
    required this.message,
    this.actionLabel = 'Reintentar',
    this.onRetry,
    this.icon = Icons.wifi_tethering_error_rounded,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: compact ? AppRadius.card : AppRadius.display,
        border: Border.all(color: AppColors.dangerSoft),
        boxShadow: compact ? AppShadows.cardSoft : AppShadows.panel,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? AppIconSize.xl : AppIconSize.successBadge,
            height: compact ? AppIconSize.xl : AppIconSize.successBadge,
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: AppRadius.full,
            ),
            child: Icon(
              icon,
              color: AppColors.danger,
              size: compact ? AppIconSize.lg : AppIconSize.successIcon,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: compact
                  ? AppTextSize.titleMedium
                  : AppTextSize.headlineMedium,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.base,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.medium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
