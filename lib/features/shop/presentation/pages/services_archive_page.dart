import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
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
        HabitoBookingApi.clearCache();
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
    return 'assets/images/services/Corte de Cabello.png';
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
    if (seconds <= 0) return 'Duracion por confirmar';
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
      body: RefreshIndicator(
        color: const Color(0xFFD4AF37),
        onRefresh: () => _loadServices(forceRefresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _ServicesHero(),
            const SizedBox(height: 22),
            const _ServicesHeader(),
            const SizedBox(height: 14),
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
                  padding: EdgeInsets.only(bottom: 14),
                  child: _ServiceArchiveSkeleton(),
                ),
              )
            else
              ..._services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
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

class _ServicesHero extends StatelessWidget {
  const _ServicesHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Catálogo Hábito',
              style: TextStyle(
                color: Color(0xFFE7D6AC),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Todos los servicios en un solo lugar antes de reservar.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Revisa opciones, duración y valor estimado para elegir la experiencia que mejor va contigo.',
            style: TextStyle(
              color: Color(0xFFD9D4CC),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explora servicios',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Cada tarjeta resume lo más importante antes de pasar al flujo de reserva.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
      ],
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
    final imageUrl =
        (service['image'] ?? service['imageUrl'] ?? '').toString().trim();
    final placeholderImage = (service['placeholderImage'] ??
            'assets/images/services/Corte de Cabello.png')
        .toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 104,
              height: 104,
              child: imageUrl.isNotEmpty
                  ? HabitoCachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: Image.asset(
                        placeholderImage,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      placeholderImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2B2118), Color(0xFF6E5031)],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.content_cut, color: Colors.white),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Servicio',
                    style: TextStyle(
                      color: Color(0xFF8B6A28),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  (service['title'] ?? 'Servicio').toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniPill(label: (service['price'] ?? '\$0').toString()),
                    _MiniPill(
                      label:
                          (service['durationLabel'] ?? 'Duracion').toString(),
                    ),
                    if (extrasCount > 0)
                      _MiniPill(label: '$extrasCount extras disponibles'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
        color: const Color(0xFFF7F3EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9C7732)),
          const SizedBox(width: 12),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
