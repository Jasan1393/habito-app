import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: const Color(0xFFF6F4F1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
      backgroundColor: const Color(0xFFF6F4F1),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    const Text(
                      'Nuestros Barberos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Conoce al equipo que hace posible la experiencia Hábito.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      itemCount: _barbers.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.42,
                      ),
                      itemBuilder: (context, index) {
                        final barber = _barbers[index];
                        final isSelected = widget.selectedBarberId != null &&
                            barber['id'] == widget.selectedBarberId;

                        return _BarberCard(
                          barber: barber,
                          isSelected: isSelected,
                          onTapProfile: () => _openBarberProfile(barber),
                          onTapReserve: () => _goToBooking(barber),
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
  final bool isSelected;
  final VoidCallback onTapProfile;
  final VoidCallback onTapReserve;

  const _BarberCard({
    required this.barber,
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
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTapProfile,
        borderRadius: BorderRadius.circular(26),
        splashColor: const Color(0xFFD4AF37).withValues(alpha: 0.10),
        highlightColor: const Color(0xFFD4AF37).withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFEAE3D8),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.055),
                blurRadius: isSelected ? 20 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 136,
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
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F1E2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFE7D7AE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Color(0xFF9C7732),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          locationName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF7A5D25),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Barbero profesional',
                  style: TextStyle(
                    fontSize: 12.5,
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
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: Color(0xFFD9C9A0),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                            errorWidget: _BarberImageFallback(name: name),
                          )
                        : _BarberImageFallback(name: name),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F1E2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE7D7AE),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: Color(0xFF9C7732),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            locationName,
                            style: const TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A5D25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
  final String name;

  const _BarberImageFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'H';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2B2118), Color(0xFF6E5031)],
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
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
            borderRadius: BorderRadius.circular(26),
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
        padding: EdgeInsets.all(24),
        child: Text(
          'No hay barberos disponibles por el momento.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
