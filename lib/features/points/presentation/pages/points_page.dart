import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_top_header.dart';
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
  bool _didLoad = false;

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
  Widget build(BuildContext context) {
    final cartCount = context.watch<ShopProvider>().cartCount;

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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          moduleEnabled ? 'Saldo actual' : 'Programa de puntos',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$balanceText $label',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _MetricRow(
                        label: 'Total acumulado',
                        value: '$totalEarnedText $label',
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      _MetricRow(
                        label: nextGoal > 0 ? 'Meta siguiente' : 'Estado',
                        value: nextGoal > 0 ? '$nextGoal $label' : 'Activo',
                      ),
                      if (nextGoal > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _MetricRow(
                          label: 'Te faltan',
                          value: '$toNextGoal $label',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Text(
                      'Historial',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (points.isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!moduleEnabled)
                  _EmptyStateCard(
                    title: 'Aun no activamos tus puntos',
                    subtitle:
                        'En cuanto el modulo quede activo en el bridge y en myCRED, aqui veras tu saldo y tus movimientos reales.',
                  )
                else if ((points.error ?? '').isNotEmpty && history.isEmpty)
                  _EmptyStateCard(
                    title: 'No pudimos cargar tus puntos',
                    subtitle: points.error!,
                  )
                else if (history.isEmpty)
                  const _EmptyStateCard(
                    title: 'Todavia no tienes movimientos',
                    subtitle:
                        'Tus puntos apareceran aqui cuando completes citas o pedidos que sumen beneficios.',
                  )
                else
                  ...history.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryCard(item: item, pointsLabel: label),
                    ),
                  ),
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
      return 'Estamos preparando el programa de puntos para que lo veas aqui con saldo e historial reales.';
    }
    if (!mycredAvailable) {
      return 'El modulo de puntos esta configurado, pero myCRED aun no esta disponible en el servidor.';
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
        const SizedBox(width: 12),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isGain ? AppColors.goldSoft : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isGain ? Icons.stars_rounded : Icons.sync_alt_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
                if (item.dateDisplay.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.dateDisplay,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${item.amountFormatted} $pointsLabel',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isGain ? const Color(0xFF9C7732) : const Color(0xFFA33A3A),
              fontWeight: FontWeight.w800,
              fontSize: 15,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
