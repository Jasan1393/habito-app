import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/location_coordinate_cache_service.dart';
import '../../../../core/services/location_launcher_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/habito_bottom_navigation_bar.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../bookings/presentation/pages/bookings_page.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import '../../../shop/presentation/pages/cart_page.dart';
import '../../../shop/presentation/pages/products_archive_page.dart';
import '../../../shop/provider/shop_provider.dart';

class LocationsPage extends StatefulWidget {
  final int selectedNavIndex;

  const LocationsPage({
    super.key,
    this.selectedNavIndex = 0,
  });

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

enum _LocationAccessIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class _LocationsPageState extends State<LocationsPage> {
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLocating = false;
  bool _isResolvingMapLinks = false;
  String? _error;
  _LocationAccessIssue? _locationAccessIssue;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadLocations);
  }

  Future<void> _loadLocations({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await HabitoBookingApi.getLocations(
        forceRefresh: forceRefresh,
      );
      _applyLocations(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyLocations(List<dynamic> rawLocations) {
    final parsed = rawLocations
        .whereType<Map>()
        .map((item) => _normalizeLocation(Map<String, dynamic>.from(item)))
        .where((item) => item['id'] != null && item['name'] != '')
        .toList();

    if (!mounted) return;
    setState(() {
      _locations = parsed;
    });

    unawaited(_cacheKnownCoordinates(parsed));
    unawaited(_resolveCoordinatesFromMapLinks());
  }

  Map<String, dynamic> _normalizeLocation(Map<String, dynamic> item) {
    final description = (item['description'] ?? '').toString().trim();
    final directCoordinates =
        LocationLauncherService.extractCoordinatesFromText(description);
    final mapUrl = LocationLauncherService.extractLocationUrl(description);
    final hasMapUrl = mapUrl != null;
    final backendLatitude = _parseDouble(item['latitude']);
    final backendLongitude = _parseDouble(item['longitude']);
    final useBackendCoordinates = !hasMapUrl &&
        LocationLauncherService.hasUsableCoordinates(
          backendLatitude,
          backendLongitude,
        );

    return {
      'id': _parseInt(item['id']),
      'name': (item['name'] ?? '').toString().trim(),
      'address': (item['address'] ?? '').toString().trim(),
      'description': description,
      'phone': (item['phone'] ?? '').toString().trim(),
      'latitude': directCoordinates?.latitude ??
          (useBackendCoordinates ? backendLatitude : null),
      'longitude': directCoordinates?.longitude ??
          (useBackendCoordinates ? backendLongitude : null),
      'map_url': mapUrl,
      'status': (item['status'] ?? '').toString().trim(),
    };
  }

  Future<void> _resolveCoordinatesFromMapLinks() async {
    if (_isResolvingMapLinks) return;

    final candidates = _locations
        .where((location) =>
            !_hasLocationCoordinates(location) &&
            (location['map_url'] ?? '').toString().trim().isNotEmpty)
        .toList();

    if (candidates.isEmpty) return;

    setState(() {
      _isResolvingMapLinks = true;
    });

    var updatedLocations = _locations
        .map((location) => Map<String, dynamic>.from(location))
        .toList();
    var hasChanges = false;

    for (final location in candidates) {
      final id = location['id'];
      final cacheKey = _coordinateCacheKey(location);
      var coordinates = await LocationCoordinateCacheService.get(cacheKey);
      var coordinatesSource = 'cache';

      if (coordinates == null) {
        coordinates = await LocationLauncherService.resolveCoordinatesFromText(
          location['description']?.toString(),
        );
        coordinatesSource = 'maps_link';
      }

      if (coordinates == null) continue;

      final index = updatedLocations.indexWhere((item) => item['id'] == id);
      if (index < 0) continue;

      updatedLocations[index] = {
        ...updatedLocations[index],
        'latitude': coordinates.latitude,
        'longitude': coordinates.longitude,
        'coordinates_source': coordinatesSource,
      };
      hasChanges = true;

      if (coordinatesSource != 'cache') {
        unawaited(LocationCoordinateCacheService.put(cacheKey, coordinates));
      }
    }

    if (!mounted) return;

    setState(() {
      if (hasChanges) {
        _locations = updatedLocations;
      }
      _isResolvingMapLinks = false;
    });
  }

  Future<void> _cacheKnownCoordinates(
    List<Map<String, dynamic>> locations,
  ) async {
    final coordinatesByKey = <String, LocationCoordinates>{};

    for (final location in locations) {
      final cacheKey = _coordinateCacheKey(location);
      final latitude = location['latitude'];
      final longitude = location['longitude'];
      if (cacheKey.isEmpty || latitude is! double || longitude is! double) {
        continue;
      }

      if (!LocationLauncherService.hasUsableCoordinates(latitude, longitude)) {
        continue;
      }

      coordinatesByKey[cacheKey] = LocationCoordinates(latitude, longitude);
    }

    await LocationCoordinateCacheService.putMany(coordinatesByKey);
  }

  Future<void> _findNearestLocation() async {
    setState(() {
      _isLocating = true;
      _locationAccessIssue = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationAccessIssue = _LocationAccessIssue.serviceDisabled;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _locationAccessIssue = _LocationAccessIssue.permissionDenied;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationAccessIssue = _LocationAccessIssue.permissionDeniedForever;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!mounted) return;

      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
        _locationAccessIssue = null;
      });
      unawaited(_resolveCoordinatesFromMapLinks());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationAccessIssue = _LocationAccessIssue.unavailable;
      });
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _sortedLocations() {
    final items = List<Map<String, dynamic>>.from(_locations);
    if (_userLatitude == null || _userLongitude == null) return items;

    items.sort((a, b) {
      final distanceA = _distanceFor(a) ?? double.maxFinite;
      final distanceB = _distanceFor(b) ?? double.maxFinite;
      return distanceA.compareTo(distanceB);
    });
    return items;
  }

  double? _distanceFor(Map<String, dynamic> location) {
    final lat = location['latitude'];
    final lng = location['longitude'];
    if (_userLatitude == null ||
        _userLongitude == null ||
        lat is! double ||
        lng is! double ||
        !LocationLauncherService.hasUsableCoordinates(lat, lng)) {
      return null;
    }

    return Geolocator.distanceBetween(
      _userLatitude!,
      _userLongitude!,
      lat,
      lng,
    );
  }

  bool _hasLocationCoordinates(Map<String, dynamic> location) {
    final lat = location['latitude'];
    final lng = location['longitude'];
    return lat is double &&
        lng is double &&
        LocationLauncherService.hasUsableCoordinates(lat, lng);
  }

  String _coordinateCacheKey(Map<String, dynamic> location) {
    final id = location['id']?.toString().trim() ?? '';
    final mapUrl = location['map_url']?.toString().trim() ?? '';
    final name = location['name']?.toString().trim() ?? '';
    final address = location['address']?.toString().trim() ?? '';

    if (id.isNotEmpty && mapUrl.isNotEmpty) return '$id|$mapUrl';
    if (id.isNotEmpty) return id;
    if (mapUrl.isNotEmpty) return mapUrl;
    return '$name|$address'.trim();
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openMap(Map<String, dynamic> location) async {
    final opened = await LocationLauncherService.openMap(
      address: location['address']?.toString(),
      latitude: location['latitude'] is double ? location['latitude'] : null,
      longitude: location['longitude'] is double ? location['longitude'] : null,
      branchName: location['name']?.toString(),
      description: location['description']?.toString(),
    );

    if (!mounted) return;

    if (!opened) {
      _showSnack('No pudimos abrir la ubicación de esta sucursal.');
    }
  }

  Future<void> _callLocation(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      _showSnack('Esta sucursal no tiene teléfono disponible.');
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnack('No pudimos iniciar la llamada.');
      }
    } catch (_) {
      _showSnack('No pudimos iniciar la llamada.');
    }
  }

  Future<void> _reserveAt(Map<String, dynamic> location) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingsPage(
          initialBranch: location['name']?.toString(),
        ),
      ),
    );
  }

  Future<void> _goToMainTab(int index) async {
    const protectedIndexes = [2, 3];
    if (protectedIndexes.contains(index) &&
        !context.read<AuthProvider>().isLoggedIn) {
      await Navigator.pushNamed(context, AppRoutes.login);
      if (!mounted || !context.read<AuthProvider>().isLoggedIn) return;
    }

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

  Future<void> _handleLocationAccessAction(
    _LocationAccessIssue issue,
  ) async {
    switch (issue) {
      case _LocationAccessIssue.serviceDisabled:
        await Geolocator.openLocationSettings();
        break;
      case _LocationAccessIssue.permissionDenied:
      case _LocationAccessIssue.unavailable:
        await _findNearestLocation();
        break;
      case _LocationAccessIssue.permissionDeniedForever:
        await Geolocator.openAppSettings();
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<ShopProvider, int>(
      (provider) => provider.cartCount,
    );
    final locations = _sortedLocations();
    final showDistances = _userLatitude != null && _userLongitude != null;
    final selectedNavIndex = widget.selectedNavIndex.clamp(0, 4).toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopHeader(
        searchHint: 'Buscar productos',
        cartCount: cartCount,
        onSearchTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductsArchivePage()),
          );
        },
        onCartTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          );
        },
        leadingIcon: Icons.arrow_back_rounded,
        leadingTooltip: 'Volver',
        onLeadingTap: () => Navigator.maybePop(context),
        compactSearch: true,
      ),
      bottomNavigationBar: HabitoBottomNavigationBar(
        selectedIndex: selectedNavIndex,
        onDestinationSelected: _goToMainTab,
      ),
      body: RefreshIndicator(
        color: const Color(0xFFD4AF37),
        onRefresh: () => _loadLocations(forceRefresh: true),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              )
            : _error != null && locations.isEmpty
                ? _LocationsErrorView(
                    message: _error!,
                    onRetry: () => _loadLocations(forceRefresh: true),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _SectionTitle(
                        isLocating: _isLocating,
                        onFindNearest: _findNearestLocation,
                      ),
                      if (_locationAccessIssue != null) ...[
                        const SizedBox(height: 12),
                        _LocationAccessNotice(
                          issue: _locationAccessIssue!,
                          onAction: () => _handleLocationAccessAction(
                            _locationAccessIssue!,
                          ),
                        ),
                      ],
                      if (_isRefreshing) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(
                          minHeight: 3,
                          color: Color(0xFFD4AF37),
                          backgroundColor: Color(0xFFE8E0D4),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (locations.isEmpty)
                        const _EmptyLocationsView()
                      else
                        ...locations.asMap().entries.map(
                          (entry) {
                            final distance = _distanceFor(entry.value);
                            final isNearest = _userLatitude != null &&
                                distance != null &&
                                entry.key == 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _LocationCard(
                                location: entry.value,
                                isNearest: isNearest,
                                showDistance: showDistances,
                                distanceLabel: _formatDistance(distance),
                                onOpenMap: () => _openMap(entry.value),
                                onCall: () => _callLocation(
                                  entry.value['phone']?.toString() ?? '',
                                ),
                                onReserve: () => _reserveAt(entry.value),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
      ),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _SectionTitle extends StatelessWidget {
  final bool isLocating;
  final VoidCallback onFindNearest;

  const _SectionTitle({
    required this.isLocating,
    required this.onFindNearest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: isLocating ? null : onFindNearest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location_rounded, size: 19),
            label: Text(
              isLocating ? 'Buscando...' : 'Buscar sucursal más cercana',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Map<String, dynamic> location;
  final bool isNearest;
  final bool showDistance;
  final String distanceLabel;
  final VoidCallback onOpenMap;
  final VoidCallback onCall;
  final VoidCallback onReserve;

  const _LocationCard({
    required this.location,
    required this.isNearest,
    required this.showDistance,
    required this.distanceLabel,
    required this.onOpenMap,
    required this.onCall,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final name = (location['name'] ?? 'Sucursal').toString();
    final address = (location['address'] ?? '').toString();
    final phone = (location['phone'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isNearest ? const Color(0xFFFFFAEC) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isNearest ? const Color(0xFFD4AF37) : AppColors.border,
          width: isNearest ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isNearest
                ? const Color(0xFFD4AF37).withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isNearest ? 24 : 16,
            offset: Offset(0, isNearest ? 12 : 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNearest) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.near_me_rounded,
                    color: Color(0xFFE7D39A),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sucursal más cercana a ti',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFFE7D39A),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (isNearest)
                          const _Badge(
                            label: 'Más cercana',
                            icon: Icons.near_me_rounded,
                          ),
                      ],
                    ),
                    if (showDistance) ...[
                      const SizedBox(height: 5),
                      Text(
                        distanceLabel.isEmpty
                            ? 'Distancia no disponible'
                            : distanceLabel,
                        style: const TextStyle(
                          color: Color(0xFF9C7732),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoLine(icon: Icons.location_on_outlined, text: address),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 9),
            _InfoLine(icon: Icons.call_outlined, text: phone),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenMap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9C7732),
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text(
                    'Cómo llegar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onCall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Icon(Icons.call_rounded, size: 20),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onReserve,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text(
                'Reservar en esta sucursal',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7D39A).withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7A5B1B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A5B1B),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF9C7732)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationAccessNotice extends StatelessWidget {
  final _LocationAccessIssue issue;
  final VoidCallback onAction;

  const _LocationAccessNotice({
    required this.issue,
    required this.onAction,
  });

  String get _title {
    switch (issue) {
      case _LocationAccessIssue.serviceDisabled:
        return 'Activa la ubicación';
      case _LocationAccessIssue.permissionDenied:
        return 'Permiso de ubicación pendiente';
      case _LocationAccessIssue.permissionDeniedForever:
        return 'Permiso bloqueado';
      case _LocationAccessIssue.unavailable:
        return 'No pudimos leer tu ubicación';
    }
  }

  String get _message {
    switch (issue) {
      case _LocationAccessIssue.serviceDisabled:
        return 'Para calcular la sucursal más cercana, activa la ubicación del dispositivo y vuelve a intentarlo.';
      case _LocationAccessIssue.permissionDenied:
        return 'Necesitamos tu permiso para calcular distancias. Toca nuevamente y acepta la solicitud del sistema.';
      case _LocationAccessIssue.permissionDeniedForever:
        return 'El permiso quedó bloqueado para la app. Puedes activarlo desde los ajustes del dispositivo.';
      case _LocationAccessIssue.unavailable:
        return 'Intenta nuevamente en unos segundos o elige una sucursal de la lista.';
    }
  }

  String get _actionLabel {
    switch (issue) {
      case _LocationAccessIssue.serviceDisabled:
        return 'Abrir ubicación';
      case _LocationAccessIssue.permissionDenied:
      case _LocationAccessIssue.unavailable:
        return 'Intentar nuevamente';
      case _LocationAccessIssue.permissionDeniedForever:
        return 'Abrir ajustes';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7D39A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFE7D39A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: Text(
                      _actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
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

class _EmptyLocationsView extends StatelessWidget {
  const _EmptyLocationsView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 52,
            color: Color(0xFF9C7732),
          ),
          SizedBox(height: 14),
          Text(
            'No hay sucursales disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Intenta actualizar la pantalla en unos segundos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LocationsErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: Color(0xFFA33A3A),
              ),
              const SizedBox(height: 14),
              const Text(
                'No pudimos cargar las sucursales',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Reintentar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
