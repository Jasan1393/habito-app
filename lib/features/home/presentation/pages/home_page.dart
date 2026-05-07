import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _HeroSection(
            onQuickBookingTap: () => _openBookings(context),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            title: 'Accesos rápidos',
            subtitle: 'Todo lo importante a un toque.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final itemWidth = (constraints.maxWidth - 14) / 2;
              final itemHeight = compact ? 158.0 : 174.0;
              return GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
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
          const SizedBox(height: 22),
          const TeamHabitoHomeSection(),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Momentos Hábito',
            subtitle: 'Una experiencia cuidada, precisa y elegante.',
          ),
          const SizedBox(height: 14),
          const _EditorialStrip(),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Tu actividad',
            subtitle: 'Resumen rápido de tu cuenta.',
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF161616),
            Color(0xFF201B14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _HeroCopy(),
              ),
              const SizedBox(width: 10),
              const _HeroMonogram(),
            ],
          ),
          const SizedBox(height: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFB68A2F).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.32),
            ),
          ),
          child: const Text(
            'Estilo con intención',
            style: TextStyle(
              color: Color(0xFFE7D39A),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Hábito Barbería',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Reserva y gestiona tu experiencia con una interfaz clara y rápida.',
          style: TextStyle(
            color: Color(0xFFD8D4CD),
            height: 1.34,
            fontSize: 12,
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
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
        ),
      ),
      child: const Icon(
        Icons.content_cut_rounded,
        color: Color(0xFFE7D39A),
        size: 22,
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFFE7D39A),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF3EEE6),
                  fontSize: 12,
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
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
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
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 42 : 46,
                  height: compact ? 42 : 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: compact ? 20 : 24,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37),
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
                  style: TextStyle(
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: compact ? 4 : 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.3,
                    fontSize: compact ? 12 : 13,
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
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = cards[index];
          final darkCard = index == 1;
          return Container(
            width: 210,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: darkCard ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(26),
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
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: darkCard ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      height: 1.4,
                      color: darkCard
                          ? const Color(0xFFD9D3C9)
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ActivityHeader(),
              const SizedBox(height: 18),
              _ActivityRow(
                label: 'Próxima cita',
                value: isLoggedIn ? 'Revisa tu agenda' : 'Inicia sesión',
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _ActivityRow(
                label: 'Puntos disponibles',
                value: pointsValue,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
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
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.insights_rounded,
            color: Color(0xFFE7D39A),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estado de tu cuenta',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Resumen rápido de tus datos principales.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
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
        const SizedBox(width: 12),
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
