import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/constants/ecuador_data.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/location_launcher_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../core/validators/ecuador_id_validator.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../shared/widgets/habito_cached_network_image.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../../../shared/widgets/main_navigation_page.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../points/points_calculator.dart';
import '../../../points/provider/points_provider.dart';
import '../../../shop/models/shop_payment_method.dart';
import '../../../shop/provider/shop_provider.dart';
import 'package:habito/features/shop/data/services/habito_booking_api.dart';

class BookingsPage extends StatefulWidget {
  final Map<String, dynamic>? service;
  final Map<String, dynamic>? selectedBarber;
  final String? initialBranch;
  final String? initialBarber;
  final DateTime? initialDate;
  final String? initialTime;
  final String? appointmentId;

  const BookingsPage({
    super.key,
    this.service,
    this.selectedBarber,
    this.initialBranch,
    this.initialBarber,
    this.initialDate,
    this.initialTime,
    this.appointmentId,
  });

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  List<Map<String, dynamic>> _locations = [];
  List<String> _availableTimeSlots = [];
  String? _availabilityNoticeMessage;

  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedEmployee;
  Map<String, dynamic>? _selectedLocation;

  final Map<int, int> _selectedExtrasQty = {};

  String? _selectedTimeSlot;
  String _selectedPaymentMethodId = ShopPaymentMethod.bankTransfer.id;
  String _contactType = 'individual';
  String _identificationType = 'cedula';
  String _province = 'Guayas';
  DateTime? _selectedDate;

  bool _isLoading = true;
  bool _isLoadingAvailability = false;
  bool _isSubmittingBooking = false;
  bool _showAllTimeSlots = true;
  bool _wantsServiceExtras = false;
  bool _usePoints = false;
  bool _useBirthdayBonus = false;
  int _availabilityRequestId = 0;

  bool get _isEditing => widget.appointmentId != null;

  bool get _isNewBookingFlow {
    return !_isEditing &&
        widget.service == null &&
        widget.selectedBarber == null &&
        widget.initialBranch == null &&
        widget.initialBarber == null &&
        widget.initialDate == null &&
        widget.initialTime == null;
  }

  bool get _isFormValid {
    return _selectedService != null &&
        _selectedLocation != null &&
        _selectedEmployee != null &&
        _selectedDate != null &&
        (_selectedTimeSlot?.isNotEmpty ?? false) &&
        _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _isValidPhone(_phoneController.text) &&
        _isValidEmail(_emailController.text) &&
        _isCustomerFiscalDataValid;
  }

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate;
    _selectedTimeSlot = null;

    _firstNameController.addListener(_refreshFormState);
    _middleNameController.addListener(_refreshFormState);
    _lastNameController.addListener(_refreshFormState);
    _phoneController.addListener(_refreshFormState);
    _emailController.addListener(_refreshFormState);
    _businessNameController.addListener(_refreshFormState);
    _taxNumberController.addListener(_refreshFormState);
    _cityController.addListener(_refreshFormState);
    _addressController.addListener(_refreshFormState);

    _prefillCustomerDataFromSession();
    _loadInitialData();
    Future.microtask(_loadPaymentMethods);
    Future.microtask(_loadPointsSummaryIfNeeded);
  }

  Future<void> _loadPointsSummaryIfNeeded() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    await context.read<PointsProvider>().load(forceRefresh: true);
  }

  void _prefillCustomerDataFromSession() {
    try {
      final auth = context.read<AuthProvider>();

      if (!auth.isLoggedIn || auth.user == null) return;

      final user = auth.user!;

      final fallbackNameParts = _splitFullName(user.displayName);

      if (_firstNameController.text.trim().isEmpty) {
        _firstNameController.text = user.firstName.trim().isNotEmpty
            ? user.firstName.trim()
            : (fallbackNameParts['firstName'] ?? '').trim();
      }

      if (_middleNameController.text.trim().isEmpty &&
          user.middleName.trim().isNotEmpty) {
        _middleNameController.text = user.middleName.trim();
      }

      if (_lastNameController.text.trim().isEmpty) {
        _lastNameController.text = user.lastName.trim().isNotEmpty
            ? user.lastName.trim()
            : (fallbackNameParts['lastName'] ?? '').trim();
      }

      if (_phoneController.text.trim().isEmpty &&
          user.phone.trim().isNotEmpty) {
        _phoneController.text = user.phone.trim();
      }

      if (_emailController.text.trim().isEmpty &&
          user.email.trim().isNotEmpty) {
        _emailController.text = user.email.trim();
      }

      _contactType = user.contactType.trim().isNotEmpty
          ? user.contactType.trim()
          : 'individual';
      _identificationType = _normalizeIdentificationType(
        user.identificationType,
      );
      if (_contactType == 'business') {
        _identificationType = 'ruc';
      }
      _province =
          kEcuadorProvinces.contains(user.province) ? user.province : 'Guayas';

      if (_businessNameController.text.trim().isEmpty &&
          user.businessName.trim().isNotEmpty) {
        _businessNameController.text = user.businessName.trim();
      }

      if (_taxNumberController.text.trim().isEmpty &&
          user.taxNumber.trim().isNotEmpty) {
        _taxNumberController.text = user.taxNumber.trim();
      }

      if (_cityController.text.trim().isEmpty && user.city.trim().isNotEmpty) {
        _cityController.text = user.city.trim();
      }

      if (_addressController.text.trim().isEmpty &&
          user.address.trim().isNotEmpty) {
        _addressController.text = user.address.trim();
      }
    } catch (_) {
      // Evita romper la pantalla si el provider aún no está listo.
    }
  }

  Future<void> _loadPaymentMethods() async {
    final shop = context.read<ShopProvider>();
    await shop.loadPaymentMethods();

    if (!mounted) return;

    final methods = _enabledPaymentMethods(shop);
    final selectedExists = methods.any(
      (method) => method.id == _selectedPaymentMethodId,
    );

    if (!selectedExists && methods.isNotEmpty) {
      setState(() {
        _selectedPaymentMethodId = methods
            .firstWhere(
              (method) => method.canCreateManualOrder,
              orElse: () => methods.first,
            )
            .id;
      });
    }
  }

  List<ShopPaymentMethod> _enabledPaymentMethods(ShopProvider shop) {
    final methods = shop.paymentMethods
        .where((method) => method.enabled)
        .toList(growable: true);

    if (methods.isEmpty) {
      return const [ShopPaymentMethod.bankTransfer, ShopPaymentMethod.onSite];
    }

    if (!methods.any((method) => method.isOnSite)) {
      methods.add(ShopPaymentMethod.onSite);
    }

    return List<ShopPaymentMethod>.unmodifiable(methods);
  }

  ShopPaymentMethod _selectedPaymentMethod(List<ShopPaymentMethod> methods) {
    for (final method in methods) {
      if (method.id == _selectedPaymentMethodId && method.enabled) {
        return method;
      }
    }

    for (final method in methods) {
      if (method.enabled && method.canCreateManualOrder) return method;
    }

    return methods.isNotEmpty ? methods.first : ShopPaymentMethod.bankTransfer;
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final cachedResults = await Future.wait([
        HabitoBookingApi.getCachedServices(),
        HabitoBookingApi.getCachedEmployees(),
        HabitoBookingApi.getCachedLocations(),
      ]);

      final hasCompleteCache = cachedResults.every((items) => items.isNotEmpty);

      if (hasCompleteCache) {
        await _applyInitialCatalogData(
          services: cachedResults[0],
          employees: cachedResults[1],
          locations: cachedResults[2],
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        unawaited(_refreshInitialCatalogData());
        return;
      }

      final services = await _loadServicesWithFallback(cachedResults[0]);
      final employees = await _loadEmployeesWithFallback(cachedResults[1]);
      final locations = await _loadLocationsWithFallback(cachedResults[2]);

      await _applyInitialCatalogData(
        services: services,
        employees: employees,
        locations: locations,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        FriendlyErrors.loadData(
          e,
          fallback: 'No pudimos cargar los datos para reservar.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshInitialCatalogData() async {
    try {
      final services = await _loadServicesWithFallback(_services);
      final employees = await _loadEmployeesWithFallback(_employees);
      final locations = await _loadLocationsWithFallback(_locations);

      if (!mounted) return;

      await _applyInitialCatalogData(
        services: services,
        employees: employees,
        locations: locations,
        preserveAvailability: true,
      );
    } catch (_) {
      // Refresco silencioso: la pantalla ya tiene cache util.
    }
  }

  Future<List<dynamic>> _loadServicesWithFallback(
      List<dynamic> fallback) async {
    try {
      return await HabitoBookingApi.getServices(forceRefresh: true);
    } catch (_) {
      return fallback;
    }
  }

  Future<List<dynamic>> _loadEmployeesWithFallback(
    List<dynamic> fallback,
  ) async {
    try {
      return await HabitoBookingApi.getEmployees(forceRefresh: true);
    } catch (_) {
      return fallback;
    }
  }

  Future<List<dynamic>> _loadLocationsWithFallback(
    List<dynamic> fallback,
  ) async {
    try {
      return await HabitoBookingApi.getLocations(forceRefresh: true);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _applyInitialCatalogData({
    required List<dynamic> services,
    required List<dynamic> employees,
    required List<dynamic> locations,
    bool preserveAvailability = false,
  }) async {
    final parsedServices = services
        .map((item) => _normalizeService(item))
        .where((item) => item['id'] != null && item['title'] != null)
        .toList();

    final parsedEmployees = employees
        .map((item) => _normalizeEmployee(item))
        .where((item) => item['id'] != null && item['fullName'] != null)
        .toList();

    final parsedLocations = locations
        .map((item) => _normalizeLocation(item))
        .where((item) => item['id'] != null && item['name'] != null)
        .toList();

    Map<String, dynamic>? initialService;
    Map<String, dynamic>? initialLocation;

    if (!_isNewBookingFlow) {
      if (widget.service != null) {
        final incomingId = _safeInt(widget.service!['id']);
        final incomingTitle = widget.service!['title']?.toString().trim();

        for (final service in parsedServices) {
          if (incomingId != null && service['id'] == incomingId) {
            initialService = service;
            break;
          }
          if (incomingTitle != null &&
              incomingTitle.isNotEmpty &&
              service['title'] == incomingTitle) {
            initialService = service;
            break;
          }
        }
      }

      final barberLocationId = _safeInt(widget.selectedBarber?['locationId']);

      if (barberLocationId != null) {
        for (final location in parsedLocations) {
          if (_safeInt(location['id']) == barberLocationId) {
            initialLocation = location;
            break;
          }
        }
      }

      if (initialLocation == null &&
          widget.initialBranch != null &&
          widget.initialBranch!.trim().isNotEmpty) {
        final incomingBranch = widget.initialBranch!.trim().toLowerCase();

        for (final location in parsedLocations) {
          final locationName =
              (location['name'] ?? '').toString().toLowerCase();

          if (locationName.contains(incomingBranch) ||
              incomingBranch.contains(locationName)) {
            initialLocation = location;
            break;
          }
        }
      }
    }

    final incomingBarberId = _resolveIncomingBarberId();
    final incomingBarberName = _resolveIncomingBarberName();
    final selectedServiceToApply = preserveAvailability
        ? _matchCatalogItem(
              parsedServices,
              _selectedService,
              labelKey: 'title',
            ) ??
            _selectedService
        : initialService;
    final selectedLocationToApply = preserveAvailability
        ? _matchCatalogItem(
              parsedLocations,
              _selectedLocation,
              labelKey: 'name',
            ) ??
            _selectedLocation
        : initialLocation;

    setState(() {
      _services = parsedServices;
      _employees = parsedEmployees;
      _locations = parsedLocations;
      _selectedService = selectedServiceToApply;
      _selectedLocation = selectedLocationToApply;
      if (!preserveAvailability) {
        _selectedEmployee = null;
        _filteredEmployees = [];
        _selectedTimeSlot = null;
        _availableTimeSlots = [];
        _selectedExtrasQty.clear();
        _wantsServiceExtras = false;
      }
    });

    _applyEmployeesForCurrentSelection(
      preferredBarberId: _isNewBookingFlow ? null : incomingBarberId,
      preferredBarberName: _isNewBookingFlow ? null : incomingBarberName,
      showMessageIfAdjusted: false,
      preserveAvailability: preserveAvailability,
    );

    if (!_isNewBookingFlow && !preserveAvailability) {
      await _loadAvailabilityIfPossible(
        preserveSelectedTime: true,
        preferredTime: widget.initialTime,
      );
    }
  }

  Map<String, dynamic>? _matchCatalogItem(
    List<Map<String, dynamic>> items,
    Map<String, dynamic>? current, {
    required String labelKey,
  }) {
    if (current == null) return null;

    final currentId = _safeInt(current['id']);
    final currentLabel = current[labelKey]?.toString().trim();

    for (final item in items) {
      if (currentId != null && _safeInt(item['id']) == currentId) {
        return item;
      }

      if (currentLabel != null &&
          currentLabel.isNotEmpty &&
          item[labelKey]?.toString().trim() == currentLabel) {
        return item;
      }
    }

    return null;
  }

  Map<String, dynamic> _normalizeService(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final rawExtras = map['extras'] ??
        map['serviceExtras'] ??
        map['service_extras'] ??
        (map['raw'] is Map ? map['raw']['extras'] : null);
    final title = (map['name'] ?? map['title'] ?? '').toString().trim();

    return {
      'id': _safeInt(map['id']),
      'title': title,
      'price': _formatPrice(
        map['price'] ?? map['priceString'] ?? map['formattedPrice'],
      ),
      'priceValue': _safeDouble(map['price']) ?? 0,
      'image': HabitoBookingApi.extractServiceImageUrl(map),
      'placeholderImage': _servicePlaceholderImage(title),
      'duration': _safeInt(map['duration']) ?? 0,
      'extras': _normalizeExtras(rawExtras),
      'raw': map,
    };
  }

  List<Map<String, dynamic>> _normalizeExtras(dynamic extrasRaw) {
    if (extrasRaw is! List) return [];

    return extrasRaw
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return {
            'id': _safeInt(map['id']) ?? _safeInt(map['extraId']) ?? 0,
            'name': (map['name'] ?? '').toString().trim(),
            'description': (map['description'] ?? '').toString().trim(),
            'price': _safeDouble(map['price']) ?? 0,
            'duration': _safeInt(map['duration']) ?? 0,
            'maxQuantity': (_safeInt(map['maxQuantity']) ?? 1) < 1
                ? 1
                : (_safeInt(map['maxQuantity']) ?? 1),
            'serviceId': _safeInt(map['serviceId']),
            'status': (map['status'] ?? '').toString().trim(),
            'raw': map,
          };
        })
        .where((extra) =>
            (extra['id'] as int) > 0 &&
            (extra['name'] as String).trim().isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _normalizeEmployee(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);

    final firstName =
        (map['firstName'] ?? map['first_name'] ?? '').toString().trim();
    final lastName =
        (map['lastName'] ?? map['last_name'] ?? '').toString().trim();
    final fullNameFromParts = '$firstName $lastName'.trim();

    final fullName = fullNameFromParts.isNotEmpty
        ? fullNameFromParts
        : (map['fullName'] ?? map['name'] ?? map['displayName'] ?? '')
            .toString()
            .trim();

    return {
      'id': _safeInt(map['id']),
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'email': map['email']?.toString(),
      'phone': map['phone']?.toString(),
      'image': map['pictureThumbPath'] ??
          map['pictureFullPath'] ??
          map['picture'] ??
          map['image'] ??
          map['avatar'],
      'description': (map['description'] ?? map['bio'] ?? '').toString().trim(),
      'serviceIds': List<int>.from(map['serviceIds'] ?? []),
      'locationId': _safeInt(map['locationId']),
      'locationIds': List<int>.from(map['locationIds'] ?? []),
      'locations': List<dynamic>.from(map['locations'] ?? []),
      'raw': map,
    };
  }

  Map<String, dynamic> _normalizeLocation(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);

    return {
      'id': _safeInt(map['id']),
      'name': (map['name'] ?? '').toString().trim(),
      'address': (map['address'] ?? '').toString().trim(),
      'description': (map['description'] ?? '').toString().trim(),
      'phone': (map['phone'] ?? '').toString().trim(),
      'latitude': map['latitude'],
      'longitude': map['longitude'],
      'status': (map['status'] ?? '').toString().trim(),
      'raw': map,
    };
  }

  int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatPrice(dynamic value) {
    if (value == null) return '-';

    if (value is num) {
      return '\$${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '-';
    if (text.startsWith('\$')) return text;

    final parsed = double.tryParse(text);
    if (parsed != null) {
      return '\$${parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 2)}';
    }

    return text;
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
  }

  String _formatDurationLabel(int seconds) {
    if (seconds <= 0) return '0 min';

    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) {
      return hours == 1 ? '1 hora' : '$hours horas';
    }

    return '${hours}h ${minutes}min';
  }

  String? _resolveIncomingBarberName() {
    if (widget.selectedBarber != null) {
      final firstName = (widget.selectedBarber!['firstName'] ?? '').toString();
      final lastName = (widget.selectedBarber!['lastName'] ?? '').toString();
      final fullName = '$firstName $lastName'.trim();

      if (fullName.isNotEmpty) {
        return fullName;
      }

      final fallbackName = (widget.selectedBarber!['fullName'] ??
              widget.selectedBarber!['name'] ??
              '')
          .toString()
          .trim();

      if (fallbackName.isNotEmpty) {
        return fallbackName;
      }
    }

    return widget.initialBarber;
  }

  int? _resolveIncomingBarberId() {
    return _safeInt(widget.selectedBarber?['id']);
  }

  List<Map<String, dynamic>> _getEmployeesForSelection({
    required int? serviceId,
    required int? locationId,
  }) {
    return _employees.where((employee) {
      final serviceIds = List<int>.from(employee['serviceIds'] ?? []);
      final locationIds = List<int>.from(employee['locationIds'] ?? []);

      final matchesService = serviceId == null ||
          serviceIds.isEmpty ||
          serviceIds.contains(serviceId);

      final matchesLocation = locationId == null ||
          locationIds.isEmpty ||
          locationIds.contains(locationId);

      return matchesService && matchesLocation;
    }).toList();
  }

  List<Map<String, dynamic>> _currentServiceExtras() {
    if (_selectedService == null) return [];

    final directExtras = _selectedService!['extras'];
    if (directExtras is List) {
      final normalized = directExtras
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (normalized.isNotEmpty) return normalized;
    }

    final raw = _selectedService!['raw'];
    if (raw is Map) {
      return _normalizeExtras(
        raw['extras'] ?? raw['serviceExtras'] ?? raw['service_extras'],
      );
    }

    return [];
  }

  int _getExtraQty(int extraId) {
    return _selectedExtrasQty[extraId] ?? 0;
  }

  List<Map<String, dynamic>> _selectedExtrasForApi() {
    return _getSelectedExtrasDetailed()
        .map(
          (extra) => {
            'id': _safeInt(extra['id']) ?? 0,
            'quantity': _safeInt(extra['quantity']) ?? 1,
            'price': _safeDouble(extra['price']) ?? 0,
            'duration': _safeInt(extra['duration']) ?? 0,
            'name': (extra['name'] ?? '').toString(),
          },
        )
        .where((extra) => (extra['id'] as int) > 0)
        .toList();
  }

  void _changeExtraQty(Map<String, dynamic> extra, int delta) {
    final int extraId = _safeInt(extra['id']) ?? 0;
    if (extraId <= 0) return;

    final int maxQuantity = (_safeInt(extra['maxQuantity']) ?? 1).clamp(1, 999);
    final int current = _selectedExtrasQty[extraId] ?? 0;
    final int next = (current + delta).clamp(0, maxQuantity);

    setState(() {
      if (next <= 0) {
        _selectedExtrasQty.remove(extraId);
      } else {
        _selectedExtrasQty[extraId] = next;
        _wantsServiceExtras = true;
      }
      _selectedTimeSlot = null;
      _availableTimeSlots = [];
      _showAllTimeSlots = true;
    });

    _loadAvailabilityIfPossible(preserveSelectedTime: true);
  }

  List<Map<String, dynamic>> _getSelectedExtrasDetailed() {
    final extras = _currentServiceExtras();
    final List<Map<String, dynamic>> selected = [];

    for (final extra in extras) {
      final int extraId = _safeInt(extra['id']) ?? 0;
      final int qty = _selectedExtrasQty[extraId] ?? 0;

      if (extraId <= 0 || qty <= 0) continue;

      final double price = _safeDouble(extra['price']) ?? 0;
      final int duration = _safeInt(extra['duration']) ?? 0;

      selected.add({
        'id': extraId,
        'name': extra['name'],
        'description': extra['description'],
        'price': price,
        'duration': duration,
        'quantity': qty,
        'totalPrice': price * qty,
        'totalDuration': duration * qty,
      });
    }

    return selected;
  }

  double _getBaseServicePrice() {
    return _safeDouble(_selectedService?['priceValue']) ?? 0;
  }

  int _getBaseServiceDuration() {
    return _safeInt(_selectedService?['duration']) ?? 0;
  }

  double _getSelectedExtrasPriceTotal() {
    return _getSelectedExtrasDetailed().fold<double>(
      0,
      (sum, extra) => sum + (_safeDouble(extra['totalPrice']) ?? 0),
    );
  }

  int _getSelectedExtrasDurationTotal() {
    return _getSelectedExtrasDetailed().fold<int>(
      0,
      (sum, extra) => sum + (_safeInt(extra['totalDuration']) ?? 0),
    );
  }

  double _getGrandTotalPrice() {
    return _getBaseServicePrice() + _getSelectedExtrasPriceTotal();
  }

  PointsRedemptionState _resolvePointsState(
    AuthProvider auth, [
    PointsProvider? pointsProvider,
  ]) {
    return PointsCalculator.resolveState(
      user: auth.user,
      summary: pointsProvider?.summary,
      reservedPoints: pointsProvider?.reservedPoints ?? 0,
    );
  }

  double _bookingPointsToUse(
    AuthProvider auth,
    double total, [
    PointsProvider? pointsProvider,
  ]) {
    return PointsCalculator.calculate(
      state: _resolvePointsState(auth, pointsProvider),
      context: PointsRedemptionContext.booking,
      total: total,
    ).pointsToUse;
  }

  double _bookingPointsDiscount(
    AuthProvider auth,
    double total, [
    PointsProvider? pointsProvider,
  ]) {
    return PointsCalculator.calculate(
      state: _resolvePointsState(auth, pointsProvider),
      context: PointsRedemptionContext.booking,
      total: total,
    ).discount;
  }

  String _bookingPointsHelperMessage(
    PointsRedemptionState pointsState,
    double totalPrice,
  ) {
    final pointsResult = PointsCalculator.calculate(
      state: pointsState,
      context: PointsRedemptionContext.booking,
      total: totalPrice,
    );
    if (pointsResult.total >= 0) {
      return pointsResult.helperMessage();
    }
    final pointsToUse = pointsResult.pointsToUse;

    if (totalPrice <= 0) {
      return 'Selecciona un servicio para calcular cuántos ${pointsState.label.toLowerCase()} puedes usar en esta reserva.';
    }

    if (pointsState.balance <= 0) {
      return 'Aún no tienes ${pointsState.label.toLowerCase()} disponibles para aplicar en esta reserva.';
    }

    if (pointsToUse <= 0) {
      if (pointsState.balance < pointsState.minPoints) {
        final minPointsLabel =
            pointsState.minPoints == pointsState.minPoints.roundToDouble()
                ? pointsState.minPoints.toStringAsFixed(0)
                : pointsState.minPoints.toStringAsFixed(2);
        return 'Necesitas al menos $minPointsLabel ${pointsState.label.toLowerCase()} para canjear en reservas.';
      }

      return 'Tus ${pointsState.label.toLowerCase()} actuales no alcanzan para generar descuento en esta reserva.';
    }

    return 'Puedes combinar tu método de pago con ${pointsState.label.toLowerCase()} para reducir el total de esta reserva.';
  }

  int _getGrandTotalDuration() {
    return _getBaseServiceDuration() + _getSelectedExtrasDurationTotal();
  }

  void _applyEmployeesForCurrentSelection({
    int? preferredBarberId,
    String? preferredBarberName,
    bool showMessageIfAdjusted = false,
    bool preserveAvailability = false,
  }) {
    final serviceId = _safeInt(_selectedService?['id']);
    final locationId = _safeInt(_selectedLocation?['id']);

    final filtered = _getEmployeesForSelection(
      serviceId: serviceId,
      locationId: locationId,
    );

    Map<String, dynamic>? nextSelected;

    final currentSelectedId = _safeInt(_selectedEmployee?['id']);
    if (currentSelectedId != null) {
      for (final employee in filtered) {
        if (_safeInt(employee['id']) == currentSelectedId) {
          nextSelected = employee;
          break;
        }
      }
    }

    if (nextSelected == null && preferredBarberId != null) {
      for (final employee in filtered) {
        if (_safeInt(employee['id']) == preferredBarberId) {
          nextSelected = employee;
          break;
        }
      }
    }

    if (nextSelected == null &&
        preferredBarberName != null &&
        preferredBarberName.isNotEmpty) {
      for (final employee in filtered) {
        if ((employee['fullName'] ?? '').toString().trim() ==
            preferredBarberName.trim()) {
          nextSelected = employee;
          break;
        }
      }
    }

    if (nextSelected == null && filtered.length == 1) {
      nextSelected = filtered.first;
    }

    final hadSelectedEmployee = _selectedEmployee != null;

    final shouldShowAdjustedMessage = showMessageIfAdjusted &&
        hadSelectedEmployee &&
        nextSelected == null &&
        filtered.isNotEmpty;
    final shouldClearAvailability =
        !preserveAvailability || (hadSelectedEmployee && nextSelected == null);

    setState(() {
      _filteredEmployees = filtered;
      _selectedEmployee = nextSelected;
      if (shouldClearAvailability) {
        _selectedTimeSlot = null;
        _availableTimeSlots = [];
        _showAllTimeSlots = true;
      }
    });

    if (shouldShowAdjustedMessage) {
      _showMessage(
        'El barbero seleccionado no trabaja con ese servicio o sucursal.',
      );
    }
  }

  Future<void> _onServiceChanged(String value) async {
    final selected = _services.firstWhere(
      (service) => service['title'] == value,
    );

    setState(() {
      _selectedService = selected;
      _selectedTimeSlot = null;
      _availableTimeSlots = [];
      _selectedExtrasQty.clear();
      _wantsServiceExtras = false;
      _showAllTimeSlots = true;
    });

    _applyEmployeesForCurrentSelection(
      showMessageIfAdjusted: true,
    );

    await _loadAvailabilityIfPossible();
  }

  void _refreshFormState() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canLoadAvailability {
    return _selectedService != null &&
        _selectedEmployee != null &&
        _selectedLocation != null &&
        _selectedDate != null;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isValidEmail(String value) {
    return FormValidators.isValidEmail(value);
  }

  bool _isValidPhone(String value) {
    return FormValidators.isValidPhone(value);
  }

  String get _effectiveIdentificationType {
    return _contactType == 'business' ? 'ruc' : _identificationType;
  }

  List<String> get _bookingIdentificationTypes {
    if (_contactType == 'business') return const ['ruc'];
    return const ['cedula', 'ruc', 'pasaporte'];
  }

  String get _bookingDocumentLabel {
    final label = kIdentificationTypeLabels[_effectiveIdentificationType] ??
        _effectiveIdentificationType;
    return 'Número de $label';
  }

  bool get _isCustomerFiscalDataValid {
    if (_contactType == 'business' &&
        FormValidators.requiredMaxLength(
              _businessNameController.text,
              field: 'la razón social',
            ) !=
            null) {
      return false;
    }

    return _validateBookingIdentificationNumber(
              _taxNumberController.text,
            ) ==
            null &&
        _cityController.text.trim().isNotEmpty &&
        FormValidators.requiredMaxLength(
              _addressController.text,
              field: 'la dirección principal',
            ) ==
            null;
  }

  String _normalizeIdentificationType(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return _bookingIdentificationTypes.contains(normalized)
        ? normalized
        : 'cedula';
  }

  String? _validateBookingIdentificationNumber(String? value) {
    return EcuadorIdValidator.validate(
      identificationType: _effectiveIdentificationType,
      value: value,
      emptyMessage: 'Ingresa tu $_bookingDocumentLabel.',
    );
  }

  String _composeGivenNames(String firstName, String middleName) {
    return '${firstName.trim()} ${middleName.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeStatusLabel(String? status) {
    final value = (status ?? '').trim().toLowerCase();

    switch (value) {
      case 'approved':
        return 'Aprobada';
      case 'pending':
        return 'Pendiente';
      case 'rejected':
        return 'Rechazada';
      case 'canceled':
      case 'cancelled':
        return 'Cancelada';
      case 'confirmed':
        return 'Confirmada';
      case 'paid':
        return 'Pagado';
      case 'unpaid':
        return 'No pagado';
      default:
        return status?.trim().isNotEmpty == true ? status!.trim() : 'Pendiente';
    }
  }

  String _formatApiDateStart(
    DateTime date, {
    int slotStepMinutes = 5,
  }) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    if (_isToday(date)) {
      final now = _roundUpDateTimeToStep(
        DateTime.now(),
        stepMinutes: slotStepMinutes,
      );
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      const second = '00';
      return '$year-$month-$day $hour:$minute:$second';
    }

    return '$year-$month-$day 00:00:00';
  }

  Future<void> _loadAvailabilityIfPossible({
    bool preserveSelectedTime = false,
    String? preferredTime,
    Map<String, dynamic>? serviceOverride,
    Map<String, dynamic>? employeeOverride,
    Map<String, dynamic>? locationOverride,
    DateTime? dateOverride,
  }) async {
    final service = serviceOverride ?? _selectedService;
    final employee = employeeOverride ?? _selectedEmployee;
    final location = locationOverride ?? _selectedLocation;
    final selectedDate = dateOverride ?? _selectedDate;

    if (service == null ||
        employee == null ||
        location == null ||
        selectedDate == null) {
      _availabilityRequestId++;
      if (!mounted) return;
      setState(() {
        _availableTimeSlots = [];
        _availabilityNoticeMessage = null;
        _selectedTimeSlot = null;
        _showAllTimeSlots = true;
        _isLoadingAvailability = false;
      });
      return;
    }

    final serviceId = _safeInt(service['id']);
    final employeeId = _safeInt(employee['id']);
    final locationId = _safeInt(location['id']);

    if (serviceId == null || employeeId == null || locationId == null) {
      _availabilityRequestId++;
      if (!mounted) return;
      setState(() {
        _availableTimeSlots = [];
        _availabilityNoticeMessage = null;
        _selectedTimeSlot = null;
        _showAllTimeSlots = true;
        _isLoadingAvailability = false;
      });
      return;
    }

    final requestId = ++_availabilityRequestId;
    final extras = _selectedExtrasForApi();
    final requestedDurationSeconds = _resolveRequestedDurationSeconds(
      service,
      extras,
    );
    final slotStepMinutes =
        _preferredSlotStepMinutes(requestedDurationSeconds) ?? 5;
    final candidateTime = preferredTime ?? _selectedTimeSlot;

    try {
      setState(() {
        _isLoadingAvailability = true;
        _availabilityNoticeMessage = null;
        if (!preserveSelectedTime) {
          _selectedTimeSlot = null;
          _showAllTimeSlots = true;
        }
      });

      final startDateTime = _formatApiDateStart(
        selectedDate,
        slotStepMinutes: slotStepMinutes,
      );
      final endDateTime = '${_formatApiDate(selectedDate)} 23:59:59';

      final availability = await HabitoBookingApi.getAvailability(
        serviceId: serviceId,
        employeeId: employeeId,
        locationId: locationId,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        extras: extras,
      );

      if (!mounted || requestId != _availabilityRequestId) return;

      final cutoff = _extractMinimumBookingCutoff(availability);
      final noticeLabel = _extractMinimumBookingNoticeLabel(availability);
      final rawExtractedSlots = _extractAvailableSlots(
        availability,
        selectedDate: selectedDate,
      );
      final extractedSlots = _filterSlotsByMinimumNotice(
        rawExtractedSlots,
        selectedDate: selectedDate,
        cutoff: cutoff,
      );
      final displaySlots = _filterSlotsForDisplay(
        extractedSlots,
        durationSeconds: requestedDurationSeconds,
        preferredTime: candidateTime,
      );
      final filteredByNotice =
          rawExtractedSlots.length != extractedSlots.length;
      final noticeMessage = cutoff != null &&
              (filteredByNotice || _isSameCalendarDay(selectedDate, cutoff))
          ? 'Para este servicio, los horarios deben reservarse con al menos ${noticeLabel ?? 'tiempo de anticipacion'}.'
          : null;

      String? nextSelectedTime;

      if (candidateTime != null && displaySlots.contains(candidateTime)) {
        nextSelectedTime = candidateTime;
      }

      if (!mounted || requestId != _availabilityRequestId) return;
      setState(() {
        _availableTimeSlots = displaySlots;
        _availabilityNoticeMessage = noticeMessage;
        _selectedTimeSlot = nextSelectedTime;
        _showAllTimeSlots = nextSelectedTime == null;
      });
    } catch (e) {
      if (!mounted || requestId != _availabilityRequestId) return;
      setState(() {
        _availableTimeSlots = [];
        _availabilityNoticeMessage = null;
        _selectedTimeSlot = null;
        _showAllTimeSlots = true;
      });
      _showMessage(_friendlyAvailabilityError(e));
    } finally {
      if (mounted && requestId == _availabilityRequestId) {
        setState(() {
          _isLoadingAvailability = false;
        });
      }
    }
  }

  List<String> _extractAvailableSlots(
    dynamic data, {
    required DateTime selectedDate,
  }) {
    final slots = <String>[];

    if (data is! Map<String, dynamic>) {
      return slots;
    }

    final selectedDateKey = _formatApiDate(selectedDate);
    final slotsNode = _findSlotsNode(data);

    void collectSlots(dynamic node) {
      if (node == null) return;

      if (node is String) {
        final time = _normalizeSlotTime(node, selectedDateKey: selectedDateKey);
        if (time != null) slots.add(time);
        return;
      }

      if (node is List) {
        for (final item in node) {
          collectSlots(item);
        }
        return;
      }

      if (node is Map) {
        final map = Map<dynamic, dynamic>.from(node);

        if (map.containsKey(selectedDateKey)) {
          collectSlots(map[selectedDateKey]);
          return;
        }

        for (final entry in map.entries) {
          final keyTime = _normalizeSlotTime(
            entry.key.toString(),
            selectedDateKey: selectedDateKey,
          );

          if (keyTime != null) {
            slots.add(keyTime);
          } else {
            collectSlots(entry.value);
          }
        }
      }
    }

    collectSlots(slotsNode);

    final unique = slots.toSet().toList()..sort();
    return unique;
  }

  List<String> _filterSlotsByMinimumNotice(
    List<String> slots, {
    required DateTime selectedDate,
    DateTime? cutoff,
  }) {
    if (cutoff == null || slots.isEmpty) return slots;

    return slots.where((slot) {
      final slotDateTime = _buildAppointmentDateTime(selectedDate, slot);
      return !slotDateTime.isBefore(cutoff);
    }).toList();
  }

  int _resolveRequestedDurationSeconds(
    Map<String, dynamic> service,
    List<Map<String, dynamic>> extras,
  ) {
    final baseDuration = _safeInt(service['duration']) ?? 0;
    final extrasDuration = extras.fold<int>(0, (sum, extra) {
      final duration = _safeInt(extra['duration']) ?? 0;
      final quantity = _safeInt(extra['quantity']) ?? 1;
      return sum + (duration * quantity);
    });

    return baseDuration + extrasDuration;
  }

  int? _preferredSlotStepMinutes(int durationSeconds) {
    final totalMinutes = (durationSeconds / 60).round();

    if (totalMinutes <= 0) return null;

    for (final step in const [30, 15, 10, 5]) {
      if (totalMinutes % step == 0) {
        return step;
      }
    }

    return totalMinutes >= 60 ? 15 : 5;
  }

  DateTime _roundUpDateTimeToStep(
    DateTime value, {
    required int stepMinutes,
  }) {
    final sanitized = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );

    if (stepMinutes <= 1) return sanitized;

    final remainder = sanitized.minute % stepMinutes;
    if (remainder == 0 && value.second == 0) {
      return sanitized;
    }

    final minutesToAdd = remainder == 0 ? stepMinutes : stepMinutes - remainder;
    return sanitized.add(Duration(minutes: minutesToAdd));
  }

  List<String> _filterSlotsForDisplay(
    List<String> slots, {
    required int durationSeconds,
    String? preferredTime,
  }) {
    final stepMinutes = _preferredSlotStepMinutes(durationSeconds);
    if (stepMinutes == null || slots.length <= 1) return slots;

    final filtered = slots.where((slot) {
      if (preferredTime != null && slot == preferredTime) {
        return true;
      }

      return _isSlotAlignedToStep(slot, stepMinutes);
    }).toList();

    if (filtered.isEmpty) {
      return slots;
    }

    return filtered.toSet().toList()..sort();
  }

  bool _isSlotAlignedToStep(String slot, int stepMinutes) {
    final parts = slot.split(':');
    if (parts.length < 2) return false;

    final minute = int.tryParse(parts[1]) ?? 0;
    return minute % stepMinutes == 0;
  }

  DateTime? _extractMinimumBookingCutoff(Map<String, dynamic> availability) {
    final meta = _findHabitoAvailabilityMeta(availability);
    final rawCutoff = meta?['minimum_booking_cutoff']?.toString().trim();

    if (rawCutoff == null || rawCutoff.isEmpty) return null;

    return DateTime.tryParse(rawCutoff.replaceFirst(' ', 'T'));
  }

  String? _extractMinimumBookingNoticeLabel(
    Map<String, dynamic> availability,
  ) {
    final meta = _findHabitoAvailabilityMeta(availability);
    final label = meta?['minimum_booking_notice_label']?.toString().trim();
    return label == null || label.isEmpty ? null : label;
  }

  Map<String, dynamic>? _findHabitoAvailabilityMeta(dynamic node) {
    if (node is! Map) return null;

    final map = Map<dynamic, dynamic>.from(node);
    final habito = map['habito'];

    if (habito is Map) {
      return Map<String, dynamic>.from(habito);
    }

    for (final key in const ['data', 'availability', 'result']) {
      if (map.containsKey(key)) {
        final found = _findHabitoAvailabilityMeta(map[key]);
        if (found != null) return found;
      }
    }

    return null;
  }

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  dynamic _findSlotsNode(dynamic data) {
    if (data is Map) {
      final map = Map<dynamic, dynamic>.from(data);
      if (map.containsKey('slots')) return map['slots'];

      for (final key in const ['data', 'availability', 'result']) {
        if (map.containsKey(key)) {
          final found = _findSlotsNode(map[key]);
          if (found != null) return found;
        }
      }
    }

    return null;
  }

  String? _normalizeSlotTime(
    String value, {
    required String selectedDateKey,
  }) {
    final text = value.trim();

    final directMatch =
        RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (directMatch != null) {
      return '${directMatch.group(1)}:${directMatch.group(2)}';
    }

    if (text.startsWith(selectedDateKey)) {
      final dateTimeMatch =
          RegExp(r'^\d{4}-\d{2}-\d{2}[ T](\d{2}):(\d{2})').firstMatch(text);
      if (dateTimeMatch != null) {
        return '${dateTimeMatch.group(1)}:${dateTimeMatch.group(2)}';
      }
    }

    return null;
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatApiDateTime(DateTime date, String time) {
    return '${_formatApiDate(date)} $time';
  }

  Map<String, String> _splitFullName(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return {
        'firstName': '',
        'middleName': '',
        'lastName': '',
      };
    }

    if (parts.length == 1) {
      return {
        'firstName': parts.first,
        'middleName': '',
        'lastName': '',
      };
    }

    if (parts.length == 2) {
      return {
        'firstName': parts.first,
        'middleName': '',
        'lastName': parts.last,
      };
    }

    return {
      'firstName': parts.first,
      'middleName': parts.sublist(1, parts.length - 1).join(' '),
      'lastName': parts.last,
    };
  }

  DateTime _buildAppointmentDateTime(DateTime date, String time) {
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  String _sanitizeForIcs(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;')
        .replaceAll('\n', r'\n');
  }

  Future<void> _openLocation({
    String? address,
    double? latitude,
    double? longitude,
    String? branchName,
    String? description,
  }) async {
    final opened = await LocationLauncherService.openMap(
      address: address,
      latitude: latitude,
      longitude: longitude,
      branchName: branchName,
      description: description,
    );

    if (!opened) {
      _showMessage('No se pudo abrir la ubicación');
    }
  }

  Future<void> _shareAppointmentOnWhatsApp({
    required String reservationCode,
    required String serviceName,
    required String barberName,
    required String branch,
    required String dateLabel,
    required String time,
  }) async {
    final text = Uri.encodeComponent(
      '📅 Mi cita en HÁBITO\n\n'
      'Reserva: #$reservationCode\n'
      'Servicio: $serviceName\n'
      'Barbero: $barberName\n'
      'Sucursal: $branch\n'
      'Fecha: $dateLabel\n'
      'Hora: $time',
    );

    final uri = Uri.parse('https://wa.me/?text=$text');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(
        '📅 Mi cita en HÁBITO\n\n'
        'Reserva: #$reservationCode\n'
        'Servicio: $serviceName\n'
        'Barbero: $barberName\n'
        'Sucursal: $branch\n'
        'Fecha: $dateLabel\n'
        'Hora: $time',
      );
    }
  }

  Future<void> _addToCalendar({
    required String reservationCode,
    required String serviceName,
    required String barberName,
    required String branch,
    required String dateLabel,
    required String time,
    String? address,
    int durationSeconds = 3600,
  }) async {
    try {
      final appointmentDate = _selectedDate;
      if (appointmentDate == null) {
        _showMessage('Selecciona la fecha de la cita.');
        return;
      }

      final start = _buildAppointmentDateTime(appointmentDate, time);
      final end = start.add(Duration(seconds: durationSeconds));

      String formatUtc(DateTime dt) {
        final utc = dt.toUtc();
        String two(int n) => n.toString().padLeft(2, '0');
        return '${utc.year}${two(utc.month)}${two(utc.day)}T'
            '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
      }

      final summary = _sanitizeForIcs('Cita HÁBITO - $serviceName');
      final description = _sanitizeForIcs(
        'Reserva: #$reservationCode\n'
        'Servicio: $serviceName\n'
        'Barbero: $barberName\n'
        'Sucursal: $branch\n'
        'Fecha: $dateLabel\n'
        'Hora: $time',
      );
      final location = _sanitizeForIcs(
        address?.trim().isNotEmpty == true ? address! : branch,
      );

      final icsContent = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//HABITO//BOOKING//ES
CALSCALE:GREGORIAN
BEGIN:VEVENT
UID:habito-$reservationCode@habito.app
DTSTAMP:${formatUtc(DateTime.now())}
DTSTART:${formatUtc(start)}
DTEND:${formatUtc(end)}
SUMMARY:$summary
DESCRIPTION:$description
LOCATION:$location
END:VEVENT
END:VCALENDAR
''';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/habito_cita_$reservationCode.ics');
      await file.writeAsString(icsContent, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Agrega tu cita al calendario',
      );
    } catch (_) {
      _showMessage('No se pudo generar el archivo de calendario');
    }
  }

  Future<void> _closeSuccessAndGoToMyAppointments(
    BuildContext sheetContext,
  ) async {
    Navigator.of(sheetContext).pop();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.main),
        builder: (_) => const MainNavigationPage(initialIndex: 2),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_refreshFormState);
    _middleNameController.removeListener(_refreshFormState);
    _lastNameController.removeListener(_refreshFormState);
    _phoneController.removeListener(_refreshFormState);
    _emailController.removeListener(_refreshFormState);
    _businessNameController.removeListener(_refreshFormState);
    _taxNumberController.removeListener(_refreshFormState);
    _cityController.removeListener(_refreshFormState);
    _addressController.removeListener(_refreshFormState);

    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _taxNumberController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday, ${date.day} de $month';
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null && !_selectedDate!.isBefore(now)
          ? _selectedDate!
          : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.secondary),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null;
        _availableTimeSlots = [];
        _showAllTimeSlots = true;
      });

      await _loadAvailabilityIfPossible(
        dateOverride: picked,
      );
    }
  }

  Future<void> _confirmBooking() async {
    FocusScope.of(context).unfocus();

    if (_firstNameController.text.trim().isEmpty) {
      _showMessage('Ingresa el nombre de pila');
      return;
    }

    if (_lastNameController.text.trim().isEmpty) {
      _showMessage('Ingresa el apellido');
      return;
    }

    if (!_isValidPhone(_phoneController.text)) {
      _showMessage('Ingresa un numero de celular ecuatoriano valido');
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showMessage('Ingresa un correo electrónico válido');
      return;
    }

    if (_contactType == 'business') {
      final businessNameError = FormValidators.requiredMaxLength(
        _businessNameController.text,
        field: 'la razón social',
      );
      if (businessNameError != null) {
        _showMessage(businessNameError);
        return;
      }
    }

    final taxNumberError = _validateBookingIdentificationNumber(
      _taxNumberController.text,
    );
    if (taxNumberError != null) {
      _showMessage(taxNumberError);
      return;
    }

    if (_cityController.text.trim().isEmpty) {
      _showMessage('Ingresa el cantón o ciudad');
      return;
    }

    final addressError = FormValidators.requiredMaxLength(
      _addressController.text,
      field: 'la dirección principal',
    );
    if (addressError != null) {
      _showMessage(addressError);
      return;
    }

    if (!_isFormValid) {
      _showMessage(
        'Completa servicio, sucursal, barbero, fecha, hora y todos tus datos fiscales para continuar.',
      );
      return;
    }

    final service = _selectedService;
    final employee = _selectedEmployee;
    final location = _selectedLocation;
    final selectedTime = _selectedTimeSlot;
    final selectedDate = _selectedDate;

    if (service == null ||
        employee == null ||
        location == null ||
        selectedTime == null ||
        selectedDate == null) {
      _showMessage(
        'Selecciona una fecha y un horario disponible para continuar con tu reserva.',
      );
      return;
    }

    if (_isEditing) {
      await _rescheduleBooking(selectedTime);
      return;
    }

    final serviceId = _safeInt(service['id']);
    final employeeId = _safeInt(employee['id']);
    final locationId = _safeInt(location['id']);

    if (serviceId == null || employeeId == null || locationId == null) {
      _showMessage(
        'No pudimos preparar la reserva. Vuelve a elegir servicio, sucursal y barbero.',
      );
      return;
    }

    final selectedExtras = _selectedExtrasForApi();
    final totalDuration = _getGrandTotalDuration();
    final paymentMethods = _enabledPaymentMethods(context.read<ShopProvider>());
    final selectedPaymentMethod = _selectedPaymentMethod(paymentMethods);

    if (!selectedPaymentMethod.canCreateManualOrder) {
      _showMessage(
        '${selectedPaymentMethod.title} estará disponible pronto para reservas desde la app.',
      );
      return;
    }

    String? pointsReservationId;
    PointsProvider? pointsProviderForReservation;

    try {
      final authProvider = context.read<AuthProvider>();
      final pointsProvider = context.read<PointsProvider>();
      pointsProviderForReservation = pointsProvider;

      final totalPrice = _getGrandTotalPrice();
      var redeemPoints = 0.0;
      var redeemDiscount = 0.0;
      var birthdayBonusPoints = 0.0;
      var birthdayBonusDiscount = 0.0;
      var birthdayVerificationNotice = '';

      setState(() {
        _isSubmittingBooking = true;
      });

      if (_useBirthdayBonus) {
        await pointsProvider.refresh();
        if (!mounted) return;

        final birthdayQuote =
            await pointsProvider.quoteBirthdayBookingPromotion(
          amount: totalPrice,
        );

        if (!birthdayQuote.canRedeem) {
          setState(() {
            _useBirthdayBonus = false;
          });
          _showMessage(
            birthdayQuote.message.isNotEmpty
                ? birthdayQuote.message
                : 'Tu bono de cumpleaños ya no está disponible.',
          );
          return;
        }

        birthdayBonusPoints = birthdayQuote.points;
        birthdayBonusDiscount = birthdayQuote.discount;
        birthdayVerificationNotice = birthdayQuote.verificationNotice.isNotEmpty
            ? birthdayQuote.verificationNotice
            : (pointsProvider.birthdayPromotion?.verificationNotice ?? '');
      }

      if (_usePoints && !_useBirthdayBonus) {
        await pointsProvider.refresh();
        if (!mounted) return;

        final quote = await pointsProvider.quoteRedemption(
          context: 'booking',
          amount: totalPrice,
        );

        if (!quote.canRedeem) {
          setState(() {
            _usePoints = false;
          });
          _showMessage(
            quote.message.isNotEmpty
                ? quote.message
                : 'Tus puntos ya no están disponibles para esta reserva. Revisa tu saldo e intenta nuevamente.',
          );
          return;
        }

        redeemPoints = quote.points;
        redeemDiscount = quote.discount;

        pointsReservationId =
            'booking-${DateTime.now().microsecondsSinceEpoch}';
        final reserved = pointsProvider.reserveRedemption(
          id: pointsReservationId,
          context: 'booking',
          points: redeemPoints,
        );
        if (!reserved) {
          setState(() {
            _usePoints = false;
          });
          _showMessage(
            'Ya hay un canje de puntos en proceso. Espera unos segundos e intenta nuevamente.',
          );
          return;
        }
      }

      if (_useBirthdayBonus && birthdayBonusPoints <= 0) {
        _showMessage(
          'Tu bono de cumpleaños ya no está disponible. Revisa tus puntos e intenta nuevamente.',
        );
        return;
      }

      if (_usePoints && !_useBirthdayBonus && redeemPoints <= 0) {
        _showMessage(
          'Tus puntos ya no están disponibles para esta reserva. Revisa tu saldo e intenta nuevamente.',
        );
        return;
      }

      final token = authProvider.token;
      final user = authProvider.user;

      final bool isLoggedIn = authProvider.isLoggedIn;
      final int? ameliaCustomerId = user?.ameliaCustomerId;
      final String firstNameToSend = _composeGivenNames(
        _firstNameController.text,
        _middleNameController.text,
      );
      final String lastNameToSend = _lastNameController.text.trim();
      final String emailToSend = _emailController.text.trim();
      final String phoneToSend = _phoneController.text.trim();

      if (isLoggedIn && (token == null || token.trim().isEmpty)) {
        throw Exception(
          'La sesión está activa pero no se encontró el token de autenticación.',
        );
      }

      final customerPayload = <String, dynamic>{
        'first_name': firstNameToSend,
        'middle_name': _middleNameController.text.trim(),
        'last_name': lastNameToSend,
        'email': emailToSend,
        'phone': phoneToSend,
        'country_phone_iso': 'ec',
        'contact_type': _contactType.trim(),
        'identification_type': _effectiveIdentificationType,
        'tax_number': _taxNumberController.text.trim(),
        'province': _province.trim(),
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        if (_contactType == 'business' &&
            _businessNameController.text.trim().isNotEmpty)
          'business_name': _businessNameController.text.trim(),
      };

      final response = await HabitoBookingApi.createBooking(
        firstName: firstNameToSend,
        lastName: lastNameToSend,
        email: emailToSend,
        phone: phoneToSend,
        customer: customerPayload,
        ameliaCustomerId: (ameliaCustomerId != null && ameliaCustomerId > 0)
            ? ameliaCustomerId
            : null,
        serviceId: serviceId,
        providerId: employeeId,
        locationId: locationId,
        bookingStart: _formatApiDateTime(selectedDate, selectedTime),
        duration: totalDuration > 0 ? totalDuration : 3600,
        authToken: (token != null && token.trim().isNotEmpty) ? token : null,
        extras: selectedExtras,
        paymentMethod: selectedPaymentMethod,
        redeemPoints: redeemPoints,
        redeemAmount: redeemDiscount,
        birthdayBonusPoints: birthdayBonusPoints,
        birthdayBonusAmount: birthdayBonusDiscount,
      );

      final int? appointmentId = _safeInt(response['appointment_id']);
      final int? bookingId = _safeInt(response['booking_id']);
      final int? reservationCodeValue =
          appointmentId != null && appointmentId > 0
              ? appointmentId
              : bookingId;

      if (reservationCodeValue == null || reservationCodeValue <= 0) {
        throw Exception(
          'La reserva se creó, pero no pudimos confirmar el código de la cita. Revisa tus citas o intenta actualizar.',
        );
      }

      final String backendStatus = (response['status'] ?? 'pending').toString();
      final String backendServiceName =
          (response['service_name'] ?? service['title'] ?? '').toString();
      final String backendLocationName =
          (response['location_name'] ?? location['name'] ?? '').toString();

      unawaited(
        AnalyticsService.logBookingCreated(
          serviceId: serviceId,
          employeeId: employeeId,
          locationId: locationId,
          paymentMethod: selectedPaymentMethod.id,
          total: _getGrandTotalPrice(),
          redeemedPoints: redeemPoints,
          birthdayPoints: birthdayBonusPoints,
        ),
      );

      if (redeemPoints > 0 || birthdayBonusPoints > 0) {
        unawaited(authProvider.refreshProfile());
        unawaited(pointsProvider.refresh());
      }

      if (!mounted) return;

      _showSuccessSheet(
        serviceName: backendServiceName,
        locationName: backendLocationName,
        barberName: (response['provider_name'] ?? employee['fullName'] ?? '')
            .toString(),
        dateLabel: _formatDate(selectedDate),
        time: selectedTime,
        reservationCode: reservationCodeValue.toString(),
        statusLabel: _normalizeStatusLabel(backendStatus),
        paymentStatus: response['payment_status']?.toString(),
        paymentMethodTitle: response['payment_title']?.toString() ??
            selectedPaymentMethod.title,
        locationAddress:
            (response['location_address'] ?? location['address'])?.toString(),
        locationDescription:
            (response['location_description'] ?? location['description'])
                ?.toString(),
        locationLatitude: _safeDouble(
          response['location_latitude'] ?? location['latitude'],
        ),
        locationLongitude: _safeDouble(
          response['location_longitude'] ?? location['longitude'],
        ),
        durationSeconds: totalDuration > 0 ? totalDuration : 3600,
        birthdayVerificationNotice:
            birthdayBonusPoints > 0 ? birthdayVerificationNotice : null,
      );
    } catch (e) {
      unawaited(
        AnalyticsService.logFailure(
          'booking_create',
          error: e,
        ),
      );
      if (!mounted) return;
      _showMessage('No se pudo crear la reserva: ${_friendlyBookingError(e)}');
    } finally {
      if (pointsReservationId != null) {
        pointsProviderForReservation?.releaseReservation(pointsReservationId);
      }
      if (mounted) {
        setState(() {
          _isSubmittingBooking = false;
        });
      }
    }
  }

  Future<void> _rescheduleBooking(String selectedTime) async {
    final appointmentId = int.tryParse(widget.appointmentId ?? '');
    final selectedDate = _selectedDate;

    if (appointmentId == null || appointmentId <= 0) {
      _showMessage('No pudimos identificar la cita que deseas reagendar.');
      return;
    }

    if (selectedDate == null) {
      _showMessage('Selecciona la nueva fecha de tu cita.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token?.trim();

    if (!authProvider.isLoggedIn || token == null || token.isEmpty) {
      _showMessage('Inicia sesión para reagendar tu cita.');
      return;
    }

    try {
      setState(() {
        _isSubmittingBooking = true;
      });

      await HabitoBookingApi.rescheduleAppointment(
        appointmentId: appointmentId,
        newBookingStart: _formatApiDateTime(selectedDate, selectedTime),
        authToken: token,
      );

      if (!mounted) return;

      _showMessage('Tu cita fue reagendada correctamente.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyRescheduleError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingBooking = false;
        });
      }
    }
  }

  String _cleanBookingErrorMessage(Object error) {
    var message = error.toString().trim();

    if (message.startsWith('Exception:')) {
      message = message.substring('Exception:'.length).trim();
    }

    return message;
  }

  bool _containsAny(String source, List<String> fragments) {
    for (final fragment in fragments) {
      if (source.contains(fragment)) {
        return true;
      }
    }
    return false;
  }

  String _friendlyAvailabilityError(Object error) {
    final message = _cleanBookingErrorMessage(error);
    final lower = message.toLowerCase();

    if (message.isEmpty) {
      return 'No pudimos actualizar los horarios disponibles. Intenta nuevamente en unos segundos.';
    }

    if (_containsAny(lower, ['sesi', 'token', '401'])) {
      return 'Tu sesión venció. Inicia sesión nuevamente para consultar horarios.';
    }

    if (_containsAny(lower, [
      'anticip',
      'notice_required',
      'minimum notice',
      'booking_notice',
    ])) {
      return 'Por ahora no hay horarios que cumplan con el tiempo mínimo de anticipación. Elige una hora más adelante.';
    }

    if (_containsAny(lower, [
      'timeout',
      'future not completed',
      'socketexception',
      'clientexception',
      'connection',
      'conectar',
    ])) {
      return 'No pudimos actualizar los horarios a tiempo. Revisa tu conexión e intenta nuevamente.';
    }

    if (_containsAny(lower, [
      'slot',
      'disponib',
      'ocup',
      'already',
      'unavailable',
    ])) {
      return 'No pudimos confirmar esos horarios. Vuelve a consultar la disponibilidad.';
    }

    return 'No pudimos cargar la disponibilidad. Intenta nuevamente.';
  }

  String _friendlyBookingError(Object error) {
    final message = _cleanBookingErrorMessage(error);
    final lower = message.toLowerCase();

    if (message.isEmpty) {
      return 'inténtalo nuevamente en unos segundos.';
    }

    if (_containsAny(lower, ['sesi', 'token', '401'])) {
      return 'Tu sesión venció. Inicia sesión nuevamente para continuar.';
    }

    if (_containsAny(lower, ['no tienes permisos', '403', 'permisos'])) {
      return 'No pudimos validar tu sesión para continuar. Intenta ingresar nuevamente.';
    }

    if (_containsAny(lower, [
      'anticip',
      'notice_required',
      'minimum notice',
      'booking_notice',
    ])) {
      return 'Ese horario ya no cumple con el tiempo mínimo de anticipación. Elige uno más adelante.';
    }

    if (_containsAny(lower, [
      'slot',
      'ya no est',
      'no disponible',
      'unavailable',
      'already',
      'ocup',
    ])) {
      return 'Ese horario ya no está disponible. Elige otro para continuar.';
    }

    if (_containsAny(lower, [
      'faltan campos obligatorios',
      'debes enviar customerid',
      'datos del cliente',
      'correo electrónico',
      'correo electronico',
      'celular',
      'first_name',
      'last_name',
      'revisa:',
    ])) {
      return message;
    }

    if (_containsAny(lower, [
      'fecha/hora de la reserva es inválida',
      'fecha/hora de la reserva es inválida',
      'booking_start',
      'fecha y hora',
    ])) {
      return 'La fecha u hora seleccionada ya no es válida. Elige un horario nuevamente.';
    }

    if (_containsAny(lower, [
      'ya está cancelada',
      'ya esta cancelada',
      'ya fue completada',
      'finalizada',
      'no se puede modificar',
    ])) {
      return 'La cita ya no puede actualizarse porque su estado cambió.';
    }

    if (_containsAny(lower, ['no encontramos la cita', 'booking_not_found'])) {
      return 'No encontramos esa cita. Actualiza tu listado e intenta nuevamente.';
    }

    if (_containsAny(lower, [
      'timeout',
      'future not completed',
      'socketexception',
      'clientexception',
      'connection',
      'conectar',
    ])) {
      return 'No pudimos completar la solicitud a tiempo. Revisa tu conexión e intenta nuevamente.';
    }

    if (_containsAny(lower, ['error 500', 'error en el servidor'])) {
      return 'Tuvimos un problema al validar tu reserva. Intenta nuevamente en unos minutos.';
    }

    return message;
  }

  String _friendlyRescheduleError(Object error) {
    final message = _friendlyBookingError(error);
    final lower = message.toLowerCase();

    if (_containsAny(lower, ['horario', 'disponible', 'anticip'])) {
      return message;
    }

    return FriendlyErrors.rescheduleAppointment(message);
  }

  void _showSuccessSheet({
    required String serviceName,
    required String locationName,
    required String barberName,
    required String dateLabel,
    required String time,
    String? reservationCode,
    String? statusLabel,
    String? paymentStatus,
    String? paymentMethodTitle,
    String? locationAddress,
    String? locationDescription,
    double? locationLatitude,
    double? locationLongitude,
    String? birthdayVerificationNotice,
    int durationSeconds = 3600,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheetCompact,
      ),
      builder: (sheetContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _closeSuccessAndGoToMyAppointments(sheetContext);
          },
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.88,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () =>
                            _closeSuccessAndGoToMyAppointments(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textSecondary,
                        tooltip: 'Cerrar',
                      ),
                    ),
                    Container(
                      width: AppIconSize.successBadge,
                      height: AppIconSize.successBadge,
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: AppRadius.large,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.goldDeep,
                        size: AppIconSize.successIcon,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                    const Text(
                      'Cita agendada con éxito',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppTextSize.headlineSmall,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    const Text(
                      'Tu reserva ya quedó registrada correctamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppTextSize.baseLarge,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                    if (reservationCode != null &&
                        reservationCode.trim().isNotEmpty)
                      _summaryRow('Reserva', '#$reservationCode'),
                    _summaryRow('Servicio', serviceName),
                    _summaryRow('Sucursal', locationName),
                    _summaryRow('Barbero', barberName),
                    _summaryRow('Fecha', dateLabel),
                    _summaryRow('Hora', time),
                    if (statusLabel != null && statusLabel.trim().isNotEmpty)
                      _summaryRow('Estado', statusLabel),
                    if (paymentMethodTitle != null &&
                        paymentMethodTitle.trim().isNotEmpty)
                      _summaryRow('Método de pago', paymentMethodTitle),
                    if (paymentStatus != null &&
                        paymentStatus.trim().isNotEmpty)
                      _summaryRow(
                        'Pago',
                        _normalizeStatusLabel(paymentStatus),
                      ),
                    if (birthdayVerificationNotice != null &&
                        birthdayVerificationNotice.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _birthdayVerificationNoticeCard(
                        birthdayVerificationNotice.trim(),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                    _actionButton(
                      icon: Icons.share_rounded,
                      label: 'Compartir por WhatsApp',
                      onTap: () async {
                        await _shareAppointmentOnWhatsApp(
                          reservationCode: reservationCode ?? '0',
                          serviceName: serviceName,
                          barberName: barberName,
                          branch: locationName,
                          dateLabel: dateLabel,
                          time: time,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    _actionButton(
                      icon: Icons.location_on_rounded,
                      label: 'Cómo llegar',
                      onTap: () async {
                        await _openLocation(
                          address: locationAddress,
                          latitude: locationLatitude,
                          longitude: locationLongitude,
                          branchName: locationName,
                          description: locationDescription,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                    _actionButton(
                      icon: Icons.calendar_month_rounded,
                      label: 'Agregar al calendario',
                      onTap: () async {
                        await _addToCalendar(
                          reservationCode: reservationCode ?? '0',
                          serviceName: serviceName,
                          barberName: barberName,
                          branch: locationName,
                          dateLabel: dateLabel,
                          time: time,
                          address: locationAddress,
                          durationSeconds: durationSeconds,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            _closeSuccessAndGoToMyAppointments(sheetContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.tile,
                          ),
                        ),
                        child: const Text(
                          'Cerrar y ver mis citas',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: AppTextSize.titleMedium,
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
      },
    );
  }

  Widget _birthdayVerificationNoticeCard(String notice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: AppRadius.tile,
        border: Border.all(color: AppColors.goldSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.badge_outlined,
            color: AppColors.goldDeep,
            size: AppIconSize.md,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              notice,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: AppTextSize.bodyCompact,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.goldDeep),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: AppTextSize.baseLarge,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.tile,
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primarySoft,
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.base,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.baseLarge,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasSection() {
    final extras = _currentServiceExtras();

    if (_selectedService == null) {
      return const Text(
        'Selecciona primero un servicio para ver sus complementos.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.bodyStrong,
          height: 1.4,
        ),
      );
    }

    if (extras.isEmpty) {
      return const Text(
        'Este servicio no tiene extras disponibles.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.bodyStrong,
          height: 1.4,
        ),
      );
    }

    if (!_wantsServiceExtras && _getSelectedExtrasDetailed().isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deseas agregar extras a tu servicio?',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextSize.titleSmall,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
          const Text(
            'Puedes sumar complementos ahora o continuar solo con el servicio principal.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.bodyStrong,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _wantsServiceExtras = true;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.goldDeep,
                side: const BorderSide(color: AppColors.secondary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.soft,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Ver extras disponibles',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ...extras.map((extra) {
          final int extraId = _safeInt(extra['id']) ?? 0;
          final int qty = _getExtraQty(extraId);
          final int maxQuantity = (_safeInt(extra['maxQuantity']) ?? 1);
          final double price = _safeDouble(extra['price']) ?? 0;
          final int duration = _safeInt(extra['duration']) ?? 0;
          final String description = (extra['description'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.tile,
              border: Border.all(
                color: qty > 0 ? AppColors.secondary : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (extra['name'] ?? '').toString(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTextSize.titleSmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoft,
                        borderRadius: AppRadius.full,
                      ),
                      child: Text(
                        '+${_formatCurrency(price)}',
                        style: const TextStyle(
                          color: AppColors.goldDeep,
                          fontSize: AppTextSize.bodySmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.bodyRelaxed,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppRadius.full,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '+ ${_formatDurationLabel(duration)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: AppTextSize.bodySmall,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _qtyButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Disminuir extra',
                      onTap: qty > 0 ? () => _changeExtraQty(extra, -1) : null,
                    ),
                    Container(
                      width: 38,
                      alignment: Alignment.center,
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppTextSize.titleSmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _qtyButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Aumentar extra',
                      onTap: qty < maxQuantity
                          ? () => _changeExtraQty(extra, 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        if (_getSelectedExtrasDetailed().isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldSurface,
              borderRadius: AppRadius.medium,
              border: Border.all(color: AppColors.goldSoft),
            ),
            child: Text(
              'Extras seleccionados: ${_formatCurrency(_getSelectedExtrasPriceTotal())} · ${_formatDurationLabel(_getSelectedExtrasDurationTotal())}',
              style: const TextStyle(
                color: AppColors.goldDeep,
                fontSize: AppTextSize.bodyStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(
    ShopProvider shop,
    AuthProvider auth,
    PointsProvider pointsProvider,
    PointsRedemptionState pointsState,
    double totalPrice,
  ) {
    final methods = _enabledPaymentMethods(shop);
    final selectedPaymentMethod = _selectedPaymentMethod(methods);
    final birthdayPromotion = pointsProvider.birthdayPromotion;
    final birthdayBalance = birthdayPromotion?.pointsAvailable ?? 0;
    final birthdayRate = pointsState.rate <= 0 ? 100.0 : pointsState.rate;
    final birthdayMaxPoints = totalPrice * birthdayRate;
    final birthdayPointsToUse = birthdayBalance < birthdayMaxPoints
        ? birthdayBalance
        : birthdayMaxPoints;
    final birthdayDiscount = birthdayPointsToUse <= 0
        ? 0.0
        : (birthdayPointsToUse / birthdayRate > totalPrice
            ? totalPrice
            : birthdayPointsToUse / birthdayRate);
    final pointsToUse = _bookingPointsToUse(auth, totalPrice, pointsProvider);
    final pointsDiscount =
        _bookingPointsDiscount(auth, totalPrice, pointsProvider);
    final projectedPayableTotal =
        (totalPrice - (_useBirthdayBonus ? birthdayDiscount : pointsDiscount))
            .clamp(0, double.infinity)
            .toDouble();
    final canShowBirthdayBonus = auth.isLoggedIn &&
        !_isEditing &&
        (birthdayPromotion?.enabled ?? false) &&
        (birthdayPromotion?.active ?? false) &&
        birthdayPointsToUse > 0;
    final canShowPointsModule = auth.isLoggedIn &&
        !_isEditing &&
        !_useBirthdayBonus &&
        pointsState.enabled &&
        pointsState.redeemEnabled &&
        PointsCalculator.isContextEnabled(
          pointsState,
          PointsRedemptionContext.booking,
        );
    final canTogglePoints =
        !_isSubmittingBooking && !pointsProvider.hasPointsReservation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shop.isLoadingPaymentMethods) ...[
          const LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.secondary,
            backgroundColor: AppColors.goldMuted,
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
        ],
        ...methods.map(
          (method) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BookingPaymentMethodTile(
              method: method,
              selected: selectedPaymentMethod.id == method.id,
              enabled: method.canCreateManualOrder,
              onTap: () {
                if (!method.canCreateManualOrder) {
                  _showMessage(
                    '${method.title} estará disponible pronto para reservas desde la app.',
                  );
                  return;
                }

                setState(() {
                  _selectedPaymentMethodId = method.id;
                });
              },
            ),
          ),
        ),
        if (canShowBirthdayBonus) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.goldSurface,
              borderRadius: AppRadius.tile,
              border: Border.all(color: AppColors.goldSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.cake_rounded,
                      color: AppColors.goldDeep,
                      size: AppIconSize.spinner,
                    ),
                    SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        'Bono de cumpleaños disponible',
                        style: TextStyle(
                          color: AppColors.goldDeep,
                          fontWeight: FontWeight.w900,
                          fontSize: AppTextSize.baseLarge,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Text(
                  'Puedes usar ${birthdayPromotion!.pointsFormatted} puntos promocionales solo en reservas.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontSize: AppTextSize.bodyCompact,
                  ),
                ),
                if (birthdayPromotion.verificationNotice.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.card,
                      border: Border.all(color: AppColors.goldSoft),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: AppColors.goldDeep,
                          size: AppIconSize.md,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            birthdayPromotion.verificationNotice,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              fontSize: AppTextSize.bodyCompact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _BookingPointsRedeemTile(
                  enabled: _useBirthdayBonus,
                  pointsLabel: 'Puntos cumpleaños',
                  points: birthdayPointsToUse,
                  discount: birthdayDiscount,
                  total: totalPrice,
                  payableTotal: projectedPayableTotal,
                  balance: birthdayBalance,
                  interactive: canTogglePoints,
                  onChanged: (value) {
                    setState(() {
                      _useBirthdayBonus = value;
                      if (value) _usePoints = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
        if (canShowPointsModule) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.tile,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: AppColors.goldDeep,
                      size: AppIconSize.spinner,
                    ),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        'Canjear ${pointsState.label}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: AppTextSize.baseLarge,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Text(
                  _bookingPointsHelperMessage(
                    pointsState,
                    totalPrice,
                  ),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontSize: AppTextSize.bodyCompact,
                  ),
                ),
                if (pointsToUse > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _BookingPointsRedeemTile(
                    enabled: _usePoints,
                    pointsLabel: pointsState.label,
                    points: pointsToUse,
                    discount: pointsDiscount,
                    total: totalPrice,
                    payableTotal: projectedPayableTotal,
                    balance: pointsState.balance,
                    interactive: canTogglePoints,
                    onChanged: (value) {
                      setState(() {
                        _usePoints = value;
                        if (value) _useBirthdayBonus = false;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
        if (shop.paymentMethodsError != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'No pudimos actualizar los métodos de pago. Usamos transferencia como respaldo.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.tile,
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.goldDeep,
                size: AppIconSize.spinner,
              ),
              SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Text(
                  'Antes de confirmar revisaremos que el horario siga libre y que tus datos estén listos para la reserva.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontSize: AppTextSize.bodyRelaxed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.compact,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: onTap == null ? AppColors.surfaceMuted : Colors.white,
              borderRadius: AppRadius.compact,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              color:
                  onTap == null ? AppColors.textSecondary : AppColors.goldDeep,
              size: AppIconSize.compact,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final auth = context.watch<AuthProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    final pointsState = _resolvePointsState(auth, pointsProvider);
    final paymentMethods = _enabledPaymentMethods(shop);
    final selectedPaymentMethod = _selectedPaymentMethod(paymentMethods);
    final isReadyForSubmit =
        _isFormValid && selectedPaymentMethod.canCreateManualOrder;
    final canConfirmBooking = isReadyForSubmit && !_isSubmittingBooking;
    final String title = _selectedService?['title'] ?? 'Selecciona un servicio';
    final totalPrice = _getGrandTotalPrice();
    final birthdayPromotion = pointsProvider.birthdayPromotion;
    final birthdayRate = pointsState.rate <= 0 ? 100.0 : pointsState.rate;
    final birthdayBalance = birthdayPromotion?.pointsAvailable ?? 0;
    final birthdayMaxPoints = totalPrice * birthdayRate;
    final birthdayPointsToUse = birthdayBalance < birthdayMaxPoints
        ? birthdayBalance
        : birthdayMaxPoints;
    final birthdayDiscount = _useBirthdayBonus && birthdayPointsToUse > 0
        ? (birthdayPointsToUse / birthdayRate > totalPrice
            ? totalPrice
            : birthdayPointsToUse / birthdayRate)
        : 0.0;
    final pointsDiscount = _usePoints
        ? _bookingPointsDiscount(auth, totalPrice, pointsProvider)
        : 0.0;
    final payableTotal = (totalPrice - birthdayDiscount - pointsDiscount)
        .clamp(0, double.infinity)
        .toDouble();
    final String price =
        _selectedService != null ? _formatCurrency(payableTotal) : '-';
    final String? image = _selectedService?['image'];
    final String durationLabel = _selectedService != null
        ? _formatDurationLabel(_getGrandTotalDuration())
        : '-';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditing ? 'Reagendar cita' : 'Reservar cita',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: HabitoLoadingShimmer(
                  itemCount: 5,
                  itemHeight: 118,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.panel,
                      boxShadow: AppShadows.panel,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: AppRadius.large,
                            child: Container(
                              width: AppIconSize.serviceThumbnail,
                              height: AppIconSize.serviceThumbnail,
                              color: AppColors.surfaceMuted,
                              child: image != null && image.isNotEmpty
                                  ? HabitoCachedNetworkImage(
                                      imageUrl: image,
                                      fit: BoxFit.cover,
                                      semanticLabel:
                                          'Imagen del servicio $title',
                                      errorWidget: _serviceFallback(),
                                    )
                                  : Semantics(
                                      label: 'Imagen del servicio $title',
                                      image: true,
                                      child: _serviceFallback(),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md + AppSpacing.xxs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Servicio seleccionado',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppTextSize.bodySmall,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(
                                    height: AppSpacing.xs + AppSpacing.xxs),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: AppTextSize.titleLarge,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(
                                    height: AppSpacing.sm + AppSpacing.xxs),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.goldSoft,
                                        borderRadius: AppRadius.full,
                                      ),
                                      child: Text(
                                        price,
                                        style: const TextStyle(
                                          color: AppColors.goldDeep,
                                          fontWeight: FontWeight.w800,
                                          fontSize: AppTextSize.base,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius: AppRadius.full,
                                      ),
                                      child: Text(
                                        durationLabel,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: AppTextSize.body,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Servicio',
                    child: _buildServiceDropdown(),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Extras del servicio',
                    child: _buildExtrasSection(),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Sucursal',
                    child: _buildLocationDropdown(),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Barbero',
                    child: _buildEmployeeDropdown(),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Fecha',
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: AppRadius.tile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: AppRadius.tile,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.goldDeep,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _selectedDate == null
                                    ? 'Selecciona el día de tu reserva'
                                    : _formatDate(_selectedDate!),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: AppTextSize.titleSmall,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Horarios disponibles',
                    child: _buildAvailabilitySection(),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Datos del cliente y facturación',
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'Primer nombre',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.givenName],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _middleNameController,
                          label: 'Segundo nombre',
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.middleName],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Apellidos',
                          icon: Icons.badge_outlined,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.familyName],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildDropdownField(
                          label: 'Tipo de cliente',
                          icon: Icons.apartment_outlined,
                          value: _contactType,
                          items: kContactTypeLabels.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _contactType = value;
                              if (_contactType == 'business') {
                                _identificationType = 'ruc';
                              }
                            });
                          },
                        ),
                        if (_contactType == 'business') ...[
                          const SizedBox(height: AppSpacing.md),
                          _buildTextField(
                            controller: _businessNameController,
                            label: 'Razon social',
                            icon: Icons.business_outlined,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.organizationName,
                            ],
                            maxLength: FormValidators.longTextMaxLength,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _buildDropdownField(
                          label: 'Tipo de identificacion',
                          icon: Icons.credit_card_outlined,
                          value: _effectiveIdentificationType,
                          items: _bookingIdentificationTypes
                              .map(
                                (type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(
                                    kIdentificationTypeLabels[type] ?? type,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _identificationType = value;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _taxNumberController,
                          label: _bookingDocumentLabel,
                          icon: Icons.badge_outlined,
                          keyboardType:
                              _effectiveIdentificationType == 'pasaporte'
                                  ? TextInputType.text
                                  : TextInputType.number,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildDropdownField(
                          label: 'Provincia',
                          icon: Icons.map_outlined,
                          value: _province,
                          items: kEcuadorProvinces
                              .map(
                                (province) => DropdownMenuItem<String>(
                                  value: province,
                                  child: Text(province),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _province = value;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _cityController,
                          label: 'Canton o ciudad',
                          icon: Icons.location_city_outlined,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.addressCity],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Dirección principal',
                          icon: Icons.home_outlined,
                          keyboardType: TextInputType.streetAddress,
                          textInputAction: TextInputAction.newline,
                          autofillHints: const [
                            AutofillHints.fullStreetAddress,
                          ],
                          maxLength: FormValidators.longTextMaxLength,
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Celular',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.telephoneNumber,
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Correo electronico',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _sectionCard(
                    title: 'Método de pago',
                    child: _buildPaymentMethodSection(
                      shop,
                      auth,
                      pointsProvider,
                      pointsState,
                      totalPrice,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.panel,
                      boxShadow: AppShadows.panel,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.goldDeep,
                            ),
                            const SizedBox(
                                width: AppSpacing.sm + AppSpacing.xxs),
                            const Expanded(
                              child: Text(
                                'Resumen rápido',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTextSize.titleMedium,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isReadyForSubmit
                                    ? AppColors.successSoft
                                    : AppColors.warningSoft,
                                borderRadius: AppRadius.full,
                              ),
                              child: Text(
                                isReadyForSubmit ? 'Listo' : 'Incompleto',
                                style: TextStyle(
                                  color: isReadyForSubmit
                                      ? AppColors.success
                                      : AppColors.warningDeep,
                                  fontSize: AppTextSize.label,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                        _infoLine('Servicio', title),
                        _infoLine(
                          'Base',
                          _formatCurrency(_getBaseServicePrice()),
                        ),
                        if (_getSelectedExtrasDetailed().isNotEmpty)
                          _infoLine(
                            'Extras',
                            _formatCurrency(_getSelectedExtrasPriceTotal()),
                          ),
                        if (birthdayDiscount > 0)
                          _infoLine(
                            'Bono cumpleaños',
                            '-${_formatCurrency(birthdayDiscount)}',
                          ),
                        if (pointsDiscount > 0)
                          _infoLine(
                            'Descuento por puntos',
                            '-${_formatCurrency(pointsDiscount)}',
                          ),
                        _infoLine('Total', price),
                        _infoLine('Duración', durationLabel),
                        _infoLine(
                            'Sucursal', _selectedLocation?['name'] ?? '-'),
                        _infoLine(
                          'Barbero',
                          _selectedEmployee?['fullName'] ?? '-',
                        ),
                        _infoLine(
                          'Fecha',
                          _selectedDate == null
                              ? 'No seleccionada'
                              : _formatDate(_selectedDate!),
                        ),
                        _infoLine(
                            'Hora', _selectedTimeSlot ?? 'No seleccionada'),
                        _infoLine('Pago', selectedPaymentMethod.title),
                        if (_getSelectedExtrasDetailed().isNotEmpty) ...[
                          const SizedBox(
                              height: AppSpacing.xs + AppSpacing.xxs),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Complementos elegidos',
                              style: const TextStyle(
                                color: AppColors.goldDeep,
                                fontWeight: FontWeight.w800,
                                fontSize: AppTextSize.bodyStrong,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ..._getSelectedExtrasDetailed().map(
                            (extra) => _infoLine(
                              '${extra['quantity']}x',
                              '${extra['name']} (${_formatCurrency(_safeDouble(extra['totalPrice']) ?? 0)})',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl - AppSpacing.xxs),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canConfirmBooking ? _confirmBooking : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        disabledBackgroundColor: AppColors.border,
                        foregroundColor: AppColors.primary,
                        disabledForegroundColor: AppColors.textMuted,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.large,
                        ),
                      ),
                      child: _isSubmittingBooking
                          ? const SizedBox(
                              width: AppIconSize.progress,
                              height: AppIconSize.progress,
                              child: CircularProgressIndicator(
                                strokeWidth: AppSpacing.progressStroke,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : Text(
                              _isEditing ? 'Guardar cambios' : 'Confirmar cita',
                              style: const TextStyle(
                                fontSize: AppTextSize.titleMedium,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                  if (!_isFormValid)
                    const Text(
                      'Completa servicio, sucursal, barbero, horario y todos los datos fiscales para continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppTextSize.bodyStrong,
                        height: 1.4,
                      ),
                    )
                  else if (!selectedPaymentMethod.canCreateManualOrder)
                    Text(
                      '${selectedPaymentMethod.title} estará disponible pronto para reservas desde la app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppTextSize.bodyStrong,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    if (!_canLoadAvailability) {
      return const Text(
        'Selecciona servicio, sucursal, barbero y fecha para consultar horarios reales.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.bodyStrong,
          height: 1.4,
        ),
      );
    }

    if (_isLoadingAvailability) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.gutter),
        child: HabitoLoadingShimmer(
          itemCount: 2,
          itemHeight: 48,
        ),
      );
    }

    if (_availableTimeSlots.isEmpty) {
      return HabitoEmptyState(
        icon: Icons.schedule_rounded,
        title: 'Sin horarios disponibles',
        message: _availabilityNoticeMessage ??
            'No hay horarios disponibles para esta fecha.',
        compact: true,
      );
    }

    if (_selectedTimeSlot != null && !_showAllTimeSlots) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.goldSurface,
          borderRadius: AppRadius.large,
          border: Border.all(color: AppColors.secondary),
        ),
        child: Row(
          children: [
            Container(
              width: AppIconSize.pointsBadge,
              height: AppIconSize.pointsBadge,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: AppRadius.medium,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Horario seleccionado',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTextSize.bodySmall,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.progress),
                  Text(
                    _selectedTimeSlot!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.section,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showAllTimeSlots = true;
                });
              },
              child: const Text(
                'Cambiar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }

    final slotsWrap = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _availableTimeSlots.map((slot) {
        final bool isSelected = _selectedTimeSlot == slot;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTimeSlot = slot;
              _showAllTimeSlots = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.secondary : AppColors.surfaceElevated,
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: isSelected ? AppColors.secondary : AppColors.border,
              ),
            ),
            child: Text(
              slot,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: AppTextSize.base,
              ),
            ),
          ),
        );
      }).toList(),
    );

    if ((_availabilityNoticeMessage ?? '').trim().isEmpty) {
      return slotsWrap;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _availabilityNoticeMessage!,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTextSize.body,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        slotsWrap,
      ],
    );
  }

  Widget _serviceFallback() {
    final placeholderImage = (_selectedService?['placeholderImage'] ??
            'assets/images/services/service_default.png')
        .toString();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
      ),
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.content_cut_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  String _servicePlaceholderImage(String title) {
    final value = title.toLowerCase();
    if (value.contains('corte') && value.contains('barba')) {
      return 'assets/images/services/service_corte_barba.png';
    }
    if (value.contains('corte')) {
      return 'assets/images/services/service_corte.png';
    }
    if (value.contains('barba')) {
      return 'assets/images/services/service_barba.png';
    }
    if (value.contains('masaje')) {
      return 'assets/images/services/service_masaje.png';
    }
    if (value.contains('facial') || value.contains('limpieza')) {
      return 'assets/images/services/service_facial.png';
    }
    return 'assets/images/services/service_default.png';
  }

  Widget _buildServiceDropdown() {
    final String? selectedTitle = _selectedService?['title'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _isEditing ? AppColors.surfaceMuted : AppColors.surfaceElevated,
        borderRadius: AppRadius.tile,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedTitle,
          dropdownColor: Colors.white,
          isExpanded: true,
          icon: Icon(
            _isEditing
                ? Icons.lock_outline_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          hint: const Text(
            'Selecciona un servicio',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.titleSmall,
            fontWeight: FontWeight.w600,
          ),
          items: _services.map((service) {
            return DropdownMenuItem<String>(
              value: service['title'] as String,
              child: Text(service['title'] as String),
            );
          }).toList(),
          onChanged: _isEditing
              ? null
              : (value) async {
                  if (value == null) return;
                  await _onServiceChanged(value);
                },
        ),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    final selectedName = _selectedLocation?['name']?.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _isEditing ? AppColors.surfaceMuted : AppColors.surfaceElevated,
        borderRadius: AppRadius.tile,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedName,
          dropdownColor: Colors.white,
          isExpanded: true,
          icon: Icon(
            _isEditing
                ? Icons.lock_outline_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          hint: const Text(
            'Selecciona una sucursal',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.titleSmall,
            fontWeight: FontWeight.w600,
          ),
          items: _locations.map((location) {
            final name = location['name']?.toString() ?? '';
            return DropdownMenuItem<String>(
              value: name,
              child: Text(name),
            );
          }).toList(),
          onChanged: _isEditing
              ? null
              : (value) async {
                  if (value == null) return;

                  final location = _locations.firstWhere(
                    (item) => item['name'] == value,
                  );

                  setState(() {
                    _selectedLocation = location;
                    _selectedTimeSlot = null;
                    _availableTimeSlots = [];
                    _showAllTimeSlots = true;
                  });

                  _applyEmployeesForCurrentSelection(
                    showMessageIfAdjusted: true,
                  );

                  await _loadAvailabilityIfPossible();
                },
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown() {
    if (_selectedService == null || _selectedLocation == null) {
      return const Text(
        'Selecciona servicio y sucursal para ver los barberos disponibles.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.bodyStrong,
          height: 1.4,
        ),
      );
    }

    if (_filteredEmployees.isEmpty) {
      return const Text(
        'No encontramos barberos disponibles para esta selección.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.bodyStrong,
          height: 1.4,
        ),
      );
    }

    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filteredEmployees.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final employee = _filteredEmployees[index];
          final selected =
              _safeInt(_selectedEmployee?['id']) == _safeInt(employee['id']);

          return _BarberPickerCard(
            employee: employee,
            selected: selected,
            locked: _isEditing,
            onTap: _isEditing
                ? null
                : () async {
                    setState(() {
                      _selectedEmployee = employee;
                      _selectedTimeSlot = null;
                      _availableTimeSlots = [];
                      _showAllTimeSlots = true;
                    });

                    await _loadAvailabilityIfPossible(
                      employeeOverride: employee,
                    );
                  },
          );
        },
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.panel,
        boxShadow: AppShadows.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.goldDeep,
                fontSize: AppTextSize.titleSmall,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : 1,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.goldDeep),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: AppRadius.tile,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.tile,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.tile,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.2),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: Colors.white,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.goldDeep),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: AppRadius.tile,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.tile,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.tile,
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.2),
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.bodyStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.bodyMedium,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingPointsRedeemTile extends StatelessWidget {
  final bool enabled;
  final String pointsLabel;
  final double points;
  final double discount;
  final double total;
  final double payableTotal;
  final double balance;
  final bool interactive;
  final ValueChanged<bool> onChanged;

  const _BookingPointsRedeemTile({
    required this.enabled,
    required this.pointsLabel,
    required this.points,
    required this.discount,
    required this.total,
    required this.payableTotal,
    required this.balance,
    this.interactive = true,
    required this.onChanged,
  });

  String _formatPoints(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final pointsText = _formatPoints(points);
    final balanceText = _formatPoints(balance);
    final isFullPayment = payableTotal <= 0.009;

    return InkWell(
      onTap: interactive ? () => onChanged(!enabled) : null,
      borderRadius: AppRadius.large,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled ? AppColors.goldSurface : Colors.white,
          borderRadius: AppRadius.large,
          border: Border.all(
            color: enabled ? AppColors.secondary : AppColors.border,
            width: enabled ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.secondary : AppColors.goldMuted,
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(
                    Icons.stars_rounded,
                    color: enabled ? Colors.white : AppColors.goldDeep,
                    size: 21,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enabled
                            ? 'Descuento aplicado'
                            : 'Usar $pointsLabel en esta cita',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: AppTextSize.baseLarge,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.progress),
                      Text(
                        '$pointsText de $balanceText puntos disponibles',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.bodyTiny,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: enabled,
                  activeThumbColor: AppColors.secondary,
                  activeTrackColor: AppColors.borderStrong,
                  onChanged: interactive ? onChanged : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 380;
                final metricWidth = compact
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BookingPointsMetric(
                      width: metricWidth,
                      label: 'Ahorras',
                      value: _formatCurrency(discount),
                      valueColor: AppColors.success,
                    ),
                    _BookingPointsMetric(
                      width: metricWidth,
                      label: enabled ? 'Pagaras' : 'Pagarias',
                      value: _formatCurrency(payableTotal),
                      valueColor: isFullPayment
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                    _BookingPointsMetric(
                      width: metricWidth,
                      label: 'Total original',
                      value: _formatCurrency(total),
                      valueColor: AppColors.textSecondary,
                    ),
                  ],
                );
              },
            ),
            if (isFullPayment) ...[
              const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
              const Text(
                'La reserva queda cubierta al 100% con puntos.',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: AppTextSize.bodySmall,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingPointsMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final Color valueColor;

  const _BookingPointsMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.medium,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.captionSm,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.progress),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontSize: AppTextSize.title,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingPaymentMethodTile extends StatelessWidget {
  final ShopPaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _BookingPaymentMethodTile({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = method.requiresOnlinePayment
        ? 'Pago online'
        : method.id == 'bacs'
            ? 'Transferencia'
            : method.isOnSite
                ? 'On-site'
                : 'Manual';

    final description = enabled
        ? _descriptionForBooking(method)
        : '${_descriptionForBooking(method)} Estará disponible pronto.';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  selected ? AppColors.goldSurface : AppColors.surfaceElevated,
              borderRadius: AppRadius.large,
              border: Border.all(
                color: selected ? AppColors.secondary : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : enabled
                          ? Icons.radio_button_off_outlined
                          : Icons.lock_outline_rounded,
                  color:
                      selected ? AppColors.secondary : AppColors.textSecondary,
                  size: 23,
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.progress),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              method.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: AppTextSize.baseLarge,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.borderStrong
                                  .withValues(alpha: 0.24),
                              borderRadius: AppRadius.full,
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: AppColors.goldDeep,
                                fontSize: AppTextSize.captionXs,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.body,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _descriptionForBooking(ShopPaymentMethod method) {
    if (method.id == 'bacs') {
      return 'Confirmamos tu cita y validas el pago con el equipo de Hábito.';
    }

    if (method.isOnSite) {
      return 'Confirma tu cita y paga directamente en la barberia.';
    }

    if (method.description.trim().isNotEmpty) {
      return method.description.trim();
    }

    return 'Selecciona este método para confirmar tu cita.';
  }
}

class _BarberPickerCard extends StatelessWidget {
  final Map<String, dynamic> employee;
  final bool selected;
  final bool locked;
  final Future<void> Function()? onTap;

  const _BarberPickerCard({
    required this.employee,
    required this.selected,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = employee['fullName']?.toString() ?? 'Barbero Hábito';
    final imageUrl = employee['image']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.panel,
        child: Ink(
          width: 156,
          decoration: BoxDecoration(
            color: selected ? AppColors.goldSurface : AppColors.surfaceElevated,
            borderRadius: AppRadius.panel,
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.large,
                  child: SizedBox(
                    height: 104,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty
                        ? HabitoCachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorWidget: const _BarberPickerFallback(),
                          )
                        : const _BarberPickerFallback(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.secondary
                            : AppColors.textSecondary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(
                        width: AppSpacing.sm -
                            AppSpacing.xxs +
                            AppSpacing.progress),
                    Expanded(
                      child: Text(
                        locked && selected
                            ? 'Fijo para reagendar'
                            : selected
                                ? 'Seleccionado'
                                : 'Barbero',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AppColors.goldDeep
                              : AppColors.textSecondary,
                          fontSize: AppTextSize.captionSm,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.baseLarge,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
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

class _BarberPickerFallback extends StatelessWidget {
  const _BarberPickerFallback();

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
          Icons.content_cut_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}
