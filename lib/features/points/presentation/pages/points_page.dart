import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_error_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../shop/presentation/pages/cart_page.dart';
import '../../../shop/presentation/pages/products_archive_page.dart';
import '../../../shop/provider/shop_provider.dart';
import '../../models/points_history_entry.dart';
import '../../provider/points_provider.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleHistoryScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLoad) return;
    _didLoad = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PointsProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleHistoryScroll)
      ..dispose();
    super.dispose();
  }

  void _handleHistoryScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      context.read<PointsProvider>().loadMoreHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<ShopProvider, int>(
      (provider) => provider.cartCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopHeader(
        searchHint: 'Buscar productos y beneficios',
        cartCount: cartCount,
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProductsArchivePage(),
            ),
          );
        },
        onCartTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          );
        },
      ),
      body: Consumer2<PointsProvider, AuthProvider>(
        builder: (context, points, auth, _) {
          final summary = points.summary;
          final authUser = auth.user;
          final label = summary?.label ?? authUser?.pointsLabel ?? 'Puntos';
          final balanceText = summary?.formattedBalance ??
              _formatPoints(authUser?.pointsBalance ?? 0);
          final totalEarnedText = summary?.formattedTotalEarned ??
              _formatPoints(authUser?.pointsTotalEarned ?? 0);
          final nextGoal = summary?.nextGoal ?? authUser?.pointsNextGoal ?? 0;
          final toNextGoal = summary?.formattedToNextGoal ??
              _formatPoints(
                nextGoal > 0
                    ? (nextGoal - (authUser?.pointsBalance ?? 0))
                        .clamp(0, double.infinity)
                        .toDouble()
                    : 0,
              );
          final moduleEnabled =
              summary?.enabled ?? authUser?.pointsEnabled ?? false;
          final history = points.history;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: points.refresh,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md + AppSpacing.xxs,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(
                    AppSpacing.xl - AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.display,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm - AppSpacing.xxs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.14),
                          borderRadius: AppRadius.full,
                        ),
                        child: Text(
                          moduleEnabled ? 'Saldo actual' : 'Programa de puntos',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                      Text(
                        '$balanceText $label',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.headlineLarge + AppSpacing.xxs,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _buildHeroMessage(
                          moduleEnabled: moduleEnabled,
                          mycredAvailable:
                              summary?.mycredAvailable ?? moduleEnabled,
                          error: points.error,
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                Container(
                  padding: const EdgeInsets.all(
                    AppSpacing.lg + AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.extraLarge,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _MetricRow(
                        label: 'Total acumulado',
                        value: '$totalEarnedText $label',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(height: AppSpacing.xxs / 2),
                      const SizedBox(height: AppSpacing.md),
                      _MetricRow(
                        label: nextGoal > 0 ? 'Meta siguiente' : 'Estado',
                        value: nextGoal > 0 ? '$nextGoal $label' : 'Activo',
                      ),
                      if (nextGoal > 0) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: AppSpacing.xxs / 2),
                        const SizedBox(height: AppSpacing.md),
                        _MetricRow(
                          label: 'Te faltan',
                          value: '$toNextGoal $label',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                Row(
                  children: [
                    const Text(
                      'Historial',
                      style: TextStyle(
                        fontSize: AppTextSize.section,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (points.isLoading)
                      const SizedBox(
                        width: AppIconSize.action,
                        height: AppIconSize.action,
                        child: CircularProgressIndicator(
                          strokeWidth: AppSpacing.xxs,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (points.isLoading && history.isEmpty)
                  const HabitoLoadingShimmer(
                    itemCount: 3,
                    itemHeight: 86,
                  )
                else if (!moduleEnabled)
                  _EmptyStateCard(
                    title: 'Aún no activamos tus puntos',
                    subtitle:
                        'En cuanto el módulo quede activo en el bridge y en myCRED, aquí verás tu saldo y tus movimientos reales.',
                  )
                else if ((points.error ?? '').isNotEmpty && history.isEmpty)
                  _EmptyStateCard(
                    title: 'No pudimos cargar tus puntos',
                    subtitle: points.error!,
                  )
                else if (history.isEmpty)
                  const _EmptyStateCard(
                    title: 'Todavía no tienes movimientos',
                    subtitle:
                        'Tus puntos aparecerán aquí cuando completes citas o pedidos que sumen beneficios.',
                  )
                else
                  ...history.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _HistoryCard(item: item, pointsLabel: label),
                    ),
                  ),
                if (points.isLoadingMoreHistory)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: AppSpacing.xxs,
                      ),
                    ),
                  )
                else if (points.hasMoreHistory)
                  const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  String _buildHeroMessage({
    required bool moduleEnabled,
    required bool mycredAvailable,
    required String? error,
  }) {
    if (!moduleEnabled) {
      return 'Estamos preparando el programa de puntos para que lo veas aquí con saldo e historial reales.';
    }
    if (!mycredAvailable) {
      return 'El módulo de puntos está configurado, pero myCRED aún no está disponible en el servidor.';
    }
    if ((error ?? '').isNotEmpty) {
      return error!;
    }
    return 'Sigue reservando y comprando para acumular beneficios reales dentro de tu cuenta.';
  }

  String _formatPoints(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    if ((rounded - rounded.roundToDouble()).abs() < 0.00001) {
      return rounded.round().toString();
    }
    return rounded
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PointsHistoryEntry item;
  final String pointsLabel;

  const _HistoryCard({
    required this.item,
    required this.pointsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isGain = item.amount >= 0;

    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.panel,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
            height: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
            decoration: BoxDecoration(
              color: isGain ? AppColors.goldSoft : AppColors.surfaceMuted,
              borderRadius: AppRadius.medium,
            ),
            child: Icon(
              isGain ? Icons.stars_rounded : Icons.sync_alt_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.bodySmall,
                      height: 1.35,
                    ),
                  ),
                ],
                if (item.dateDisplay.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                  Text(
                    item.dateDisplay,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.label,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${item.amountFormatted} $pointsLabel',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isGain ? AppColors.goldDeep : AppColors.danger,
              fontWeight: FontWeight.w800,
              fontSize: AppTextSize.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (title.toLowerCase().contains('no pudimos')) {
      return HabitoErrorState(
        title: title,
        message: subtitle,
        compact: true,
      );
    }

    return HabitoEmptyState(
      icon: Icons.stars_rounded,
      title: title,
      message: subtitle,
      compact: true,
    );
  }
}
