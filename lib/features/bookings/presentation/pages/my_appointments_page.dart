import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/location_launcher_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/habito_empty_state.dart';
import '../../../../shared/widgets/habito_error_state.dart';
import '../../../../shared/widgets/habito_loading_shimmer.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/unread_notifications_button.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import '../../../shop/presentation/pages/cart_page.dart';
import '../../../shop/presentation/pages/products_archive_page.dart';
import '../../../shop/provider/shop_provider.dart';
import 'appointment_detail_page.dart';
import 'bookings_page.dart';

enum _AppointmentDateFilter {
  all,
  today,
  sevenDays,
  fifteenDays,
  oneMonth,
}

class MyAppointmentsPage extends StatefulWidget {
  final Map<String, dynamic>? initialArguments;

  const MyAppointmentsPage({
    super.key,
    this.initialArguments,
  });

  static void clearCachedState() {
    // La versión actual ya no mantiene caché estático en esta pantalla.
    // Dejamos este hook para limpiar el estado compartido de forma segura
    // cuando la sesión cambia.
  }

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  AuthProvider? _authProvider;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _allAppointments = [];
  String? _loadedToken;

  bool _didReadRouteArgs = false;
  bool _didOpenPushAppointment = false;
  int? _pushAppointmentId;
  int? _pushBookingId;
  bool _openFromPush = false;
  int _loadRequestId = 0;
  bool _isLoadingHistory = false;
  bool _hasLoadedHistory = false;
  bool _didAutoFocusNonEmptyTab = false;
  _AppointmentDateFilter _selectedDateFilter = _AppointmentDateFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider = context.read<AuthProvider>();
      _authProvider!.addListener(_onAuthChanged);
      _loadAppointments();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didReadRouteArgs) return;
    _didReadRouteArgs = true;

    final route = ModalRoute.of(context);
    final args = widget.initialArguments ?? route?.settings.arguments;

    if (args is Map) {
      final map = Map<String, dynamic>.from(args);

      _pushAppointmentId = _parseInt(
        map['appointmentId'] ?? map['appointment_id'],
      );
      _pushBookingId = _parseInt(
        map['bookingId'] ?? map['booking_id'],
      );
      _openFromPush = map['openFromPush'] == true;
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }

    if (!_tabController.indexIsChanging && _tabController.index == 2) {
      unawaited(_loadHistoryAppointments());
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final token = auth.token?.trim();

    if (!auth.isLoggedIn || token == null || token.isEmpty) {
      setState(() {
        _loadedToken = null;
        _allAppointments = [];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    if (_loadedToken != token || _error != null || _allAppointments.isEmpty) {
      _loadAppointments();
    }
  }

  String _friendlyLoadError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = text.toLowerCase();

    if (lower.contains('timeoutexception') ||
        lower.contains('future not completed') ||
        lower.contains('timed out')) {
      return 'No pudimos cargar tus citas a tiempo. Revisa tu conexión e intenta nuevamente.';
    }

    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection')) {
      return 'No pudimos conectar con tus citas. Revisa tu internet e intenta nuevamente.';
    }

    return text.isEmpty
        ? 'No pudimos cargar tus citas. Intenta nuevamente.'
        : text;
  }

  Future<void> _loadAppointments({
    bool retryingFirstLoad = false,
  }) async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();

    if (!auth.isInitialized || auth.isLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      return;
    }

    final token = auth.token;

    if (token == null || token.trim().isEmpty) {
      setState(() {
        _loadedToken = null;
        _isLoading = false;
        _error = null;
        _allAppointments = [];
      });
      return;
    }

    final requestId = ++_loadRequestId;
    final normalizedToken = token.trim();
    final tokenChanged =
        _loadedToken != null && _loadedToken != normalizedToken;

    setState(() {
      _isLoading = true;
      _error = null;
      if (tokenChanged) {
        _allAppointments = [];
      }
    });

    try {
      final response = await _loadAllMyBookings(normalizedToken);
      final rawList = _extractItemsFromResponse(response);

      final appointments = rawList
          .whereType<Map>()
          .map((e) => _normalizeAppointment(Map<String, dynamic>.from(e)))
          .toList();

      _sortAppointments(appointments);

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _loadedToken = normalizedToken;
        _allAppointments = appointments;
        _hasLoadedHistory = false;
        _isLoading = false;
        if (tokenChanged) {
          _didAutoFocusNonEmptyTab = false;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusFirstNonEmptyTab();
      });
      _tryOpenAppointmentFromPush();
      unawaited(_loadHistoryAppointments(silent: true));
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;

      if (!retryingFirstLoad &&
          _allAppointments.isEmpty &&
          _isRetryableFirstLoadError(e)) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted || requestId != _loadRequestId) return;
        await _loadAppointments(retryingFirstLoad: true);
        return;
      }

      setState(() {
        _error = _friendlyLoadError(e);
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _loadAllMyBookings(String token) async {
    return _loadMyBookingsPages(
      token: token,
      view: 'upcoming',
      pageLimit: 80,
      maxPages: 4,
    );
  }

  Future<Map<String, dynamic>> _loadMyBookingsPages({
    required String token,
    required String view,
    int pageLimit = 50,
    int maxPages = 6,
  }) async {
    final allItems = <dynamic>[];
    Map<String, dynamic> lastResponse = <String, dynamic>{};

    for (var page = 1; page <= maxPages; page++) {
      final response = await HabitoBookingApi.getMyBookings(
        token: token,
        limit: pageLimit,
        page: page,
        includeRaw: false,
        view: view,
      );

      lastResponse = response;
      final items = _extractItemsFromResponse(response);
      allItems.addAll(items);

      if (response['has_more'] != true) {
        break;
      }
    }

    return {
      ...lastResponse,
      'items': allItems,
      'total': allItems.length,
    };
  }

  Future<void> _loadHistoryAppointments({bool silent = false}) async {
    if (!mounted || _isLoadingHistory || _hasLoadedHistory) return;

    final auth = context.read<AuthProvider>();
    final token = auth.token?.trim();
    if (!auth.isLoggedIn || token == null || token.isEmpty) return;

    _isLoadingHistory = true;

    try {
      final response = await _loadMyBookingsPages(
        token: token,
        view: 'history',
        pageLimit: 50,
        maxPages: 6,
      );
      final rawList = _extractItemsFromResponse(response);
      final history = rawList
          .whereType<Map>()
          .map((e) => _normalizeAppointment(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;

      setState(() {
        _allAppointments = _mergeAppointments(_allAppointments, history);
        _sortAppointments(_allAppointments);
        _hasLoadedHistory = true;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = _friendlyLoadError(e);
      });
    } finally {
      _isLoadingHistory = false;
    }
  }

  List<Map<String, dynamic>> _mergeAppointments(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final item in [...current, ...incoming]) {
      final key = _appointmentIdentity(item);
      merged[key] = item;
    }

    return merged.values.toList();
  }

  String _appointmentIdentity(Map<String, dynamic> appointment) {
    final appointmentId = _parseInt(
      appointment['appointmentId'] ?? appointment['appointment_id'],
    );
    final bookingId = _parseInt(
      appointment['bookingId'] ?? appointment['booking_id'],
    );

    if (appointmentId != null && appointmentId > 0) {
      return 'appointment:$appointmentId';
    }
    if (bookingId != null && bookingId > 0) return 'booking:$bookingId';

    return [
      appointment['bookingStart'],
      appointment['service_name'],
      appointment['provider_name'],
      appointment['status'],
    ].join('|');
  }

  void _sortAppointments(List<Map<String, dynamic>> appointments) {
    appointments.sort((a, b) {
      final dateA = _resolveAppointmentDate(a);
      final dateB = _resolveAppointmentDate(b);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateB.compareTo(dateA);
    });
  }

  bool _isRetryableFirstLoadError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('future not completed') ||
        lower.contains('clientexception') ||
        lower.contains('socketexception') ||
        lower.contains('connection');
  }

  void _tryOpenAppointmentFromPush() {
    if (!mounted) return;
    if (_didOpenPushAppointment) return;
    if (!_openFromPush) return;
    if (_allAppointments.isEmpty) return;

    Map<String, dynamic>? target;

    if (_pushAppointmentId != null) {
      for (final appointment in _allAppointments) {
        final appointmentId = _parseInt(
          appointment['appointmentId'] ??
              appointment['appointment_id'] ??
              appointment['id'],
        );

        if (appointmentId != null && appointmentId == _pushAppointmentId) {
          target = appointment;
          break;
        }
      }
    }

    if (target == null && _pushBookingId != null) {
      for (final appointment in _allAppointments) {
        final bookingMap = appointment['booking'];
        int? bookingId;

        if (bookingMap is Map) {
          bookingId = _parseInt(bookingMap['id']);
        }

        bookingId ??= _parseInt(
          appointment['bookingId'] ?? appointment['booking_id'],
        );

        if (bookingId != null && bookingId == _pushBookingId) {
          target = appointment;
          break;
        }
      }
    }

    if (target == null) {
      return;
    }

    _didOpenPushAppointment = true;

    final statusKey = _appointmentStatusKey(target);
    int tabIndex = 0;

    if (statusKey == 'confirmed' || statusKey == 'completed') {
      tabIndex = 1;
    } else if (statusKey == 'canceled' || statusKey == 'rejected') {
      tabIndex = 2;
    }

    if (_tabController.index != tabIndex) {
      _tabController.animateTo(tabIndex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailPage(appointment: target!),
        ),
      );
    });
  }

  List<dynamic> _extractItemsFromResponse(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is Map<String, dynamic>) {
      if (response['items'] is List) {
        return List<dynamic>.from(response['items']);
      }

      if (response['data'] is List) {
        return List<dynamic>.from(response['data']);
      }

      if (response['data'] is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(response['data']);

        if (data['items'] is List) {
          return List<dynamic>.from(data['items']);
        }

        if (data['data'] is List) {
          return List<dynamic>.from(data['data']);
        }

        if (data['appointments'] is List) {
          return List<dynamic>.from(data['appointments']);
        }
      }

      if (response['appointments'] is List) {
        return List<dynamic>.from(response['appointments']);
      }
    }

    throw Exception('La respuesta de citas no tiene el formato esperado.');
  }

  Map<String, dynamic> _normalizeAppointment(Map<String, dynamic> appointment) {
    final raw = appointment['raw'] is Map
        ? Map<String, dynamic>.from(appointment['raw'])
        : <String, dynamic>{};

    final rawBookings = raw['bookings'] is List
        ? List<Map<String, dynamic>>.from(
            (raw['bookings'] as List).whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ),
          )
        : <Map<String, dynamic>>[];

    final rawBooking =
        rawBookings.isNotEmpty ? rawBookings.first : <String, dynamic>{};

    final rawCustomer = rawBooking['customer'] is Map
        ? Map<String, dynamic>.from(rawBooking['customer'])
        : <String, dynamic>{};

    final rawPayments = rawBooking['payments'] is List
        ? List<Map<String, dynamic>>.from(
            (rawBooking['payments'] as List).whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ),
          )
        : <Map<String, dynamic>>[];

    final rawPayment =
        rawPayments.isNotEmpty ? rawPayments.first : <String, dynamic>{};

    final serviceName = _firstNonEmpty([
      appointment['service_name']?.toString(),
      appointment['service']?.toString(),
      _readNestedString(raw, ['service', 'name']),
      _readNestedString(appointment, ['service', 'name']),
    ]);

    final providerName = _firstNonEmpty([
      appointment['provider_name']?.toString(),
      _readNestedString(raw, ['provider', 'fullName']),
      _readNestedString(appointment, ['provider', 'fullName']),
      [
        _readNestedString(raw, ['provider', 'firstName']),
        _readNestedString(raw, ['provider', 'lastName']),
      ].where((e) => e != null && e.trim().isNotEmpty).join(' '),
      [
        _readNestedString(appointment, ['provider', 'firstName']),
        _readNestedString(appointment, ['provider', 'lastName']),
      ].where((e) => e != null && e.trim().isNotEmpty).join(' '),
    ]);

    final locationName = _firstNonEmpty([
      appointment['location_name']?.toString(),
      appointment['branch']?.toString(),
      _readNestedString(raw, ['location', 'name']),
      _readNestedString(appointment, ['location', 'name']),
    ]);

    final bookingStart = _firstNonEmpty([
      appointment['booking_start']?.toString(),
      appointment['bookingStart']?.toString(),
      _readNestedString(raw, ['bookingStart']),
    ]);

    final bookingEnd = _firstNonEmpty([
      appointment['booking_end']?.toString(),
      appointment['bookingEnd']?.toString(),
      _readNestedString(raw, ['bookingEnd']),
    ]);

    final resolvedStatus = _firstNonEmpty([
      appointment['status']?.toString(),
      appointment['statusRaw']?.toString(),
      rawBooking['status']?.toString(),
      _readNestedString(raw, ['status']),
    ]);

    final clientName = _firstNonEmpty([
      appointment['customer_name']?.toString(),
      appointment['customerName']?.toString(),
      [
        appointment['customer_first_name']?.toString(),
        appointment['customer_last_name']?.toString(),
      ].where((e) => e != null && e.trim().isNotEmpty).join(' '),
      [
        rawCustomer['firstName']?.toString(),
        rawCustomer['lastName']?.toString(),
      ].where((e) => e != null && e.trim().isNotEmpty).join(' '),
    ]);

    final appointmentId = _parseInt(
      appointment['appointmentId'] ??
          appointment['appointment_id'] ??
          appointment['id'],
    );

    final providerId = _parseInt(
      appointment['providerId'] ?? appointment['provider_id'],
    );

    final locationId = _parseInt(
      appointment['locationId'] ?? appointment['location_id'],
    );

    final serviceId = _parseInt(
      appointment['serviceId'] ?? appointment['service_id'],
    );

    final bookingId = _parseInt(
      rawBooking['id'] ?? appointment['bookingId'] ?? appointment['booking_id'],
    );
    final statusNormalized = _firstNonEmpty([
      appointment['status_normalized']?.toString(),
      appointment['statusNormalized']?.toString(),
      _normalizeStatusKey(resolvedStatus),
    ]);
    final statusLifecycle = _firstNonEmpty([
      appointment['status_lifecycle']?.toString(),
      appointment['statusLifecycle']?.toString(),
    ]);
    final statusDisplay = _firstNonEmpty([
      appointment['status_display']?.toString(),
      appointment['statusDisplay']?.toString(),
    ]);
    final isExpiredPending = _readBoolValue(
          appointment['is_expired_pending'] ?? appointment['isExpiredPending'],
        ) ??
        false;

    return {
      ...appointment,
      'status': resolvedStatus ?? '',
      'status_normalized': statusNormalized ?? '',
      'statusNormalized': statusNormalized ?? '',
      'status_lifecycle': statusLifecycle ?? '',
      'statusLifecycle': statusLifecycle ?? '',
      'status_display': statusDisplay ?? '',
      'statusDisplay': statusDisplay ?? '',
      'is_expired_pending': isExpiredPending,
      'isExpiredPending': isExpiredPending,
      'service': serviceName ?? 'Servicio',
      'branch': (locationName != null && locationName.trim().isNotEmpty)
          ? locationName
          : 'Sin sucursal',
      'barber': providerName ?? 'Barbero',
      'bookingStart': bookingStart ?? '',
      'bookingEnd': bookingEnd ?? '',
      'paymentStatus': _firstNonEmpty([
        appointment['payment_status']?.toString(),
        rawPayment['status']?.toString(),
      ]),
      'paymentGateway': _firstNonEmpty([
        appointment['payment_gateway']?.toString(),
        rawPayment['gateway']?.toString(),
      ]),
      'clientName': clientName ?? '-',
      'clientPhone': _firstNonEmpty([
            appointment['customer_phone']?.toString(),
            rawCustomer['phone']?.toString(),
          ]) ??
          '-',
      'clientEmail': _firstNonEmpty([
            appointment['customer_email']?.toString(),
            rawCustomer['email']?.toString(),
          ]) ??
          '-',
      'bookingToken': _firstNonEmpty([
            appointment['booking_token']?.toString(),
            rawBooking['token']?.toString(),
          ]) ??
          '-',
      'locationAddress': _firstNonEmpty([
            appointment['location_address']?.toString(),
            _readNestedString(raw, ['location', 'address']),
          ]) ??
          '-',
      'locationPhone': _firstNonEmpty([
            appointment['location_phone']?.toString(),
            _readNestedString(raw, ['location', 'phone']),
          ]) ??
          '-',
      'appointmentId': appointmentId,
      'appointment_id': appointmentId,
      'bookingId': bookingId,
      'booking_id': bookingId,
      'providerId': providerId,
      'provider_id': providerId,
      'barberId': providerId,
      'locationId': locationId,
      'location_id': locationId,
      'serviceId': serviceId,
      'service_id': serviceId,
      'statusRaw': resolvedStatus ?? '',
      'date': _displayDateFromNormalized(bookingStart),
      'time': _displayTimeFromNormalized(bookingStart),
    };
  }

  String? _readNestedString(Map<String, dynamic> map, List<String> path) {
    dynamic current = map;

    for (final segment in path) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }

    if (current == null) return null;
    final text = current.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final normalized = value.toString().trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;

    return double.tryParse(normalized);
  }

  String? _cleanLocationValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == '-') return null;

    final normalized = text.toLowerCase();
    if (normalized == 'sin sucursal' ||
        normalized == 'sin ubicacion' ||
        normalized == 'sin ubicación') {
      return null;
    }

    return text;
  }

  Future<void> _openAppointmentLocation(
    Map<String, dynamic> appointment,
  ) async {
    final rawLocation = appointment['location'];
    final locationMap = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : <String, dynamic>{};

    final description = _cleanLocationValue(
      _firstNonEmpty([
        appointment['locationDescription']?.toString(),
        appointment['location_description']?.toString(),
        locationMap['description']?.toString(),
      ]),
    );
    final coordinates = LocationLauncherService.extractCoordinatesFromText(
          description,
        ) ??
        LocationLauncherService.extractCoordinatesFromText(
          appointment['locationAddress']?.toString(),
        );
    final latitude = _parseDouble(
          appointment['locationLatitude'] ??
              appointment['location_latitude'] ??
              locationMap['latitude'],
        ) ??
        coordinates?.latitude;
    final longitude = _parseDouble(
          appointment['locationLongitude'] ??
              appointment['location_longitude'] ??
              locationMap['longitude'],
        ) ??
        coordinates?.longitude;
    final address = _cleanLocationValue(
      _firstNonEmpty([
        appointment['locationAddress']?.toString(),
        appointment['location_address']?.toString(),
        locationMap['address']?.toString(),
      ]),
    );
    final branchName = _cleanLocationValue(
      _firstNonEmpty([
        appointment['branch']?.toString(),
        appointment['location_name']?.toString(),
        locationMap['name']?.toString(),
      ]),
    );

    final hasLocation = LocationLauncherService.hasUsableCoordinates(
          latitude,
          longitude,
        ) ||
        address != null ||
        branchName != null ||
        description != null;

    if (!hasLocation) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta cita no tiene ubicación del local.'),
        ),
      );
      return;
    }

    final opened = await LocationLauncherService.openMap(
      address: address,
      latitude: latitude,
      longitude: longitude,
      branchName: branchName,
      description: description,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir Google Maps para esta sucursal.'),
        ),
      );
    }
  }

  bool? _readBoolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return null;

    if (['1', 'true', 'yes', 'si', 'sí'].contains(text)) {
      return true;
    }

    if (['0', 'false', 'no'].contains(text)) {
      return false;
    }

    return null;
  }

  String _normalizeStatusKey(String? status) {
    final value = (status ?? '').trim().toLowerCase();

    switch (value) {
      case 'approved':
      case 'confirmed':
      case 'confirmada':
      case 'confirmado':
      case 'aprobada':
      case 'aprobado':
        return 'confirmed';

      case 'pending':
      case 'pendiente':
      case 'reservada':
      case 'waiting':
        return 'pending';

      case 'expired_pending':
      case 'pendiente_vencida':
      case 'pendiente vencida':
        return 'expired_pending';

      case 'completed':
      case 'completada':
      case 'completado':
        return 'completed';

      case 'canceled':
      case 'cancelled':
      case 'cancelada':
      case 'cancelado':
        return 'canceled';

      case 'rejected':
      case 'rechazada':
      case 'rechazado':
        return 'rejected';

      default:
        return value;
    }
  }

  String _appointmentStatusKey(Map<String, dynamic> appointment) {
    final lifecycle = _firstNonEmpty([
      appointment['status_lifecycle']?.toString(),
      appointment['statusLifecycle']?.toString(),
    ]);
    if (lifecycle != null) {
      return _normalizeStatusKey(lifecycle);
    }

    final expired = _readBoolValue(
      appointment['is_expired_pending'] ?? appointment['isExpiredPending'],
    );
    if (expired == true) {
      return 'expired_pending';
    }

    final normalized = _firstNonEmpty([
      appointment['status_normalized']?.toString(),
      appointment['statusNormalized']?.toString(),
      appointment['status']?.toString(),
    ]);

    final key = _normalizeStatusKey(normalized);
    if (key == 'pending' && _isPastAppointment(appointment)) {
      return 'expired_pending';
    }

    return key;
  }

  DateTime? _resolveAppointmentDate(Map<String, dynamic> appointment) {
    final String bookingStart =
        appointment['booking_start']?.toString().trim() ??
            appointment['bookingStart']?.toString().trim() ??
            '';

    if (bookingStart.isNotEmpty) {
      final parsed = _parseBackendDateTime(bookingStart);
      if (parsed != null) return parsed;
    }

    final timestamp = _parseInt(
      appointment['booking_start_timestamp'] ??
          appointment['bookingStartTimestamp'],
    );
    if (timestamp != null && timestamp > 0) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
    }

    final String dateString = appointment['date']?.toString() ?? '';
    final parsedSpanish = _parseSpanishDate(dateString);
    if (parsedSpanish == null) return null;

    final String timeString = appointment['time']?.toString() ?? '';
    final parsedTime = _parseTime(timeString);

    if (parsedTime == null) {
      return parsedSpanish;
    }

    return DateTime(
      parsedSpanish.year,
      parsedSpanish.month,
      parsedSpanish.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }

  DateTime? _parseBackendDateTime(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;

    try {
      return DateTime.parse(clean).toLocal();
    } catch (_) {}

    try {
      final normalized = clean.replaceFirst(' ', 'T');
      return DateTime.parse(normalized).toLocal();
    } catch (_) {}

    return null;
  }

  DateTime? _parseSpanishDate(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;

    final months = <String, int>{
      'enero': 1,
      'febrero': 2,
      'marzo': 3,
      'abril': 4,
      'mayo': 5,
      'junio': 6,
      'julio': 7,
      'agosto': 8,
      'septiembre': 9,
      'setiembre': 9,
      'octubre': 10,
      'noviembre': 11,
      'diciembre': 12,
    };

    final regex = RegExp(
      r'^(\d{1,2})\s+de\s+([a-zA-ZáéíóúÁÉÍÓÚñÑ]+)\s+de\s+(\d{4})$',
      caseSensitive: false,
    );

    final match = regex.firstMatch(clean);
    if (match == null) return null;

    final day = int.tryParse(match.group(1) ?? '');
    final monthName = (match.group(2) ?? '').toLowerCase();
    final year = int.tryParse(match.group(3) ?? '');
    final month = months[monthName];

    if (day == null || month == null || year == null) return null;

    return DateTime(year, month, day);
  }

  TimeOfDay? _parseTime(String value) {
    final clean = value.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)?$');
    final match = regex.firstMatch(clean);

    if (match == null) return null;

    int hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = match.group(3);

    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _displayDateFromNormalized(String? bookingStart) {
    if (bookingStart == null || bookingStart.trim().isEmpty) {
      return 'Sin fecha';
    }

    final date = _parseBackendDateTime(bookingStart);
    if (date == null) return 'Sin fecha';

    const months = <String>[
      '',
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

    return '${date.day} de ${months[date.month]} de ${date.year}';
  }

  String _displayTimeFromNormalized(String? bookingStart) {
    if (bookingStart == null || bookingStart.trim().isEmpty) {
      return '';
    }

    final date = _parseBackendDateTime(bookingStart);
    if (date == null) return '';

    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<Map<String, dynamic>> _appointmentsByTab(int index) {
    final List<Map<String, dynamic>> filteredByStatus;

    switch (index) {
      case 0:
        filteredByStatus = _allAppointments
            .where(
              (a) => _appointmentStatusKey(a) == 'pending',
            )
            .toList();
        break;
      case 1:
        filteredByStatus = _allAppointments.where(
          (a) {
            final statusKey = _appointmentStatusKey(a);
            return statusKey == 'confirmed' && !_isPastAppointment(a);
          },
        ).toList();
        break;
      case 2:
        filteredByStatus = _allAppointments.where(
          (a) {
            return _isHistoricalAppointment(a);
          },
        ).toList();
        break;
      default:
        filteredByStatus = _allAppointments;
    }

    return filteredByStatus
        .where((appointment) => _matchesSelectedDateFilter(appointment, index))
        .toList(growable: false);
  }

  int _tabCount(int index) => _appointmentsByTab(index).length;

  String _tabTitle(int index) {
    switch (index) {
      case 0:
        return 'Pendientes';
      case 1:
        return 'Confirmadas';
      case 2:
        return 'Historico';
      default:
        return 'Citas';
    }
  }

  String _tabDescription(int index) {
    switch (index) {
      case 0:
        return 'Por aprobar';
      case 1:
        return 'Vigentes';
      case 2:
        return 'Pasadas o cerradas';
      default:
        return 'Tus reservas';
    }
  }

  String _dateFilterLabel(_AppointmentDateFilter filter) {
    switch (filter) {
      case _AppointmentDateFilter.all:
        return 'Todo';
      case _AppointmentDateFilter.today:
        return 'Hoy';
      case _AppointmentDateFilter.sevenDays:
        return '7 días';
      case _AppointmentDateFilter.fifteenDays:
        return '15 días';
      case _AppointmentDateFilter.oneMonth:
        return '1 mes';
    }
  }

  int? _dateFilterWindowDays(_AppointmentDateFilter filter) {
    switch (filter) {
      case _AppointmentDateFilter.all:
        return null;
      case _AppointmentDateFilter.today:
        return 0;
      case _AppointmentDateFilter.sevenDays:
        return 7;
      case _AppointmentDateFilter.fifteenDays:
        return 15;
      case _AppointmentDateFilter.oneMonth:
        return 30;
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _matchesSelectedDateFilter(
    Map<String, dynamic> appointment,
    int tabIndex,
  ) {
    final windowDays = _dateFilterWindowDays(_selectedDateFilter);
    if (windowDays == null) return true;

    final date = _resolveAppointmentDate(appointment);
    if (date == null) return false;

    final today = _dateOnly(DateTime.now());
    final appointmentDate = _dateOnly(date);
    final diffDays = appointmentDate.difference(today).inDays;

    if (windowDays == 0) return diffDays == 0;

    final statusKey = _appointmentStatusKey(appointment);
    final isHistorical = tabIndex == 2 ||
        statusKey == 'completed' ||
        statusKey == 'canceled' ||
        statusKey == 'rejected' ||
        diffDays < 0;

    if (isHistorical) {
      return diffDays <= 0 && diffDays >= -windowDays;
    }

    return diffDays >= 0 && diffDays <= windowDays;
  }

  bool _isHistoricalAppointment(Map<String, dynamic> appointment) {
    final statusKey = _appointmentStatusKey(appointment);
    return statusKey == 'completed' ||
        statusKey == 'canceled' ||
        statusKey == 'rejected' ||
        statusKey == 'expired_pending' ||
        _isPastAppointment(appointment);
  }

  IconData _tabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.hourglass_top_rounded;
      case 1:
        return Icons.event_available_rounded;
      case 2:
        return Icons.event_busy_rounded;
      default:
        return Icons.calendar_month_rounded;
    }
  }

  Color _tabColor(int index) {
    switch (index) {
      case 0:
        return AppColors.warning;
      case 1:
        return AppColors.success;
      case 2:
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  int? _suggestedTabForEmpty(int currentIndex) {
    final preferred = currentIndex == 0
        ? const [1, 2]
        : currentIndex == 1
            ? const [0, 2]
            : const [1, 0];

    for (final index in preferred) {
      if (_tabCount(index) > 0) return index;
    }

    return null;
  }

  void _focusFirstNonEmptyTab() {
    if (!mounted || _didAutoFocusNonEmptyTab || _allAppointments.isEmpty) {
      return;
    }

    _didAutoFocusNonEmptyTab = true;

    final currentIndex = _tabController.index;
    if (_tabCount(currentIndex) > 0) {
      return;
    }

    final suggested = _suggestedTabForEmpty(currentIndex);
    if (suggested != null && suggested != _tabController.index) {
      if (suggested == 2) {
        unawaited(_loadHistoryAppointments());
      }
      _tabController.animateTo(suggested);
    }
  }

  bool _isPastAppointment(Map<String, dynamic> appointment) {
    final date = _resolveAppointmentDate(appointment);
    if (date == null) return false;
    return date.isBefore(DateTime.now());
  }

  Color _statusColorByKey(String statusKey) {
    switch (statusKey) {
      case 'confirmed':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'expired_pending':
        return AppColors.textSecondary;
      case 'completed':
        return AppColors.info;
      case 'rejected':
        return AppColors.dangerDeep;
      case 'canceled':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabelByKey(String statusKey, {String? fallback}) {
    switch (statusKey) {
      case 'confirmed':
        return 'Confirmada';
      case 'pending':
        return 'Pendiente';
      case 'expired_pending':
        return 'Pendiente vencida';
      case 'completed':
        return 'Completada';
      case 'rejected':
        return 'Rechazada';
      case 'canceled':
        return 'Cancelada';
      default:
        final cleanFallback = (fallback ?? '').trim();
        return cleanFallback.isEmpty ? 'Sin estado' : cleanFallback;
    }
  }

  Color _appointmentStatusColor(Map<String, dynamic> appointment) {
    if (_isHistoricalAppointment(appointment) &&
        _appointmentStatusKey(appointment) == 'confirmed') {
      return AppColors.textSecondary;
    }

    return _statusColorByKey(_appointmentStatusKey(appointment));
  }

  String _appointmentStatusLabel(Map<String, dynamic> appointment) {
    if (_isHistoricalAppointment(appointment) &&
        _appointmentStatusKey(appointment) == 'confirmed') {
      return 'Historico';
    }

    final explicitDisplay = _firstNonEmpty([
      appointment['status_display']?.toString(),
      appointment['statusDisplay']?.toString(),
    ]);

    if (explicitDisplay != null) {
      return explicitDisplay;
    }

    return _statusLabelByKey(
      _appointmentStatusKey(appointment),
      fallback: appointment['status']?.toString(),
    );
  }

  String _displayServiceName(Map<String, dynamic> appointment) {
    return appointment['service_name']?.toString() ??
        appointment['service']?.toString() ??
        _readNestedString(appointment, ['service', 'name']) ??
        'Servicio';
  }

  String _displayBarberName(Map<String, dynamic> appointment) {
    return appointment['provider_name']?.toString() ??
        appointment['barber']?.toString() ??
        _readNestedString(appointment, ['provider', 'fullName']) ??
        'Barbero';
  }

  String _displayDate(Map<String, dynamic> appointment) {
    final date = _resolveAppointmentDate(appointment);
    if (date == null) {
      return appointment['date']?.toString() ?? 'Sin fecha';
    }

    const months = <String>[
      '',
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

    return '${date.day} de ${months[date.month]} de ${date.year}';
  }

  String _displayTime(Map<String, dynamic> appointment) {
    final date = _resolveAppointmentDate(appointment);
    if (date == null) {
      return appointment['time']?.toString() ?? '';
    }

    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _goToRebook(Map<String, dynamic> appointment) async {
    final barberId = appointment['provider_id'];
    final serviceId = appointment['service_id'];
    final serviceName = _displayServiceName(appointment);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingsPage(
          service: serviceId != null
              ? {
                  'id': serviceId,
                  'title': serviceName,
                }
              : null,
          selectedBarber: barberId != null
              ? {
                  'id': barberId,
                  'fullName': _displayBarberName(appointment),
                  'locationId': appointment['locationId'],
                }
              : null,
          initialBranch: appointment['branch']?.toString(),
          initialBarber: _displayBarberName(appointment),
        ),
      ),
    );

    if (!mounted) return;
    await _loadAppointments();
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    int? suggestedTabIndex,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HabitoEmptyState(
              icon: icon,
              title: title,
              message: subtitle,
              compact: true,
            ),
            const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (suggestedTabIndex != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      if (suggestedTabIndex == 2) {
                        unawaited(_loadHistoryAppointments());
                      }
                      _tabController.animateTo(suggestedTabIndex);
                    },
                    icon: Icon(_tabIcon(suggestedTabIndex), size: 18),
                    label: Text(
                      'Ver ${_tabTitle(suggestedTabIndex).toLowerCase()} (${_tabCount(suggestedTabIndex)})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRoutes.bookings);
                    if (!mounted) return;
                    await _loadAppointments();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                  ),
                  child: const Text(
                    'Reservar ahora',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final statusColor = _appointmentStatusColor(appointment);
    final statusKey = _appointmentStatusKey(appointment);
    final canRebook = statusKey == 'confirmed';
    final canOpenLocation = canRebook && !_isHistoricalAppointment(appointment);

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentDetailPage(appointment: appointment),
          ),
        );
        if (!mounted) return;
        if (changed == true) {
          await _loadAppointments();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md + AppSpacing.xxs),
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.large,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.panel,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _displayServiceName(appointment),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.title,
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
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: AppRadius.full,
                  ),
                  child: Text(
                    _appointmentStatusLabel(appointment),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: AppTextSize.label,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
            _infoRow(Icons.person_outline, _displayBarberName(appointment)),
            const SizedBox(height: AppSpacing.sm),
            _infoRow(Icons.calendar_today_outlined, _displayDate(appointment)),
            const SizedBox(height: AppSpacing.sm),
            _infoRow(Icons.access_time_outlined, _displayTime(appointment)),
            const SizedBox(height: AppSpacing.lg),
            if (canOpenLocation) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openAppointmentLocation(appointment),
                  icon: const Icon(
                    Icons.directions_rounded,
                    size: AppIconSize.action,
                  ),
                  label: const Text('Cómo llegar al local'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.medium,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: AppTextSize.bodyStrong,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + AppSpacing.xxs),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AppointmentDetailPage(appointment: appointment),
                        ),
                      );
                      if (!mounted) return;
                      if (changed == true) {
                        await _loadAppointments();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldDeep,
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    child: const Text(
                      'Ver detalle',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        canRebook ? () => _goToRebook(appointment) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      disabledBackgroundColor: AppColors.border,
                      foregroundColor: AppColors.primary,
                      disabledForegroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    child: const Text(
                      'Agendar nuevamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: AppTextSize.bodySmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.quantityIcon, color: AppColors.secondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.base,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsOverview() {
    final selectedIndex = _tabController.index;
    const orderedTabs = [1, 0, 2];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.panel,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth >= 560
              ? (constraints.maxWidth - 16) / 3
              : 158.0;

          return SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: orderedTabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, position) {
                final index = orderedTabs[position];
                return _AppointmentStatusSummaryCard(
                  width: itemWidth,
                  title: _tabTitle(index),
                  description: _tabDescription(index),
                  count: _tabCount(index),
                  color: _tabColor(index),
                  selected: selectedIndex == index,
                  loading: index == 2 && _isLoadingHistory,
                  onTap: () {
                    if (index == 2) {
                      unawaited(_loadHistoryAppointments());
                    }
                    _tabController.animateTo(index);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateFilterBar() {
    final filters = _AppointmentDateFilter.values;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs, right: AppSpacing.sm),
            child: Text(
              'Periodo',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.labelSmall,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: filters.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final selected = filter == _selectedDateFilter;

                  return ChoiceChip(
                    showCheckmark: false,
                    selected: selected,
                    label: Text(_dateFilterLabel(filter)),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontSize: AppTextSize.labelSmall,
                      fontWeight: FontWeight.w800,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.full,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedDateFilter = filter;
                      });

                      if (_tabController.index == 2) {
                        unawaited(_loadHistoryAppointments());
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: HabitoLoadingShimmer(
            itemCount: 3,
            itemHeight: 136,
            shrinkWrap: true,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: HabitoErrorState(
            title: 'No se pudieron cargar tus citas',
            message: _error!,
            onRetry: _loadAppointments,
          ),
        ),
      );
    }

    final items = _appointmentsByTab(tabIndex);
    final isFiltered = _selectedDateFilter != _AppointmentDateFilter.all;
    final filterLabel = _dateFilterLabel(_selectedDateFilter).toLowerCase();

    if (items.isEmpty) {
      final suggestedTabIndex = _suggestedTabForEmpty(tabIndex);
      switch (tabIndex) {
        case 0:
          return _buildEmptyState(
            icon: Icons.schedule,
            title: 'No tienes citas pendientes',
            subtitle: suggestedTabIndex != null
                ? 'No hay citas pendientes, pero si tienes reservas en otra categoria.'
                : isFiltered
                    ? 'No hay citas pendientes para $filterLabel.'
                    : 'Cuando hagas una nueva reserva, aparecera aqui.',
            suggestedTabIndex: suggestedTabIndex,
          );
        case 1:
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No tienes citas confirmadas',
            subtitle: suggestedTabIndex != null
                ? 'No hay citas confirmadas ahora. Puedes revisar otra categoria.'
                : isFiltered
                    ? 'No hay citas confirmadas para $filterLabel.'
                    : 'Tus proximas citas confirmadas apareceran aqui.',
            suggestedTabIndex: suggestedTabIndex,
          );
        case 2:
          return _buildEmptyState(
            icon: Icons.cancel_outlined,
            title: 'No tienes citas en historial',
            subtitle: suggestedTabIndex != null
                ? 'No hay citas historicas. Tus citas activas estan en otra categoria.'
                : isFiltered
                    ? 'No hay citas historicas para $filterLabel.'
                    : 'Las citas pasadas o cerradas se mostraran aqui.',
            suggestedTabIndex: suggestedTabIndex,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    return RefreshIndicator(
      color: AppColors.secondary,
      backgroundColor: Colors.white,
      onRefresh: _loadAppointments,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, index) {
          return _buildAppointmentCard(items[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<ShopProvider, int>(
      (provider) => provider.cartCount,
    );

    Future<void> openBooking() async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingsPage()),
      );
      if (!context.mounted) return;
      await _loadAppointments();
    }

    void openProducts() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProductsArchivePage()),
      );
    }

    void openCart() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartPage()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopHeader(
        automaticallyImplyLeading: false,
        titleSpacingOverride: AppSpacing.md,
        searchHint: 'Buscar productos',
        cartCount: cartCount,
        onSearchTap: openProducts,
        onCartTap: openCart,
        titleOverride: _AppointmentReserveButton(onTap: openBooking),
        actionsOverride: [
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.xs),
            child: UnreadNotificationsButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _AppointmentHeaderIconButton(
              icon: Icons.search_rounded,
              tooltip: 'Buscar productos',
              onTap: openProducts,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: _AppointmentCartIconButton(
              cartCount: cartCount,
              onTap: openCart,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAppointmentsOverview(),
          _buildDateFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(0),
                _buildTabContent(1),
                _buildTabContent(2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentStatusSummaryCard extends StatelessWidget {
  final double width;
  final String title;
  final String description;
  final int count;
  final Color color;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _AppointmentStatusSummaryCard({
    required this.width,
    required this.title,
    required this.description,
    required this.count,
    required this.color,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppColors.primary : AppColors.surfaceElevated;
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    final secondary =
        selected ? AppColors.textOnDarkMuted : AppColors.textSecondary;
    final accent = selected ? AppColors.secondary : color;

    return SizedBox(
      width: width,
      child: Material(
        color: background,
        borderRadius: AppRadius.medium,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.medium,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.medium,
              border: Border.all(
                color: selected ? AppColors.secondary : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected ? AppShadows.cardSoft : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: AppTextSize.bodyStrong,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (loading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth:
                              AppSpacing.progressStroke - AppSpacing.xxs / 10,
                          color: accent,
                        ),
                      )
                    else
                      Text(
                        '$count',
                        style: TextStyle(
                          color: accent,
                          fontSize: AppTextSize.titleLarge,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondary,
                    fontSize: AppTextSize.labelSmall,
                    fontWeight: FontWeight.w700,
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

class _AppointmentReserveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AppointmentReserveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppIconSize.headerAction,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.medium,
          ),
        ),
        icon: const Icon(
          Icons.edit_calendar_rounded,
          size: AppIconSize.headerActionIcon,
        ),
        label: const Text(
          'Reservar cita',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: AppTextSize.bodyStrong,
          ),
        ),
      ),
    );
  }
}

class _AppointmentHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _AppointmentHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary,
        borderRadius: AppRadius.tile,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.tile,
          child: SizedBox(
            width: AppIconSize.headerAction,
            height: AppIconSize.headerAction,
            child: Icon(
              icon,
              color: Colors.white,
              size: AppIconSize.headerActionIcon,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCartIconButton extends StatelessWidget {
  final int cartCount;
  final VoidCallback onTap;

  const _AppointmentCartIconButton({
    required this.cartCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Carrito',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.primary,
            borderRadius: AppRadius.tile,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.tile,
              child: SizedBox(
                width: AppIconSize.headerAction,
                height: AppIconSize.headerAction,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: AppIconSize.headerActionIcon,
                ),
              ),
            ),
          ),
          if (cartCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: AppIconSize.notificationBadge,
                  minHeight: AppIconSize.notificationBadge,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  cartCount > 9 ? '9+' : '$cartCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: AppTextSize.captionXs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
