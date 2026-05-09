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
        searchHint: 'Buscar productos y favoritos',
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
            subtitle: 'Todo lo importante a un toque.',
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
                    subtitle: 'Agenda tu próximo espacio',
                    onTap: () => _openBookings(context),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.shopping_bag_rounded,
                    title: 'Tienda',
                    subtitle: 'Compra productos Hábito',
                    onTap: () => _goToTab(context, 1),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Puntos',
                    subtitle: 'Consulta tus beneficios',
                    onTap: () => _goToTab(context, 3),
                    compact: compact,
                  ),
                  _QuickActionCard(
                    icon: Icons.storefront_rounded,
                    title: 'Sucursales',
                    subtitle: 'Encuentra la más cercana',
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
                    subtitle: 'Edita tu información',
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
            title: 'Momentos Hábito',
            subtitle: 'Una experiencia cuidada, precisa y elegante.',
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          const _EditorialStrip(),
          const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
          const _SectionHeader(
            title: 'Tu actividad',
            subtitle: 'Resumen rápido de tu cuenta.',
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

class _EditorialStrip extends StatelessWidget {
  const _EditorialStrip();

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        'Presencia',
        'Negro, blanco y detalles dorados para una imagen limpia y segura.'
      ),
      (
        'Cuidado',
        'Cada reserva y cada compra deben sentirse fluidas y bien resueltas.'
      ),
      ('Detalle', 'Menos ruido visual y mejor foco en los pasos que importan.'),
    ];

    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.md + AppSpacing.xs),
        itemBuilder: (context, index) {
          final item = cards[index];
          final darkCard = index == 1;
          return Container(
            width: 210,
            padding: const EdgeInsets.all(AppSpacing.xl - AppSpacing.xs),
            decoration: BoxDecoration(
              color: darkCard ? AppColors.primary : AppColors.surface,
              borderRadius: AppRadius.extraLarge,
              border: Border.all(
                color: darkCard
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: AppRadius.full,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                Text(
                  item.$1,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: darkCard ? Colors.white : AppColors.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Expanded(
                  child: Text(
                    item.$2,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: darkCard
                              ? AppColors.textOnDark
                              : AppColors.textSecondary,
                        ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        final isLoggedIn = auth.isLoggedIn;
        final pointsEnabled = user?.pointsEnabled ?? false;
        final pointsLabel = (user?.pointsLabel ?? 'pts').trim();
        final pointsBalance = user?.pointsBalance ?? 0;
        final pointsValue = !isLoggedIn
            ? 'Inicia sesión'
            : !pointsEnabled
                ? 'No activo'
                : '${_formatPoints(pointsBalance)} ${pointsLabel.isEmpty ? 'pts' : pointsLabel}';

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

  String _formatPoints(double value) {
    final normalized = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return normalized.replaceAll(RegExp(r'\.?0+$'), '');
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
                'Estado de tu cuenta',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Resumen rápido de tus datos principales.',
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
