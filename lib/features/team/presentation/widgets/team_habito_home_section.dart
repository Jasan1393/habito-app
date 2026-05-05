import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
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
        'pictureFullPath': employeeMap['pictureThumbPath'] ??
            employeeMap['pictureFullPath'] ??
            employeeMap['picture'] ??
            employeeMap['image'] ??
            employeeMap['avatar'],
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
      backgroundColor: const Color(0xFFF6F4F1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
        const SizedBox(height: 12),
        SizedBox(
          height: 256,
          child: _isLoading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => Container(
                    width: 184,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _barbers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Text(
                  'Ver todos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9C7732),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9C7732),
                  size: 18,
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
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          width: 184,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 128,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty
                        ? HabitoCachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: const _MiniBarberFallback(),
                          )
                        : const _MiniBarberFallback(),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Team Hábito',
                    style: TextStyle(
                      color: Color(0xFF8B6A28),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 15,
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
          colors: [Color(0xFF2B2118), Color(0xFF6E5031)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.content_cut,
          color: Colors.white,
          size: 28,
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
              color: Color(0xFFF6F4F1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty
                        ? HabitoCachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: const _BarberImageFallback(),
                          )
                        : const _BarberImageFallback(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Barbero Hábito',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
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
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Reservar con este barbero',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: Color(0xFFD4AF37),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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
          colors: [Color(0xFF2B2118), Color(0xFF6E5031)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.content_cut,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}
