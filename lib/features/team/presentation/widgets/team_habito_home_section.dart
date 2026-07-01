import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/habito_portrait_image.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import '../pages/team_habito_page.dart';

class TeamHabitoHomeSection extends StatefulWidget {
  const TeamHabitoHomeSection({super.key});

  @override
  State<TeamHabitoHomeSection> createState() => _TeamHabitoHomeSectionState();
}

class _TeamHabitoHomeSectionState extends State<TeamHabitoHomeSection> {
  List<Map<String, dynamic>> _barbers = [];
  bool _isLoading = true;
  bool _didRetryLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadBarbers();
    });
  }

  int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  List<int> _extractLocationIds(dynamic raw) {
    if (raw == null) return [];

    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              return _safeInt(
                item['id'] ?? item['locationId'] ?? item['location_id'],
              );
            }
            return _safeInt(item);
          })
          .whereType<int>()
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((e) => _safeInt(e.trim()))
          .whereType<int>()
          .toList();
    }

    return [];
  }

  int? _extractPrimaryLocationId(Map<String, dynamic> employee) {
    final directLocationId =
        _safeInt(employee['locationId']) ?? _safeInt(employee['location_id']);

    if (directLocationId != null) {
      return directLocationId;
    }

    final locationIds = _extractLocationIds(employee['locationIds']);
    if (locationIds.isNotEmpty) {
      return locationIds.first;
    }

    final locations = employee['locations'];
    final locationsIds = _extractLocationIds(locations);
    if (locationsIds.isNotEmpty) {
      return locationsIds.first;
    }

    return null;
  }

  Future<void> _loadBarbers() async {
    final cachedEmployees = await HabitoBookingApi.getCachedEmployees();

    if (cachedEmployees.isNotEmpty && mounted) {
      setState(() {
        _barbers = _mapEmployees(cachedEmployees, limit: 6);
        _isLoading = false;
      });
    }

    try {
      final employees = await HabitoBookingApi.getEmployees(
        forceRefresh: cachedEmployees.isNotEmpty,
      );

      final mapped = _mapEmployees(employees, limit: 6);

      if (!mounted) return;

      setState(() {
        _barbers = mapped;
        _isLoading = false;
      });
    } catch (e) {
      if (cachedEmployees.isNotEmpty || _barbers.isNotEmpty) {
        return;
      }

      if (!_didRetryLoading) {
        _didRetryLoading = true;
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        await _loadBarbers();
        return;
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando Team Hábito: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _mapEmployees(
    List<dynamic> employees, {
    int? limit,
  }) {
    final iterable = limit == null ? employees : employees.take(limit);

    return iterable.map<Map<String, dynamic>>((employee) {
      final employeeMap = Map<String, dynamic>.from(employee);

      final firstName =
          (employeeMap['firstName'] ?? employeeMap['first_name'] ?? '')
              .toString()
              .trim();

      final lastName =
          (employeeMap['lastName'] ?? employeeMap['last_name'] ?? '')
              .toString()
              .trim();

      final fullNameFromParts = '$firstName $lastName'.trim();

      final fullName = fullNameFromParts.isNotEmpty
          ? fullNameFromParts
          : (employeeMap['fullName'] ??
                  employeeMap['name'] ??
                  employeeMap['displayName'] ??
                  'Barbero Hábito')
              .toString()
              .trim();

      final locationIds = _extractLocationIds(
        employeeMap['locationIds'] ?? employeeMap['locations'],
      );

      final locationId = _extractPrimaryLocationId(employeeMap);

      return {
        'id': _safeInt(employeeMap['id']) ?? 0,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName.isEmpty ? 'Barbero Hábito' : fullName,
        'pictureFullPath': employeeMap['pictureFullPath'] ??
            employeeMap['picture'] ??
            employeeMap['image'] ??
            employeeMap['avatar'] ??
            employeeMap['pictureThumbPath'],
        'description': employeeMap['description'] ?? employeeMap['bio'] ?? '',
        'locationId': locationId,
        'locationIds': locationIds,
        'locations': employeeMap['locations'] ?? [],
        'raw': employeeMap,
      };
    }).toList();
  }

  void _openBarberProfile(Map<String, dynamic> barber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (_) => _BarberProfileModal(barber: barber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TeamSectionHeader(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeamHabitoPage()),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 256,
          child: _isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, __) => Container(
                    width: 184,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.extraLarge,
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _barbers.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final barber = _barbers[index];
                    return _MiniBarberCard(
                      barber: barber,
                      onTap: () => _openBarberProfile(barber),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TeamSectionHeader extends StatelessWidget {
  final VoidCallback onTap;

  const _TeamSectionHeader({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Team Hábito',
            style: TextStyle(
              fontSize: AppTextSize.headlineSmall,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.full,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs + AppSpacing.xxs,
            ),
            child: Row(
              children: [
                Text(
                  'Ver todos',
                  style: TextStyle(
                    fontSize: AppTextSize.base,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldDeep,
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.goldDeep,
                  size: AppIconSize.action,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBarberCard extends StatelessWidget {
  final Map<String, dynamic> barber;
  final VoidCallback onTap;

  const _MiniBarberCard({
    required this.barber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = barber['pictureFullPath']?.toString() ?? '';
    final fullName = barber['fullName']?.toString() ?? 'Barbero Hábito';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.extraLarge,
        onTap: onTap,
        child: Ink(
          width: 184,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.extraLarge,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.cardSoft,
          ),
          child: Padding(
            padding: AppSpacing.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.large,
                  child: SizedBox(
                    height: 128,
                    width: double.infinity,
                    child: HabitoPortraitImage(
                      imageUrl: imageUrl,
                      fallback: const _MiniBarberFallback(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: AppRadius.full,
                  ),
                  child: const Text(
                    'Team Hábito',
                    style: TextStyle(
                      color: AppColors.goldDeep,
                      fontSize: AppTextSize.captionXs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: AppTextSize.titleSmall,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBarberFallback extends StatelessWidget {
  const _MiniBarberFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primarySoft, AppColors.goldDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.content_cut,
          color: Colors.white,
          size: AppIconSize.lg,
        ),
      ),
    );
  }
}

class _BarberProfileModal extends StatelessWidget {
  final Map<String, dynamic> barber;

  const _BarberProfileModal({required this.barber});

  @override
  Widget build(BuildContext context) {
    final imageUrl = barber['pictureFullPath']?.toString() ?? '';
    final name = barber['fullName']?.toString() ?? 'Barbero Hábito';
    final rawDescription = barber['description']?.toString() ?? '';
    final description = _cleanHtml(rawDescription).isNotEmpty
        ? _cleanHtml(rawDescription)
        : 'Barbero profesional de Hábito. Muy pronto conocerás más sobre su experiencia, especialidades y estilo.';

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.55,
        maxChildSize: 0.94,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.bottomSheet,
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Center(
                  child: Container(
                    width: AppSpacing.actionHeight,
                    height: AppSpacing.xs + AppSpacing.xxs / 2,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: AppRadius.card,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: AppRadius.extraLarge,
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: HabitoPortraitImage(
                      imageUrl: imageUrl,
                      fallback: const _BarberImageFallback(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: AppTextSize.headlineMedium + AppSpacing.xxs,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.16),
                    borderRadius: AppRadius.medium,
                  ),
                  child: const Text(
                    'Barbero Hábito',
                    style: TextStyle(
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                const Text(
                  'Perfil',
                  style: TextStyle(
                    fontSize: AppTextSize.titleLarge,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: AppTextSize.titleSmall,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final auth = context.read<AuthProvider>();
                      Navigator.pop(context);

                      if (!auth.isLoggedIn) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Inicia sesión para reservar tu cita.'),
                            ),
                          );
                        Navigator.pushNamed(context, AppRoutes.login);
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingsPage(
                            selectedBarber: barber,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                      elevation: AppSpacing.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.tile,
                      ),
                    ),
                    child: const Text(
                      'Reservar con este barbero',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppTextSize.titleSmall,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.secondary,
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.tile,
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppTextSize.titleSmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}

class _BarberImageFallback extends StatelessWidget {
  const _BarberImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primarySoft, AppColors.goldDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.content_cut,
          color: Colors.white,
          size: AppIconSize.xl,
        ),
      ),
    );
  }
}
