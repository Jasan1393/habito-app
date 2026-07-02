import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../points/models/points_summary.dart';
import '../../../points/provider/points_provider.dart';
import '../../../shop/presentation/pages/cart_page.dart';
import '../../../shop/presentation/pages/products_archive_page.dart';
import '../../../shop/provider/shop_provider.dart';
import '../../../team/presentation/widgets/team_habito_home_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _goToTab(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationPage(initialIndex: index),
      ),
    );
  }

  void _openBookings(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Inicia sesión para reservar tu cita.'),
          ),
        );
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }

    Navigator.pushNamed(context, AppRoutes.bookings);
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<ShopProvider, int>(
      (provider) => provider.cartCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopHeader(
        searchHint: 'Buscar productos en tienda',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl + AppSpacing.xs,
        ),
        children: [
          _HeroSection(
            onQuickBookingTap: () => _openBookings(context),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
          const _SectionHeader(
            title: 'Accesos rápidos',
            subtitle: 'Reserva, compra y revisa tus beneficios.',
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              const gridGap = AppSpacing.md + AppSpacing.xs;
              final compact = constraints.maxWidth < 360;
              final itemWidth = (constraints.maxWidth - gridGap) / 2;
              final itemHeight = compact ? 158.0 : 174.0;
              return GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: gridGap,
                crossAxisSpacing: gridGap,
                childAspectRatio: itemWidth / itemHeight,
                children: [
                  _QuickActionCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Reservar cita',
                    subtitle: 'Elige servicio, barbero y horario',
                    onTap: () => _openBookings(context),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.shopping_bag_rounded,
                    title: 'Tienda',
                    subtitle: 'Productos para tu cuidado diario',
                    onTap: () => _goToTab(context, 1),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Puntos',
                    subtitle: 'Saldo, referidos y cumpleaños',
                    onTap: () => _goToTab(context, 3),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.storefront_rounded,
                    title: 'Sucursales',
                    subtitle: 'Ubicación y contacto directo',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.locations,
                      arguments: {'selectedNavIndex': 0},
                    ),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Perfil',
                    subtitle: 'Datos, pedidos y notificaciones',
                    onTap: () => _goToTab(context, 4),
                    compact: compact,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
          const TeamHabitoHomeSection(),
          const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
          const _SectionHeader(
            title: 'Beneficios Hábito',
            subtitle: 'Gana, comparte y celebra dentro de tu cuenta.',
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          _BenefitsStrip(
            onBenefitsTap: () => _goToTab(context, 3),
          ),
          const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
          const _SectionHeader(
            title: 'Tu actividad',
            subtitle: 'Citas, puntos y perfil en un solo lugar.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _ActivityCard(),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onQuickBookingTap;

  const _HeroSection({
    required this.onQuickBookingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.extraLarge,
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cardDark,
            AppColors.primarySoft,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.strong,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSpacing.xs,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: AppRadius.full,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: _HeroCopy(),
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              const _HeroMonogram(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HeroPill(
            icon: Icons.calendar_month_rounded,
            onTap: onQuickBookingTap,
            label: 'Reserva rápida',
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xxs,
            vertical: AppSpacing.xs + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: AppColors.goldDeep.withValues(alpha: 0.16),
            borderRadius: AppRadius.full,
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.32),
            ),
          ),
          child: Text(
            'Estilo con intención',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.goldSoft,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
        Text(
          'Hábito Barbería',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                height: 1.08,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
        Text(
          'Reserva y gestiona tu experiencia con una interfaz clara y rápida.',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textOnDark,
                height: 1.34,
              ),
        ),
      ],
    );
  }
}

class _HeroMonogram extends StatelessWidget {
  const _HeroMonogram();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: AppRadius.medium,
        color: AppColors.secondary.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: const Icon(
        Icons.content_cut_rounded,
        color: AppColors.goldSoft,
        size: AppIconSize.md,
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: AppRadius.large,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppIconSize.xs + AppSpacing.xxs,
                color: AppColors.goldSoft,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.extraLarge,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.extraLarge,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.light,
          ),
          child: Padding(
            padding: EdgeInsets.all(
              compact
                  ? AppSpacing.md + AppSpacing.xs
                  : AppSpacing.lg + AppSpacing.xxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 42 : 46,
                  height: compact ? 42 : 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.medium,
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: compact
                              ? AppIconSize.sm + AppSpacing.xxs
                              : AppIconSize.md + AppSpacing.xxs,
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          width: AppSpacing.sm - AppSpacing.xxs,
                          height: AppSpacing.sm - AppSpacing.xxs,
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(
                  height:
                      compact ? AppSpacing.xs : AppSpacing.xs + AppSpacing.xxs,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitsStrip extends StatelessWidget {
  final VoidCallback onBenefitsTap;

  const _BenefitsStrip({
    required this.onBenefitsTap,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      const _BenefitCardData(
        icon: Icons.workspace_premium_rounded,
        eyebrow: 'Puntos',
        title: 'Reserva y acumula',
        description:
            'Cada cita o compra válida suma puntos para usar en próximos beneficios.',
        actionLabel: 'Ver saldo',
      ),
      const _BenefitCardData(
        icon: Icons.group_add_rounded,
        eyebrow: 'Referidos',
        title: 'Invita y gana',
        description:
            'Comparte tu enlace personal y recibe puntos cuando tu referido complete su primera cita.',
        actionLabel: 'Compartir',
      ),
      const _BenefitCardData(
        icon: Icons.cake_rounded,
        eyebrow: 'Cumpleaños',
        title: 'Bono especial',
        description:
            'En tu mes de cumpleaños puedes recibir un bono para reservar tu próxima experiencia.',
        actionLabel: 'Revisar bono',
      ),
    ];

    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.md + AppSpacing.xs),
        itemBuilder: (context, index) {
          final item = cards[index];
          final darkCard = index == 1;
          return _BenefitCard(
            data: item,
            darkCard: darkCard,
            onTap: onBenefitsTap,
          );
        },
      ),
    );
  }
}

class _BenefitCardData {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;

  const _BenefitCardData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
  });
}

class _BenefitCard extends StatelessWidget {
  final _BenefitCardData data;
  final bool darkCard;
  final VoidCallback onTap;

  const _BenefitCard({
    required this.data,
    required this.darkCard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = darkCard ? Colors.white : AppColors.textPrimary;
    final muted = darkCard ? AppColors.textOnDark : AppColors.textSecondary;
    final chipBackground = darkCard
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.secondary.withValues(alpha: 0.18);

    return SizedBox(
      width: 226,
      child: Material(
        color: darkCard ? AppColors.primary : AppColors.surface,
        borderRadius: AppRadius.extraLarge,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.extraLarge,
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.extraLarge,
              border: Border.all(
                color: darkCard
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.border,
              ),
              boxShadow: darkCard ? AppShadows.medium : AppShadows.light,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: chipBackground,
                        borderRadius: AppRadius.large,
                      ),
                      child: Icon(
                        data.icon,
                        size: AppIconSize.md,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        data.eyebrow,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: darkCard
                                  ? AppColors.goldLight
                                  : AppColors.goldDeep,
                              fontWeight: FontWeight.w800,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Text(
                    data.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          color: muted,
                        ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      data.actionLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: darkCard
                                ? AppColors.goldLight
                                : AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: AppIconSize.sm,
                      color: darkCard
                          ? AppColors.goldLight
                          : AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard();

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  bool _requestedPointsLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPointsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPointsIfNeeded();
  }

  void _loadPointsIfNeeded() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _requestedPointsLoad = false;
      return;
    }

    if (_requestedPointsLoad) return;
    _requestedPointsLoad = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = context.read<PointsProvider>();
      if (!points.isLoading) {
        points.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, PointsProvider>(
      builder: (context, auth, points, _) {
        final user = auth.user;
        final isLoggedIn = auth.isLoggedIn;
        final pointsValue = _pointsValue(
          isLoggedIn: isLoggedIn,
          points: points,
          fallback: user == null
              ? null
              : PointsSummary(
                  enabled: user.pointsEnabled,
                  mycredAvailable: user.pointsEnabled,
                  balance: user.pointsBalance,
                  totalEarned: user.pointsTotalEarned,
                  pointType: user.pointsType,
                  label: user.pointsLabel,
                  nextGoal: user.pointsNextGoal ?? 0,
                  toNextGoal: 0,
                  redeemEnabled: user.pointsRedeemEnabled,
                  redeemProductsEnabled: user.pointsRedeemProductsEnabled,
                  redeemBookingsEnabled: user.pointsRedeemBookingsEnabled,
                  redeemPointsPerUsd: user.pointsRedeemPointsPerUsd,
                  redeemMinPoints: user.pointsRedeemMinPoints,
                  redeemMaxPercent: user.pointsRedeemMaxPercent,
                  bookingPointsEnabled: user.pointsEnabled,
                  orderPointsEnabled: user.pointsEnabled,
                ),
        );

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xxs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.light,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ActivityHeader(),
              const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
              _ActivityRow(
                label: 'Próxima cita',
                value: isLoggedIn ? 'Revisa tu agenda' : 'Inicia sesión',
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.lg),
              _ActivityRow(
                label: 'Puntos disponibles',
                value: pointsValue,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.lg),
              _ActivityRow(
                label: 'Estado de perfil',
                value: isLoggedIn ? 'Activo' : 'Invitado',
              ),
            ],
          ),
        );
      },
    );
  }

  String _pointsValue({
    required bool isLoggedIn,
    required PointsProvider points,
    required PointsSummary? fallback,
  }) {
    if (!isLoggedIn) return 'Inicia sesión';

    final summary = points.summary ?? fallback;
    if (summary == null && points.isLoading) return 'Actualizando';
    if (summary == null) return 'Sin datos';
    if (!summary.enabled || !summary.mycredAvailable) return 'No activo';

    final label = summary.label.trim().isEmpty ? 'Puntos' : summary.label;
    return '${summary.formattedBalance} $label';
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: AppRadius.medium,
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: AppColors.goldSoft,
            size: AppIconSize.sm + AppSpacing.xxs,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu cuenta Hábito',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Consulta tu agenda, beneficios y estado de sesión.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String label;
  final String value;

  const _ActivityRow({
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
