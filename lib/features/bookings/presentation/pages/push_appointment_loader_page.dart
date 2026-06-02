import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../auth/provider/auth_provider.dart';
import '../../../shop/data/services/habito_booking_api.dart';
import 'appointment_detail_page.dart';

class PushAppointmentLoaderPage extends StatefulWidget {
  final int? appointmentId;
  final int? bookingId;

  const PushAppointmentLoaderPage({
    super.key,
    this.appointmentId,
    this.bookingId,
  });

  @override
  State<PushAppointmentLoaderPage> createState() =>
      _PushAppointmentLoaderPageState();
}

class _PushAppointmentLoaderPageState extends State<PushAppointmentLoaderPage> {
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAppointment());
  }

  Future<void> _openAppointment() async {
    final auth = context.read<AuthProvider>();

    if (!auth.isLoggedIn && !auth.isInitialized) {
      await auth.init();
    }

    if (!mounted) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.trim().isEmpty) {
      await _redirectToMyAppointmentsLoginFlow();
      return;
    }

    try {
      final response = await HabitoBookingApi.getMyBooking(
        token: token,
        appointmentId: widget.appointmentId,
        bookingId: widget.bookingId,
      );

      final item = response['item'];
      if (!mounted) return;

      if (item is! Map) {
        throw Exception('No encontramos la cita solicitada.');
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppointmentDetailPage(
            appointment: Map<String, dynamic>.from(item),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'No pudimos abrir el detalle de la cita desde la notificación.';
      });
    }
  }

  Future<void> _redirectToMyAppointmentsLoginFlow() async {
    if (!mounted) return;

    await Navigator.of(context).pushNamed(AppRoutes.login);

    if (!mounted) return;

    if (!context.read<AuthProvider>().isLoggedIn) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.main,
        (route) => false,
        arguments: {'initialIndex': 0},
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.main,
      (route) => false,
      arguments: {
        'initialIndex': 2,
        'myAppointmentsArguments': {
          'appointmentId': widget.appointmentId,
          'bookingId': widget.bookingId,
          'openFromPush': true,
          'refreshMyBookings': true,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Abriendo cita',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error == null) ...[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Estamos abriendo el detalle de tu cita...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppTextSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryMuted,
                  ),
                ),
              ] else ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTextSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryMuted,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _redirectToMyAppointmentsLoginFlow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Ir a Mis citas',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
