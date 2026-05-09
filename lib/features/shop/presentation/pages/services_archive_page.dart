import 'package:flutter/material.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';
import '../../data/services/habito_booking_api.dart';

class ServicesArchivePage extends StatefulWidget {
  const ServicesArchivePage({super.key});

  @override
  State<ServicesArchivePage> createState() => _ServicesArchivePageState();
}

class _ServicesArchivePageState extends State<ServicesArchivePage> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (forceRefresh) {
        await HabitoBookingApi.clearServicesCache();
      }

      final items = await HabitoBookingApi.getServices(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        _services = items
            .whereType<Map>()
            .map((item) => _mapService(Map<String, dynamic>.from(item)))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic> _mapService(Map<String, dynamic> service) {
    final name = (service['name'] ?? service['title'] ?? 'Servicio').toString();
    final duration = _safeInt(service['duration']) ?? 0;
    final extras = service['extras'];
    final extrasCount = extras is List ? extras.length : 0;
    final placeholderImage = _getServicePlaceholderImage(name);
    final imageUrl = HabitoBookingApi.extractServiceImageUrl(service);

    return {
      'id': service['id'],
      'title': name,
      'image': imageUrl,
      'imageUrl': imageUrl,
      'placeholderImage': placeholderImage,
      'price': '\$${_formatPrice(service['price'])}',
      'durationLabel': _formatDurationLabel(duration),
      'extrasCount': extrasCount,
      'raw': service,
    };
  }

  String _getServicePlaceholderImage(String name) {
    return 'assets/images/services/Corte de Cabello.webp';
  }

  String _formatPrice(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '') ?? 0;
    if (parsed == parsed.roundToDouble()) return parsed.toStringAsFixed(0);
    return parsed.toStringAsFixed(2);
  }

  int? _safeInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatDurationLabel(int seconds) {
    if (seconds <= 0) return 'Duración por confirmar';
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  void _openBooking(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingsPage(service: service)),
    );
  }

  Future<void> _goToMainTab(int index) async {
    if (!mounted) return;

    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.main),
        builder: (_) => MainNavigationPage(initialIndex: index),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Servicios'),
      ),
      bottomNavigationBar: HabitoBottomNavigationBar(
        selectedIndex: 1,
        onDestinationSelected: _goToMainTab,
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: () => _loadServices(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _ServicesHeader(
              count: _services.length,
              isLoading: _isLoading,
              hasError: _error != null && _services.isEmpty,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null && _services.isEmpty)
              _ServicesInfoCard(
                message: _error!,
                label: 'Reintentar',
                onTap: () => _loadServices(forceRefresh: true),
              )
            else if (_isLoading)
              ...List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ServiceArchiveSkeleton(),
                ),
              )
            else
              ..._services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ServiceArchiveCard(
                    service: service,
                    onTap: () => _openBooking(service),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  final int count;
  final bool isLoading;
  final bool hasError;

  const _ServicesHeader({
    required this.count,
    required this.isLoading,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = hasError
        ? 'No pudimos cargar'
        : isLoading
            ? 'Cargando'
            : '$count disponibles';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          Container(
            width: AppIconSize.pointsBadge,
            height: AppIconSize.pointsBadge,
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: AppRadius.medium,
            ),
            child: const Icon(
              Icons.content_cut_rounded,
              color: AppColors.goldDeep,
              size: AppIconSize.md,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servicios disponibles',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTextSize.title,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.progress),
                Text(
                  'Elige un servicio para reservar.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: hasError ? AppColors.dangerSoft : AppColors.goldSurface,
              borderRadius: AppRadius.full,
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: hasError ? AppColors.danger : AppColors.goldDeep,
                fontSize: AppTextSize.label,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceArchiveCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onTap;

  const _ServiceArchiveCard({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extrasCount = service['extrasCount'] as int? ?? 0;
    final title = (service['title'] ?? 'Servicio').toString();
    final imageUrl =
        (service['image'] ?? service['imageUrl'] ?? '').toString().trim();
    final placeholderImage = (service['placeholderImage'] ??
            'assets/images/services/Corte de Cabello.webp')
        .toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.medium,
            child: SizedBox(
              width: 96,
              height: 96,
              child: imageUrl.isNotEmpty
                  ? HabitoCachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      semanticLabel: 'Imagen del servicio $title',
                      errorWidget: Image.asset(
                        placeholderImage,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Semantics(
                      label: 'Imagen del servicio $title',
                      image: true,
                      child: Image.asset(
                        placeholderImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primarySoft,
                                AppColors.goldDeep,
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.content_cut, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: AppRadius.full,
                  ),
                  child: const Text(
                    'Servicio',
                    style: TextStyle(
                      color: AppColors.goldDeep,
                      fontSize: AppTextSize.captionSm,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTextSize.title,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniPill(label: (service['price'] ?? '\$0').toString()),
                    _MiniPill(
                      label:
                          (service['durationLabel'] ?? 'Duración').toString(),
                    ),
                    if (extrasCount > 0)
                      _MiniPill(label: '$extrasCount extras disponibles'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    child: const Text(
                      'Reservar servicio',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
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

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.goldMuted,
        borderRadius: AppRadius.full,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.label,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ServicesInfoCard extends StatelessWidget {
  final String message;
  final String label;
  final VoidCallback onTap;

  const _ServicesInfoCard({
    required this.message,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.goldDeep),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
          TextButton(onPressed: onTap, child: Text(label)),
        ],
      ),
    );
  }
}

class _ServiceArchiveSkeleton extends StatelessWidget {
  const _ServiceArchiveSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
