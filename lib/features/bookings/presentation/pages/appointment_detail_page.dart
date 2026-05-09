import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/friendly_errors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icon_size.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_top_header.dart';
import '../../../../shared/widgets/habito_payment_proof_picker.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import '../../../shop/presentation/pages/cart_page.dart';
import '../../../shop/presentation/pages/products_archive_page.dart';
import '../../../shop/provider/shop_provider.dart';
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
  bool _isUploadingProof = false;
  Map<String, dynamic>? _paymentProofOverride;

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
        return AppColors.successSoft;
      case 'pendiente':
        return AppColors.warningSoft;
      case 'pendiente_vencida':
        return AppColors.surfaceMuted;
      case 'cancelada':
        return AppColors.dangerSoft;
      case 'rechazada':
        return AppColors.dangerSoft;
      case 'completada':
        return AppColors.infoSoft;
      case 'pagado':
        return AppColors.successSoft;
      case 'no_pagado':
        return AppColors.warningSoft;
      default:
        return AppColors.surfaceMuted;
    }
  }

  Color _statusText(String status) {
    switch (_normalizeStatusKey(status)) {
      case 'confirmada':
        return AppColors.success;
      case 'pendiente':
        return AppColors.warningDeep;
      case 'pendiente_vencida':
        return AppColors.textSecondary;
      case 'cancelada':
        return AppColors.danger;
      case 'rechazada':
        return AppColors.dangerDeep;
      case 'completada':
        return AppColors.info;
      case 'pagado':
        return AppColors.success;
      case 'no_pagado':
        return AppColors.warningDeep;
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

  int? _findIntByKeys(
    dynamic value,
    Set<String> keys, {
    int depth = 0,
  }) {
    if (depth > 8) return null;

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final entry in map.entries) {
        if (keys.contains(entry.key)) {
          final parsed = _asInt(entry.value);
          if (parsed != null && parsed > 0) return parsed;
        }
      }

      for (final entry in map.entries) {
        final found = _findIntByKeys(entry.value, keys, depth: depth + 1);
        if (found != null && found > 0) return found;
      }
    }

    if (value is List) {
      for (final item in value) {
        final found = _findIntByKeys(item, keys, depth: depth + 1);
        if (found != null && found > 0) return found;
      }
    }

    return null;
  }

  Map<String, dynamic> _findMapByKeys(
    dynamic value,
    Set<String> keys, {
    int depth = 0,
  }) {
    if (depth > 8) return <String, dynamic>{};

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final entry in map.entries) {
        if (keys.contains(entry.key) && entry.value is Map) {
          return Map<String, dynamic>.from(entry.value as Map);
        }
      }

      for (final entry in map.entries) {
        final found = _findMapByKeys(entry.value, keys, depth: depth + 1);
        if (found.isNotEmpty) return found;
      }
    }

    if (value is List) {
      for (final item in value) {
        final found = _findMapByKeys(item, keys, depth: depth + 1);
        if (found.isNotEmpty) return found;
      }
    }

    return <String, dynamic>{};
  }

  String _formatPaymentMethod(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '-') return 'On-site (pagar en el sitio)';

    final lower = text.toLowerCase();
    if (lower == 'bacs' || lower.contains('transfer')) {
      return 'Transferencia';
    }
    if (lower == 'cod' ||
        lower == 'on_site' ||
        lower == 'onsite' ||
        lower.contains('on-site') ||
        lower.contains('sitio') ||
        lower.contains('barberia') ||
        lower.contains('barbería') ||
        lower.contains('local') ||
        lower.contains('contra entrega')) {
      return 'On-site (pagar en el sitio)';
    }
    if (lower.contains('point') || lower.contains('punto')) {
      return 'Puntos Habito';
    }
    if (lower.contains('cash') || lower.contains('efectivo')) {
      return 'Efectivo';
    }
    if (lower.contains('card') ||
        lower.contains('tarjeta') ||
        lower.contains('credito') ||
        lower.contains('crédito')) {
      return 'Tarjeta';
    }

    return text;
  }

  bool _isBankTransferPayment(String value) {
    final lower = value.trim().toLowerCase();
    return lower == 'bacs' ||
        lower.contains('transfer') ||
        lower.contains('transferencia');
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
    if (statusKey == 'cancelada') return 'La cita ya está cancelada.';
    if (statusKey == 'rechazada') {
      return 'La cita fue rechazada y ya no se puede gestionar.';
    }
    if (statusKey == 'completada') return 'La cita ya fue completada.';
    if (statusKey == 'pendiente_vencida') {
      return 'La solicitud venció porque la fecha de la cita ya pasó.';
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
          'Esta acción cancelará tu cita. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
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
        FriendlyErrors.cancelAppointment(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  Future<void> _openRescheduleFlow({
    required int? appointmentId,
    required int? serviceId,
    required String serviceName,
    required int? providerId,
    required String barberName,
    required int? locationId,
    required String branchName,
    required String bookingStart,
  }) async {
    if (appointmentId == null || appointmentId <= 0) {
      _showMessage(context, 'No pudimos identificar la cita para reagendar.');
      return;
    }

    final parsedStart = _parseBackendDateTime(bookingStart);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingsPage(
          appointmentId: appointmentId.toString(),
          service: serviceId != null
              ? {
                  'id': serviceId,
                  'title': serviceName,
                }
              : null,
          selectedBarber: providerId != null
              ? {
                  'id': providerId,
                  'fullName': barberName,
                  'locationId': locationId,
                }
              : null,
          initialBranch: branchName,
          initialBarber: barberName,
          initialDate: parsedStart == null
              ? null
              : DateTime(parsedStart.year, parsedStart.month, parsedStart.day),
          initialTime:
              parsedStart == null ? null : _formatBackendTime(bookingStart),
        ),
      ),
    );

    if (!mounted) return;
    if (changed == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _selectAndUploadPaymentProof(int orderId) async {
    final auth = context.read<AuthProvider>();
    final token = auth.token?.trim();

    if (!auth.isLoggedIn || token == null || token.isEmpty || orderId <= 0) {
      _showMessage(
        context,
        'No pudimos identificar el pedido para adjuntar el comprobante.',
      );
      return;
    }

    final selectedProof = await HabitoPaymentProofPicker.pickAndConfirm(
      context,
      showMessage: (message) => _showMessage(context, message),
    );

    if (selectedProof == null || !mounted) return;

    setState(() {
      _isUploadingProof = true;
    });

    try {
      final shop = context.read<ShopProvider>();
      final ok = await shop.uploadPaymentProof(
        token: token,
        orderId: orderId,
        filePath: selectedProof.path,
      );

      if (!mounted) return;

      if (ok) {
        final updatedOrder = shop.orders.firstWhere(
          (order) => _asInt(order['id']) == orderId,
          orElse: () => <String, dynamic>{},
        );

        setState(() {
          _paymentProofOverride = _asMap(
            updatedOrder['payment_proof'] ?? updatedOrder['paymentProof'],
          );
        });

        _showMessage(
            context, 'Comprobante recibido. Lo validaremos muy pronto.');
        return;
      }

      _showMessage(
        context,
        FriendlyErrors.paymentProof(
          shop.paymentProofError ?? 'No pudimos subir el comprobante.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        context,
        FriendlyErrors.paymentProof(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProof = false;
        });
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primarySoft,
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
          appointmentMap['habitoPaymentTitle']?.toString(),
          appointmentMap['habito_payment_title']?.toString(),
          appointmentMap['paymentTitle']?.toString(),
          appointmentMap['payment_title']?.toString(),
          appointmentMap['paymentMethodTitle']?.toString(),
          appointmentMap['payment_method_title']?.toString(),
          appointmentMap['habitoPaymentMethod']?.toString(),
          appointmentMap['habito_payment_method']?.toString(),
          appointmentMap['paymentMethod']?.toString(),
          appointmentMap['payment_method']?.toString(),
          appointmentMap['paymentGateway']?.toString(),
          appointmentMap['payment_gateway']?.toString(),
          bookingMap['paymentTitle']?.toString(),
          bookingMap['payment_title']?.toString(),
          bookingMap['habitoPaymentMethod']?.toString(),
          bookingMap['habito_payment_method']?.toString(),
          bookingMap['paymentMethod']?.toString(),
          bookingMap['payment_method']?.toString(),
        ]) ??
        '-';
    final String paymentMethodDisplay = _formatPaymentMethod(paymentGateway);
    final bool isBankTransfer = _isBankTransferPayment(paymentGateway);
    final int? paymentOrderId = _findIntByKeys(
      appointmentMap,
      const {
        'orderId',
        'order_id',
        'wooOrderId',
        'woo_order_id',
        'woocommerceOrderId',
        'woocommerce_order_id',
        'wcOrderId',
        'wc_order_id',
        'paymentOrderId',
        'payment_order_id',
        'shopOrderId',
        'shop_order_id',
      },
    );
    final paymentProof = _paymentProofOverride?.isNotEmpty == true
        ? _paymentProofOverride!
        : _findMapByKeys(
            appointmentMap,
            const {
              'paymentProof',
              'payment_proof',
              'proof',
              'transferProof',
              'transfer_proof',
            },
          );
    final proofUrl = (paymentProof['url'] ?? '').toString().trim();
    final proofUploaded =
        paymentProof['uploaded'] == true || proofUrl.isNotEmpty;
    final proofUploadedAt =
        (paymentProof['uploaded_at'] ?? paymentProof['uploadedAt'] ?? '')
            .toString();
    final int? appointmentId = _asInt(
      appointmentMap['appointmentId'] ??
          appointmentMap['appointment_id'] ??
          appointmentMap['id'],
    );

    final String reservationCode = _firstNonEmpty([
          appointmentId?.toString(),
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
    final isPendingAppointment = normalizedStatus == 'pendiente';
    final canUploadPaymentProof = isBankTransfer &&
        !proofUploaded &&
        isPendingAppointment &&
        paymentOrderId != null &&
        paymentOrderId > 0 &&
        !const {'cancelada', 'rechazada', 'completada'}
            .contains(normalizedStatus);
    final shouldShowPaymentProofPanel =
        isBankTransfer && (proofUploaded || isPendingAppointment);

    final extras = _extractExtras(appointmentMap, bookingMap);
    final cartCount = context.select<ShopProvider, int>(
      (provider) => provider.cartCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopHeader(
        compactSearch: true,
        searchHint: 'Buscar productos',
        cartCount: cartCount,
        leadingIcon: Icons.arrow_back_rounded,
        leadingTooltip: 'Volver',
        onLeadingTap: () => Navigator.maybePop(context),
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
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (canCancel) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openRescheduleFlow(
                          appointmentId: appointmentId,
                          serviceId: serviceId,
                          serviceName: service,
                          providerId: providerId,
                          barberName: barber,
                          locationId: locationId,
                          branchName: branch,
                          bookingStart: bookingStart,
                        ),
                        icon: const Icon(Icons.edit_calendar_rounded),
                        label: const Text('Reagendar'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.secondary),
                          foregroundColor: AppColors.goldDeep,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.tile,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: canCancel && !_isCancelling
                          ? () => _cancelAppointment(
                                bookingId: bookingId,
                                canCancel: canCancel,
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        disabledBackgroundColor: AppColors.border,
                        foregroundColor: AppColors.primary,
                        disabledForegroundColor: AppColors.textMuted,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.tile,
                        ),
                      ),
                      child: _isCancelling
                          ? const SizedBox(
                              width: AppIconSize.action,
                              height: AppIconSize.action,
                              child: CircularProgressIndicator(
                                strokeWidth: AppSpacing.progressStroke,
                                color: AppColors.primary,
                              ),
                            )
                          : const Text(
                              'Cancelar cita',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
              if (!canCancel && cancelUnavailableReason != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  cancelUnavailableReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppTextSize.bodySmall,
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
              borderRadius: AppRadius.extraLarge,
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: AppRadius.large,
                  ),
                  child: const Icon(
                    Icons.content_cut,
                    color: Colors.white,
                    size: AppIconSize.lg,
                  ),
                ),
                const SizedBox(width: AppSpacing.md + AppSpacing.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.headlineSmall,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs + AppSpacing.xxs),
                      Text(
                        'Reserva #$reservationCode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: AppTextSize.bodyStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.extraLarge,
              boxShadow: AppShadows.panel,
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Sucursal',
                  value: branch,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Barbero',
                  value: barber,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Fecha',
                  value: date,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: 'Hora',
                  value: endTime != '-' ? '$time - $endTime' : time,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Precio',
                  value: priceText,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: AppIconSize.spinner,
                      color: AppColors.goldDeep,
                    ),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    const SizedBox(
                      width: 86,
                      child: Text(
                        'Estado',
                        style: TextStyle(
                          fontSize: AppTextSize.base,
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
                            borderRadius: AppRadius.full,
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: _statusText(normalizedStatus),
                              fontSize: AppTextSize.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: AppIconSize.spinner,
                      color: AppColors.goldDeep,
                    ),
                    const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
                    const SizedBox(
                      width: 86,
                      child: Text(
                        'Pago',
                        style: TextStyle(
                          fontSize: AppTextSize.base,
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
                            borderRadius: AppRadius.full,
                          ),
                          child: Text(
                            _statusLabel(paymentStatus),
                            style: TextStyle(
                              color: _statusText(paymentStatus),
                              fontSize: AppTextSize.label,
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
          const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.extraLarge,
              boxShadow: AppShadows.panel,
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.person_2_outlined,
                  label: 'Cliente',
                  value: clientName,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Celular',
                  value: clientPhone,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Correo',
                  value: clientEmail,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
          if (extras.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.extraLarge,
                boxShadow: AppShadows.panel,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Extras',
                    style: TextStyle(
                      fontSize: AppTextSize.titleMedium,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
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
                              size: AppIconSize.action,
                              color: AppColors.goldDeep,
                            ),
                            const SizedBox(
                                width: AppSpacing.sm + AppSpacing.xxs),
                            Expanded(
                              child: Text(
                                quantity > 1
                                    ? '$extraName x$quantity'
                                    : extraName,
                                style: const TextStyle(
                                  fontSize: AppTextSize.baseLarge,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              totalPrice,
                              style: const TextStyle(
                                fontSize: AppTextSize.base,
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
          if (extras.isNotEmpty)
            const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.extraLarge,
              boxShadow: AppShadows.panel,
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.store_mall_directory_outlined,
                  label: 'Dirección',
                  value: locationAddress,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.call_outlined,
                  label: 'Teléfono',
                  value: locationPhone,
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                _DetailRow(
                  icon: Icons.credit_card_outlined,
                  label: 'Forma de pago',
                  value: paymentMethodDisplay,
                ),
                if (shouldShowPaymentProofPanel) ...[
                  const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
                  _AppointmentPaymentProofPanel(
                    uploaded: proofUploaded,
                    uploadedAt: proofUploadedAt,
                    isUploading: _isUploadingProof,
                    canUpload: canUploadPaymentProof,
                    hasLinkedOrder:
                        paymentOrderId != null && paymentOrderId > 0,
                    onUpload: paymentOrderId != null
                        ? () => _selectAndUploadPaymentProof(paymentOrderId)
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
        Icon(icon, size: AppIconSize.spinner, color: AppColors.goldDeep),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppTextSize.base,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: AppTextSize.baseLarge,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentPaymentProofPanel extends StatelessWidget {
  final bool uploaded;
  final String uploadedAt;
  final bool isUploading;
  final bool canUpload;
  final bool hasLinkedOrder;
  final VoidCallback? onUpload;

  const _AppointmentPaymentProofPanel({
    required this.uploaded,
    required this.uploadedAt,
    required this.isUploading,
    required this.canUpload,
    required this.hasLinkedOrder,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = uploaded ? AppColors.success : AppColors.goldDeep;
    final title =
        uploaded ? 'Comprobante recibido' : 'Comprobante de transferencia';
    final description = uploaded
        ? 'Tu comprobante quedó adjunto para validación.'
        : hasLinkedOrder
            ? 'Sube una foto clara del pago para confirmar la transferencia.'
            : 'La cita aún no tiene un pedido vinculado para adjuntar el comprobante.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.large,
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                uploaded
                    ? Icons.check_circle_outline_rounded
                    : Icons.upload_file_rounded,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (uploaded && uploadedAt.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        uploadedAt.split(' ').first,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!uploaded) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppIconSize.xl + AppSpacing.sm + AppSpacing.xxs,
              child: ElevatedButton.icon(
                onPressed: canUpload && !isUploading ? onUpload : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.medium,
                  ),
                ),
                icon: isUploading
                    ? const SizedBox(
                        width: AppIconSize.quantityIcon,
                        height: AppIconSize.quantityIcon,
                        child: CircularProgressIndicator(
                          strokeWidth:
                              AppSpacing.progressStroke - AppSpacing.xxs / 10,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.add_photo_alternate_outlined,
                        size: AppIconSize.sm + AppSpacing.xxs / 2,
                      ),
                label: Text(
                  isUploading ? 'Subiendo...' : 'Subir comprobante',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
