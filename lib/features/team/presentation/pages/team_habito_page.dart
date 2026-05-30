import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';

class TeamHabitoPage extends StatefulWidget {
  final int? selectedBarberId;

  const TeamHabitoPage({
    super.key,
    this.selectedBarberId,
  });

  @override
  State<TeamHabitoPage> createState() => _TeamHabitoPageState();
}

class _TeamHabitoPageState extends State<TeamHabitoPage> {
  List<Map<String, dynamic>> _barbers = [];
  bool _isLoading = true;
  bool _didRetryLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBarbers();
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

  String _extractPrimaryLocationName(Map<String, dynamic> employee) {
    final directName = (employee['locationName'] ??
            employee['location_name'] ??
            employee['branch'] ??
            '')
        .toString()
        .trim();

    if (directName.isNotEmpty) {
      return directName;
    }

    final rawLocations = employee['locations'];
    if (rawLocations is List && rawLocations.isNotEmpty) {
      final first = rawLocations.first;

      if (first is Map) {
        final name = (first['name'] ?? first['title'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }

      if (first is String) {
        final name = first.trim();
        if (name.isNotEmpty) return name;
      }
    }

    return 'Sucursal Hábito';
  }

  Future<void> _loadBarbers() async {
    final cachedEmployees = await HabitoBookingApi.getCachedEmployees();

    if (cachedEmployees.isNotEmpty && mounted) {
      setState(() {
        _barbers = _mapEmployees(cachedEmployees);
        _isLoading = false;
      });
    }

    try {
      final employees = await HabitoBookingApi.getEmployees(
        forceRefresh: cachedEmployees.isNotEmpty,
      );

      final mapped = _mapEmployees(employees);

      if (widget.selectedBarberId != null) {
        mapped.sort((a, b) {
          final aSelected = a['id'] == widget.selectedBarberId ? 1 : 0;
          final bSelected = b['id'] == widget.selectedBarberId ? 1 : 0;
          return bSelected.compareTo(aSelected);
        });
      }

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

  List<Map<String, dynamic>> _mapEmployees(List<dynamic> employees) {
    return employees.map<Map<String, dynamic>>((employee) {
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
      final locationName = _extractPrimaryLocationName(employeeMap);

      return {
        'id': _safeInt(employeeMap['id']) ?? 0,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName.isEmpty ? 'Barbero Hábito' : fullName,
        'pictureFullPath': employeeMap['pictureThumbPath'] ??
            employeeMap['pictureFullPath'] ??
            employeeMap['picture'] ??
            employeeMap['image'] ??
            employeeMap['avatar'],
        'description': employeeMap['description'] ?? employeeMap['bio'] ?? '',
        'locationId': locationId,
        'locationIds': locationIds,
        'locationName': locationName,
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

  void _goToBooking(Map<String, dynamic> barber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingsPage(
          selectedBarber: barber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: AppSpacing.none,
        centerTitle: true,
        title: const Text(
          'Team Hábito',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const _TeamLoadingView()
          : _barbers.isEmpty
              ? const _EmptyTeamView()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  children: [
                    const Text(
                      'Nuestros Barberos',
                      style: TextStyle(
                        fontSize: AppTextSize.headlineMedium,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                    const Text(
                      'Conoce al equipo que hace posible la experiencia Hábito.',
                      style: TextStyle(
                        fontSize: AppTextSize.base,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final crossAxisCount = width >= 900
                            ? 3
                            : width >= 560
                                ? 2
                                : 1;
                        final isTabletGrid = width >= 560;
                        final imageHeight = isTabletGrid ? 210.0 : 190.0;
                        final cardHeight = isTabletGrid ? 500.0 : 475.0;

                        return GridView.builder(
                          itemCount: _barbers.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisExtent: cardHeight,
                          ),
                          itemBuilder: (context, index) {
                            final barber = _barbers[index];
                            final isSelected =
                                widget.selectedBarberId != null &&
                                    barber['id'] == widget.selectedBarberId;

                            return _BarberCard(
                              barber: barber,
                              imageHeight: imageHeight,
                              isSelected: isSelected,
                              onTapProfile: () => _openBarberProfile(barber),
                              onTapReserve: () => _goToBooking(barber),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  final Map<String, dynamic> barber;
  final double imageHeight;
  final bool isSelected;
  final VoidCallback onTapProfile;
  final VoidCallback onTapReserve;

  const _BarberCard({
    required this.barber,
    required this.imageHeight,
    required this.onTapProfile,
    required this.onTapReserve,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = barber['pictureFullPath']?.toString() ?? '';
    final name = barber['fullName']?.toString() ?? 'Barbero Hábito';
    final locationName =
        barber['locationName']?.toString().trim().isNotEmpty == true
            ? barber['locationName'].toString().trim()
            : 'Sucursal Hábito';

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.hero,
      child: InkWell(
        onTap: onTapProfile,
        borderRadius: AppRadius.hero,
        splashColor: AppColors.secondary.withValues(alpha: 0.10),
        highlightColor: AppColors.secondary.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.hero,
            border: Border.all(
              color: isSelected ? AppColors.secondary : AppColors.border,
              width: isSelected ? AppSpacing.xxs : AppSpacing.xxs / 2,
            ),
            boxShadow: isSelected ? AppShadows.goldGlow : AppShadows.medium,
          ),
          child: Padding(
            padding: AppSpacing.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.large,
                      child: SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: imageUrl.isNotEmpty
                            ? HabitoCachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: _BarberImageFallback(name: name),
                              )
                            : _BarberImageFallback(name: name),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: AppIconSize.lg,
                          height: AppIconSize.lg,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: AppRadius.full,
                            boxShadow: AppShadows.goldGlow,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: AppIconSize.action,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.cartItemGap),
                SizedBox(
                  height: 46,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: AppTextSize.titleMedium,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: AppRadius.full,
                    border: Border.all(
                      color: AppColors.borderStrong,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.goldDeep,
                      ),
                      const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          locationName,
                          style: const TextStyle(
                            fontSize: AppTextSize.bodySmall,
                            color: AppColors.goldDeep,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Barbero profesional',
                  style: TextStyle(
                    fontSize: AppTextSize.bodySmall,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: onTapReserve,
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Reservar',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppTextSize.base,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                      elevation: AppSpacing.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + AppSpacing.xxs,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: onTapProfile,
                    icon: const Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Ver perfil',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: AppTextSize.base,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.borderStrong,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
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

class _BarberProfileModal extends StatelessWidget {
  final Map<String, dynamic> barber;

  const _BarberProfileModal({required this.barber});

  @override
  Widget build(BuildContext context) {
    final imageUrl = barber['pictureFullPath']?.toString() ?? '';
    final name = barber['fullName']?.toString() ?? 'Barbero Hábito';
    final locationName =
        barber['locationName']?.toString().trim().isNotEmpty == true
            ? barber['locationName'].toString().trim()
            : 'Sucursal Hábito';
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
                    child: imageUrl.isNotEmpty
                        ? HabitoCachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: _BarberImageFallback(name: name),
                          )
                        : _BarberImageFallback(name: name),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted,
                        borderRadius: AppRadius.medium,
                        border: Border.all(
                          color: AppColors.borderStrong,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: AppColors.goldDeep,
                          ),
                          const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                          Text(
                            locationName,
                            style: const TextStyle(
                              fontSize: AppTextSize.bodyCompact,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      Navigator.pop(context);

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
  final String name;

  const _BarberImageFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'H';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primarySoft, AppColors.goldDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: AppRadius.full,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppTextSize.headlineMedium + AppSpacing.xxs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLoadingView extends StatelessWidget {
  const _TeamLoadingView();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.42,
      ),
      itemBuilder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.hero,
          ),
        );
      },
    );
  }
}

class _EmptyTeamView extends StatelessWidget {
  const _EmptyTeamView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: AppSpacing.section,
        child: Text(
          'No hay barberos disponibles por el momento.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTextSize.titleMedium,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
