import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/services/referral_link_service.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_error_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';
import '../../../shop/presentation/pages/cart_page.dart';
import '../../../shop/presentation/pages/products_archive_page.dart';
import '../../../shop/provider/shop_provider.dart';
import '../../models/points_history_entry.dart';
import '../../models/referrals_summary.dart';
import '../../provider/points_provider.dart';

class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _referralCodeController = TextEditingController();
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
      _prefillPendingReferralCode();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleHistoryScroll)
      ..dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _handleHistoryScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      context.read<PointsProvider>().loadMoreHistory();
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _referralCodeController.text.trim();
    if (code.isEmpty) return;

    final ok = await context.read<PointsProvider>().applyReferralCode(code);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            ok
                ? 'Codigo de referido vinculado.'
                : context.read<PointsProvider>().error ??
                    'No pudimos vincular el codigo.',
          ),
        ),
      );

    if (ok) {
      await ReferralLinkService.consumePendingReferralCode();
      _referralCodeController.clear();
    }
  }

  Future<void> _prefillPendingReferralCode() async {
    final code = await ReferralLinkService.getPendingReferralCode();
    if (!mounted || code == null || code.isEmpty) return;
    _referralCodeController.text = code;
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
          final moduleEnabled =
              summary?.enabled ?? authUser?.pointsEnabled ?? false;
          final history = points.history;
          final birthdayPromotion = points.birthdayPromotion;
          final showBirthdayBonus = moduleEnabled &&
              (birthdayPromotion?.enabled ?? false) &&
              (birthdayPromotion?.active ?? false) &&
              (birthdayPromotion?.pointsAvailable ?? 0) > 0;

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
                _PointsBalanceHero(
                  balanceText: balanceText,
                  label: label,
                  title: moduleEnabled ? 'Saldo actual' : 'Programa de puntos',
                  message: _buildHeroMessage(
                    moduleEnabled: moduleEnabled,
                    mycredAvailable: summary?.mycredAvailable ?? moduleEnabled,
                    error: points.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                if (showBirthdayBonus) ...[
                  _BirthdayBonusCard(
                    pointsText: birthdayPromotion!.pointsFormatted,
                    expiresAt: birthdayPromotion.expiresAt,
                    verificationNotice:
                        birthdayPromotion.verificationNotice.trim(),
                    onReserve: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookingsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                ],
                if ((points.referrals?.enabled ?? false) &&
                    (points.referrals?.link ?? '').isNotEmpty) ...[
                  _ReferralInviteCard(
                    referrals: points.referrals!,
                    applyController: _referralCodeController,
                    onCopy: () async {
                      await Clipboard.setData(
                        ClipboardData(text: points.referrals!.link),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                            content: Text('Link de referido copiado.'),
                          ),
                        );
                    },
                    onShare: () {
                      Share.share(
                        'Reserva en Hábito con mi código ${points.referrals!.code}. Abre mi invitación aquí: ${points.referrals!.link}',
                      );
                    },
                    onApplyCode: _applyReferralCode,
                  ),
                  const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                ],
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

class _PointsBalanceHero extends StatelessWidget {
  final String balanceText;
  final String label;
  final String title;
  final String message;

  const _PointsBalanceHero({
    required this.balanceText,
    required this.label,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.display,
      child: Stack(
        children: [
          Positioned(
            top: -44,
            right: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -58,
            left: -38,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.darkPanel,
                  AppColors.primarySoft,
                ],
              ),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.18),
              ),
              borderRadius: AppRadius.display,
              boxShadow: AppShadows.strong,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.14),
                        borderRadius: AppRadius.full,
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            size: AppIconSize.sm,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      balanceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.headlineLarge + AppSpacing.sm,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textOnDarkMuted,
                          fontSize: AppTextSize.titleSmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textOnDarkMuted,
                    height: 1.45,
                    fontSize: AppTextSize.bodyStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayBonusCard extends StatelessWidget {
  final String pointsText;
  final String? expiresAt;
  final String verificationNotice;
  final VoidCallback onReserve;

  const _BirthdayBonusCard({
    required this.pointsText,
    required this.expiresAt,
    required this.verificationNotice,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final expiresLabel = _formatExpiry(expiresAt);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary,
            AppColors.goldLight,
          ],
        ),
        borderRadius: AppRadius.display,
        boxShadow: AppShadows.medium,
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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.full,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: const Text(
              'Bono de cumpleaños activo',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '$pointsText puntos para reservar',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: AppTextSize.headlineLarge,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            expiresLabel == null
                ? 'Usa este beneficio únicamente en reservas durante tu cumpleaños.'
                : 'Disponible hasta $expiresLabel. Úsalo únicamente en reservas.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextSize.bodyStrong,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (verificationNotice.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: AppRadius.large,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                verificationNotice,
                style: const TextStyle(
                  color: AppColors.primary,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onReserve,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(AppSpacing.actionHeight),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.large,
              ),
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('Reservar con mi bono'),
          ),
        ],
      ),
    );
  }

  static String? _formatExpiry(String? rawValue) {
    final raw = rawValue?.trim();
    if (raw == null || raw.isEmpty) return null;

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return raw;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }
}

class _ReferralInviteCard extends StatelessWidget {
  final ReferralsSummary referrals;
  final TextEditingController applyController;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onApplyCode;

  const _ReferralInviteCard({
    required this.referrals,
    required this.applyController,
    required this.onCopy,
    required this.onShare,
    required this.onApplyCode,
  });

  @override
  Widget build(BuildContext context) {
    final referralLink =
        referrals.link.isEmpty ? referrals.code : referrals.link;
    final referrerPoints = _formatRewardPoints(referrals.referrerPoints);
    final referredPoints = _formatRewardPoints(referrals.referredPoints);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.darkPanel,
          ],
        ),
        borderRadius: AppRadius.display,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.16)),
        boxShadow: AppShadows.strong,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppIconSize.xxl,
                height: AppIconSize.xxl,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: AppRadius.large,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.secondary,
                  size: AppIconSize.lg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invita y gana',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppTextSize.section,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Comparte tu link personal. Cuando tu referido se registre, reserve y facture su primera cita, ambos ganan.',
                      style: TextStyle(
                        color: AppColors.textOnDarkMuted,
                        height: 1.4,
                        fontSize: AppTextSize.bodyStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (referrerPoints.isNotEmpty || referredPoints.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (referrerPoints.isNotEmpty)
                  Expanded(
                    child: _ReferralRewardPill(
                      title: 'Tú ganas',
                      value: '$referrerPoints pts',
                    ),
                  ),
                if (referrerPoints.isNotEmpty && referredPoints.isNotEmpty)
                  const SizedBox(width: AppSpacing.sm),
                if (referredPoints.isNotEmpty)
                  Expanded(
                    child: _ReferralRewardPill(
                      title: 'Tu referido',
                      value: '$referredPoints pts',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: AppRadius.large,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link para compartir',
                  style: TextStyle(
                    color: AppColors.textOnDarkMuted,
                    fontSize: AppTextSize.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  referralLink,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(
                      AppSpacing.actionHeight,
                    ),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.large,
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(
                      AppSpacing.actionHeight,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.large,
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Compartir'),
                ),
              ),
            ],
          ),
          if (referrals.metrics.total > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${referrals.metrics.rewarded} premiado(s). ${referrals.metrics.total} invitacion(es) en seguimiento.',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (referrals.asReferred == null) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '¿Te invitaron?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: applyController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tengo un código de referido',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.large,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.large,
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.large,
                  borderSide: BorderSide(color: AppColors.secondary),
                ),
                suffixIcon: TextButton(
                  onPressed: onApplyCode,
                  child: const Text(
                    'Aplicar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _statusLabel(referrals.asReferred!.status),
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRewardPoints(double value) {
    if (value <= 0) return '';
    if ((value - value.roundToDouble()).abs() < 0.00001) {
      return value.round().toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'registered':
        return 'Tu referido está vinculado. Falta que abra la app, reserve y facture su primera cita.';
      case 'app_installed':
        return 'Tu referido ya abrió la app. Falta que reserve y facture su primera cita.';
      case 'appointment_created':
        return 'Tu referido ya reservó. El premio se libera cuando la cita sea facturada.';
      case 'rewarded':
        return 'Referido premiado correctamente.';
      case 'reversed':
        return 'El premio fue reversado por anulación de factura.';
      default:
        return 'Referido en seguimiento.';
    }
  }
}

class _ReferralRewardPill extends StatelessWidget {
  final String title;
  final String value;

  const _ReferralRewardPill({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: AppRadius.large,
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textOnDarkMuted,
              fontSize: AppTextSize.label,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
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
