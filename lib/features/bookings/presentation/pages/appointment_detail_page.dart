import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import 'bookings_page.dart';

class AppointmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailPage({
    super.key,
    required this.appointment,
  });

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  Map<String, dynamic> get appointment => widget.appointment;
  bool _isCancelling = false;

  String _normalizeStatusKey(String? status) {
    final value = (status ?? '').trim().toLowerCase();

    switch (value) {
      case 'approved':
      case 'confirmed':
      case 'confirmada':
      case 'aprobada':
      case 'confirmado':
      case 'aprobado':
        return 'confirmada';

      case 'pending':
      case 'pendiente':
        return 'pendiente';

      case 'expired_pending':
      case 'pendiente_vencida':
      case 'pendiente vencida':
        return 'pendiente_vencida';

      case 'canceled':
      case 'cancelled':
      case 'cancelada':
      case 'cancelado':
        return 'cancelada';

      case 'completed':
      case 'completada':
      case 'completado':
        return 'completada';

      case 'rejected':
      case 'rechazada':
      case 'rechazado':
        return 'rechazada';

      case 'paid':
      case 'pagado':
        return 'pagado';

      case 'unpaid':
      case 'no pagado':
      case 'pending payment':
        return 'no_pagado';

      default:
        return value;
    }
  }

  Color _statusBg(String status) {
    switch (_normalizeStatusKey(status)) {
      case 'confirmada':
        return const Color(0xFFE7F6EC);
      case 'pendiente':
        return const Color(0xFFFFF4DD);
      case 'pendiente_vencida':
        return const Color(0xFFF3EFE9);
      case 'cancelada':
        return const Color(0xFFFDE8E8);
      case 'rechazada':
        return const Color(0xFFFDE8E8);
      case 'completada':
        return const Color(0xFFE8F0FD);
      case 'pagado':
        return const Color(0xFFE7F6EC);
      case 'no_pagado':
        return const Color(0xFFFFF4DD);
      default:
        return const Color(0xFFF3EFE9);
    }
  }

  Color _statusText(String status) {
    switch (_normalizeStatusKey(status)) {
      case 'confirmada':
        return const Color(0xFF1F8B4D);
      case 'pendiente':
        return const Color(0xFFB7791F);
      case 'pendiente_vencida':
        return const Color(0xFF6B7280);
      case 'cancelada':
        return const Color(0xFFC53030);
      case 'rechazada':
        return const Color(0xFFB91C1C);
      case 'completada':
        return const Color(0xFF1565C0);
      case 'pagado':
        return const Color(0xFF1F8B4D);
      case 'no_pagado':
        return const Color(0xFFB7791F);
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (_normalizeStatusKey(status)) {
      case 'confirmada':
        return 'Confirmada';
      case 'pendiente':
        return 'Pendiente';
      case 'pendiente_vencida':
        return 'Pendiente vencida';
      case 'cancelada':
        return 'Cancelada';
      case 'rechazada':
        return 'Rechazada';
      case 'completada':
        return 'Completada';
      case 'pagado':
        return 'Pagado';
      case 'no_pagado':
        return 'No pagado';
      default:
        return status.trim().isEmpty ? '-' : status;
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
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

  String _formatBackendDate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';

    final parsed = _parseBackendDateTime(value);
    if (parsed == null) return value;

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

    final weekday = weekdays[parsed.weekday - 1];
    final month = months[parsed.month - 1];

    return '$weekday, ${parsed.day} de $month';
  }

  String _formatBackendTime(String? value) {
    if (value == null || value.trim().isEmpty) return '-';

    final parsed = _parseBackendDateTime(value);
    if (parsed == null) return value;

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatPrice(dynamic value) {
    if (value == null) return '-';

    if (value is num) {
      return '\$${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '-';
    if (text.startsWith('\$')) return text;

    final normalized = text.replaceAll(',', '.');
    final parsed = num.tryParse(normalized);
    if (parsed != null) {
      return '\$${parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 2)}';
    }

    return text;
  }

  List<Map<String, dynamic>> _extractExtras(
    Map<String, dynamic> appointmentMap,
    Map<String, dynamic> bookingMap,
  ) {
    final dynamic rawExtras = (bookingMap['extras'] is List
            ? bookingMap['extras']
            : null) ??
        (appointmentMap['extras'] is List ? appointmentMap['extras'] : null) ??
        (appointmentMap['service_extras'] is List
            ? appointmentMap['service_extras']
            : null) ??
        (appointmentMap['serviceExtras'] is List
            ? appointmentMap['serviceExtras']
            : null);

    if (rawExtras is! List) return <Map<String, dynamic>>[];

    return rawExtras
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  bool _isFutureAppointment(String bookingStart) {
    final parsed = _parseBackendDateTime(bookingStart);
    if (parsed == null) return false;
    return parsed.isAfter(DateTime.now());
  }

  bool? _readBoolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (['1', 'true', 'yes', 'si', 'allowed'].contains(text)) {
      return true;
    }
    if (['0', 'false', 'no', 'denied', 'blocked'].contains(text)) {
      return false;
    }
    return null;
  }

  String _resolveAppointmentStatusKey({
    required Map<String, dynamic> appointmentMap,
    required String status,
    required String bookingStart,
  }) {
    final lifecycle = _firstNonEmpty([
      appointmentMap['status_lifecycle']?.toString(),
      appointmentMap['statusLifecycle']?.toString(),
    ]);
    if (lifecycle != null) {
      return _normalizeStatusKey(lifecycle);
    }

    final explicitExpired = _readBoolValue(
      appointmentMap['is_expired_pending'] ??
          appointmentMap['isExpiredPending'],
    );
    if (explicitExpired == true) {
      return 'pendiente_vencida';
    }

    final key = _normalizeStatusKey(status);
    if (key == 'pendiente' &&
        bookingStart.trim().isNotEmpty &&
        !_isFutureAppointment(bookingStart)) {
      return 'pendiente_vencida';
    }

    return key;
  }

  bool _canCancelAppointment({
    required Map<String, dynamic> appointmentMap,
    required Map<String, dynamic> bookingMap,
    required String statusKey,
    required String bookingStart,
  }) {
    if (statusKey == 'cancelada' ||
        statusKey == 'rechazada' ||
        statusKey == 'completada' ||
        statusKey == 'pendiente_vencida' ||
        !_isFutureAppointment(bookingStart)) {
      return false;
    }

    for (final key in const [
      'can_cancel',
      'canCancel',
      'cancelable',
      'is_cancelable',
      'isCancelable',
      'cancellation_available',
      'cancellationAvailable',
      'within_cancellation_window',
      'withinCancellationWindow',
    ]) {
      final explicit = _readBoolValue(appointmentMap[key]) ??
          _readBoolValue(bookingMap[key]);
      if (explicit != null) return explicit;
    }

    final cancelWindowText = _firstNonEmpty([
      appointmentMap['cancel_window']?.toString(),
      appointmentMap['cancelWindow']?.toString(),
      appointmentMap['cancel_status']?.toString(),
      appointmentMap['cancelStatus']?.toString(),
      bookingMap['cancel_window']?.toString(),
      bookingMap['cancelWindow']?.toString(),
    ])?.toLowerCase();

    if (cancelWindowText != null &&
        (cancelWindowText.contains('fuera') ||
            cancelWindowText.contains('outside') ||
            cancelWindowText.contains('expired'))) {
      return false;
    }

    final cutoff = _firstNonEmpty([
      appointmentMap['cancel_until']?.toString(),
      appointmentMap['cancelUntil']?.toString(),
      appointmentMap['cancel_before']?.toString(),
      appointmentMap['cancelBefore']?.toString(),
      appointmentMap['cancellation_deadline']?.toString(),
      appointmentMap['cancellationDeadline']?.toString(),
      bookingMap['cancel_until']?.toString(),
      bookingMap['cancelUntil']?.toString(),
      bookingMap['cancel_before']?.toString(),
      bookingMap['cancelBefore']?.toString(),
    ]);

    if (cutoff != null) {
      final parsedCutoff = _parseBackendDateTime(cutoff);
      if (parsedCutoff != null && DateTime.now().isAfter(parsedCutoff)) {
        return false;
      }
    }

    return true;
  }

  String? _cancelUnavailableReason({
    required String statusKey,
    required String bookingStart,
  }) {
    if (statusKey == 'cancelada') return 'La cita ya esta cancelada.';
    if (statusKey == 'rechazada') {
      return 'La cita fue rechazada y ya no se puede gestionar.';
    }
    if (statusKey == 'completada') return 'La cita ya fue completada.';
    if (statusKey == 'pendiente_vencida') {
      return 'La solicitud vencio porque la fecha de la cita ya paso.';
    }
    if (!_isFutureAppointment(bookingStart)) {
      return 'Fuera de ventana para cancelar.';
    }
    return null;
  }

  Future<void> _cancelAppointment({
    required int? bookingId,
    required bool canCancel,
  }) async {
    if (!canCancel) return;

    if (bookingId == null || bookingId <= 0) {
      _showMessage(context, 'No pudimos identificar la reserva para cancelar.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final token = auth.token?.trim();
    if (!auth.isLoggedIn || token == null || token.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text(
          'Esta accion cancelara tu cita. Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Si, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      setState(() {
        _isCancelling = true;
      });

      await HabitoBookingApi.cancelBooking(
        bookingId: bookingId,
        authToken: token,
      );

      if (!mounted) return;
      _showMessage(context, 'Cita cancelada correctamente.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        context,
        'No se pudo cancelar la cita: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2B2118),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointmentMap = appointment;
    final bookingMap = _asMap(appointmentMap['booking']);
    final serviceMap = _asMap(appointmentMap['service']);
    final providerMap = _asMap(appointmentMap['provider']);
    final locationMap = _asMap(appointmentMap['location']);

    final String service = _firstNonEmpty([
          appointmentMap['service'] is String
              ? appointmentMap['service']?.toString()
              : null,
          appointmentMap['service_name']?.toString(),
          serviceMap['name']?.toString(),
        ]) ??
        '-';

    final String branch = _firstNonEmpty([
          appointmentMap['branch']?.toString(),
          appointmentMap['location_name']?.toString(),
          locationMap['name']?.toString(),
        ]) ??
        'Sin sucursal';

    final String barber = _firstNonEmpty([
          appointmentMap['barber']?.toString(),
          appointmentMap['provider_name']?.toString(),
          providerMap['fullName']?.toString(),
          [
            providerMap['firstName']?.toString(),
            providerMap['lastName']?.toString(),
          ].where((e) => e != null && e.trim().isNotEmpty).join(' '),
        ]) ??
        '-';

    final String status = _firstNonEmpty([
          appointmentMap['status_normalized']?.toString(),
          appointmentMap['statusNormalized']?.toString(),
          appointmentMap['status']?.toString(),
          bookingMap['status']?.toString(),
        ]) ??
        '';

    final String paymentStatus = _firstNonEmpty([
          appointmentMap['paymentStatus']?.toString(),
          appointmentMap['payment_status']?.toString(),
          appointmentMap['booking_status']?.toString(),
          bookingMap['paymentStatus']?.toString(),
        ]) ??
        '';

    final String clientName = _firstNonEmpty([
          appointmentMap['clientName']?.toString(),
          appointmentMap['customer_name']?.toString(),
        ]) ??
        '-';

    final String clientPhone = _firstNonEmpty([
          appointmentMap['clientPhone']?.toString(),
          appointmentMap['customer_phone']?.toString(),
        ]) ??
        '-';

    final String clientEmail = _firstNonEmpty([
          appointmentMap['clientEmail']?.toString(),
          appointmentMap['customer_email']?.toString(),
        ]) ??
        '-';

    final String bookingToken = _firstNonEmpty([
          appointmentMap['bookingToken']?.toString(),
          appointmentMap['booking_token']?.toString(),
        ]) ??
        '-';

    final String locationAddress = _firstNonEmpty([
          appointmentMap['locationAddress']?.toString(),
          appointmentMap['location_address']?.toString(),
          locationMap['address']?.toString(),
        ]) ??
        '-';

    final String locationPhone = _firstNonEmpty([
          appointmentMap['locationPhone']?.toString(),
          appointmentMap['location_phone']?.toString(),
          locationMap['phone']?.toString(),
        ]) ??
        '-';

    final String paymentGateway = _firstNonEmpty([
          appointmentMap['paymentGateway']?.toString(),
          appointmentMap['payment_gateway']?.toString(),
        ]) ??
        '-';

    final String reservationCode = _firstNonEmpty([
          appointmentMap['appointmentId']?.toString(),
          appointmentMap['appointment_id']?.toString(),
          appointmentMap['id']?.toString(),
        ]) ??
        '-';

    final String bookingStart = _firstNonEmpty([
          appointmentMap['bookingStart']?.toString(),
          appointmentMap['booking_start']?.toString(),
        ]) ??
        '';

    final String bookingEnd = _firstNonEmpty([
          appointmentMap['bookingEnd']?.toString(),
          appointmentMap['booking_end']?.toString(),
        ]) ??
        '';

    final String date =
        bookingStart.isNotEmpty ? _formatBackendDate(bookingStart) : '-';

    final String time =
        bookingStart.isNotEmpty ? _formatBackendTime(bookingStart) : '-';

    final String endTime =
        bookingEnd.isNotEmpty ? _formatBackendTime(bookingEnd) : '-';

    final String priceText = _formatPrice(
      bookingMap['totalPrice'] ??
          bookingMap['price'] ??
          appointmentMap['price'] ??
          appointmentMap['service_price'] ??
          serviceMap['price'],
    );

    final int? providerId = _asInt(
      appointmentMap['providerId'] ??
          appointmentMap['provider_id'] ??
          providerMap['id'],
    );

    final int? locationId = _asInt(
      appointmentMap['locationId'] ??
          appointmentMap['location_id'] ??
          locationMap['id'],
    );

    final int? serviceId = _asInt(
      appointmentMap['serviceId'] ??
          appointmentMap['service_id'] ??
          serviceMap['id'],
    );
    final int? bookingId = _asInt(
      appointmentMap['bookingId'] ??
          appointmentMap['booking_id'] ??
          bookingMap['id'],
    );
    final normalizedStatus = _resolveAppointmentStatusKey(
      appointmentMap: appointmentMap,
      status: status,
      bookingStart: bookingStart,
    );
    final statusLabel = _firstNonEmpty([
          appointmentMap['status_display']?.toString(),
          appointmentMap['statusDisplay']?.toString(),
        ]) ??
        _statusLabel(normalizedStatus);
    final canRebook = normalizedStatus == 'confirmada';
    final canCancel = _canCancelAppointment(
      appointmentMap: appointmentMap,
      bookingMap: bookingMap,
      statusKey: normalizedStatus,
      bookingStart: bookingStart,
    );
    final cancelUnavailableReason = _cancelUnavailableReason(
          statusKey: normalizedStatus,
          bookingStart: bookingStart,
        ) ??
        (!canCancel ? 'Fuera de ventana para cancelar.' : null);

    final extras = _extractExtras(appointmentMap, bookingMap);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F1),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Detalle de cita',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: canRebook
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingsPage(
                                service: serviceId != null
                                    ? {
                                        'id': serviceId,
                                        'title': service,
                                      }
                                    : null,
                                selectedBarber: providerId != null
                                    ? {
                                        'id': providerId,
                                        'fullName': barber,
                                        'locationId': locationId,
                                      }
                                    : null,
                                initialBranch: branch,
                                initialBarber: barber,
                              ),
                            ),
                          );
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    foregroundColor: const Color(0xFF9C7732),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Agendar nuevamente',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canCancel && !_isCancelling
                      ? () => _cancelAppointment(
                            bookingId: bookingId,
                            canCancel: canCancel,
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    disabledBackgroundColor: const Color(0xFFE7DFD4),
                    foregroundColor: AppColors.primary,
                    disabledForegroundColor: const Color(0xFF9E9E9E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Text(
                          'Cancelar cita',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              if (!canCancel && cancelUnavailableReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  cancelUnavailableReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.content_cut,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reserva #$reservationCode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Sucursal',
                  value: branch,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Barbero',
                  value: barber,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Fecha',
                  value: date,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Hora',
                  value: endTime != '-' ? '$time - $endTime' : time,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Precio',
                  value: priceText,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Color(0xFF9C7732),
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 86,
                      child: Text(
                        'Estado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBg(normalizedStatus),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: _statusText(normalizedStatus),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: Color(0xFF9C7732),
                    ),
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 86,
                      child: Text(
                        'Pago',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBg(paymentStatus),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _statusLabel(paymentStatus),
                            style: TextStyle(
                              color: _statusText(paymentStatus),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_2_outlined,
                  label: 'Cliente',
                  value: clientName,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Celular',
                  value: clientPhone,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Correo',
                  value: clientEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (extras.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Extras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...extras.map(
                    (extra) {
                      final extraName = _firstNonEmpty([
                            extra['name']?.toString(),
                            extra['extraId']?.toString(),
                            extra['extra_id']?.toString(),
                            extra['id']?.toString(),
                          ]) ??
                          'Extra';
                      final quantity = _asInt(extra['quantity']) ?? 1;
                      final totalPrice = _formatPrice(
                        extra['totalPrice'] ??
                            extra['total_price'] ??
                            extra['price'],
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                              color: Color(0xFF9C7732),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                quantity > 1
                                    ? '$extraName x$quantity'
                                    : extraName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              totalPrice,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          if (extras.isNotEmpty) const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Dirección',
                  value: locationAddress,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.call_outlined,
                  label: 'Teléfono',
                  value: locationPhone,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.qr_code_rounded,
                  label: 'Token',
                  value: bookingToken,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.credit_card_outlined,
                  label: 'Método',
                  value: paymentGateway,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9C7732)),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
