import 'dart:convert';
import 'package:http/http.dart' as http;

class BookingService {
  BookingService({required this.baseUrl, this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String? authToken;
  final http.Client _client;

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (authToken != null && authToken!.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<List<BookingModel>> getAppointments({
    required String customerId,
    String? status,
  }) async {
    final response = await _client.get(
      _uri('/reservas/mis-citas', {
        'customer_id': customerId,
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      headers: _headers,
    );

    _ensureSuccess(response);

    final data = jsonDecode(response.body);

    if (data is List) {
      return data
          .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (data is Map<String, dynamic> && data['data'] is List) {
      return (data['data'] as List)
          .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw const BookingException('Formato inesperado al obtener citas.');
  }

  Future<BookingModel> createAppointment({
    required CreateBookingRequest request,
  }) async {
    final response = await _client.post(
      _uri('/reservas/crear'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );

    _ensureSuccess(response);

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      return BookingModel.fromJson(payload);
    }

    throw const BookingException('Formato inesperado al crear la cita.');
  }

  Future<BookingModel> cancelAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    final response = await _client.post(
      _uri('/reservas/cancelar'),
      headers: _headers,
      body: jsonEncode({
        'appointment_id': appointmentId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );

    _ensureSuccess(response);

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      return BookingModel.fromJson(payload);
    }

    throw const BookingException('Formato inesperado al cancelar la cita.');
  }

  Future<BookingModel> rescheduleAppointment({
    required RescheduleBookingRequest request,
  }) async {
    final response = await _client.post(
      _uri('/reservas/reagendar'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );

    _ensureSuccess(response);

    final data = jsonDecode(response.body);

    if (data is Map<String, dynamic>) {
      final payload = data['data'] is Map<String, dynamic>
          ? data['data'] as Map<String, dynamic>
          : data;
      return BookingModel.fromJson(payload);
    }

    throw const BookingException('Formato inesperado al reagendar la cita.');
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Error de servidor (${response.statusCode}).';

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        message =
            data['message']?.toString() ?? data['error']?.toString() ?? message;
      }
    } catch (_) {}

    throw BookingException(message, statusCode: response.statusCode);
  }

  void dispose() {
    _client.close();
  }
}

class BookingModel {
  const BookingModel({
    required this.id,
    required this.service,
    required this.branch,
    required this.barber,
    required this.date,
    required this.time,
    required this.status,
    this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.price,
  });

  final String id;
  final String service;
  final String branch;
  final String barber;
  final String date;
  final String time;
  final String status;
  final String? clientName;
  final String? clientPhone;
  final String? clientEmail;
  final String? price;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id']?.toString() ?? '',
      service:
          json['service']?.toString() ?? json['service_name']?.toString() ?? '',
      branch: json['branch']?.toString() ?? json['location']?.toString() ?? '',
      barber: json['barber']?.toString() ?? json['employee']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pendiente',
      clientName: json['client_name']?.toString(),
      clientPhone: json['client_phone']?.toString(),
      clientEmail: json['client_email']?.toString(),
      price: json['price']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service': service,
      'branch': branch,
      'barber': barber,
      'date': date,
      'time': time,
      'status': status,
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_email': clientEmail,
      'price': price,
    };
  }
}

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.customerId,
    required this.serviceId,
    required this.branchId,
    required this.barberId,
    required this.date,
    required this.time,
    required this.clientName,
    required this.clientPhone,
    this.clientEmail,
    this.notes,
  });

  final String customerId;
  final String serviceId;
  final String branchId;
  final String barberId;
  final String date;
  final String time;
  final String clientName;
  final String clientPhone;
  final String? clientEmail;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'service_id': serviceId,
      'branch_id': branchId,
      'barber_id': barberId,
      'date': date,
      'time': time,
      'client_name': clientName,
      'client_phone': clientPhone,
      if (clientEmail != null && clientEmail!.isNotEmpty)
        'client_email': clientEmail,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

class RescheduleBookingRequest {
  const RescheduleBookingRequest({
    required this.appointmentId,
    required this.serviceId,
    required this.branchId,
    required this.barberId,
    required this.date,
    required this.time,
  });

  final String appointmentId;
  final String serviceId;
  final String branchId;
  final String barberId;
  final String date;
  final String time;

  Map<String, dynamic> toJson() {
    return {
      'appointment_id': appointmentId,
      'service_id': serviceId,
      'branch_id': branchId,
      'barber_id': barberId,
      'date': date,
      'time': time,
    };
  }
}

class BookingException implements Exception {
  const BookingException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
