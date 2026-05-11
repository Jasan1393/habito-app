class ReferralsSummary {
  final bool enabled;
  final String code;
  final String link;
  final ReferralProgress? asReferred;
  final ReferralMetrics metrics;
  final double referrerPoints;
  final double referredPoints;

  const ReferralsSummary({
    required this.enabled,
    required this.code,
    required this.link,
    required this.asReferred,
    required this.metrics,
    required this.referrerPoints,
    required this.referredPoints,
  });

  factory ReferralsSummary.empty() {
    return ReferralsSummary(
      enabled: false,
      code: '',
      link: '',
      asReferred: null,
      metrics: ReferralMetrics.empty(),
      referrerPoints: 0,
      referredPoints: 0,
    );
  }

  factory ReferralsSummary.fromPayload(Map<String, dynamic> payload) {
    final referrals = _asMap(payload['referrals']);
    final settings = _asMap(payload['settings']);

    return ReferralsSummary(
      enabled: _parseBool(referrals['enabled']) ??
          _parseBool(
              settings['referrals_enabled'] ?? settings['referralsEnabled']) ??
          false,
      code: (referrals['code'] ?? '').toString(),
      link: (referrals['link'] ?? '').toString(),
      asReferred:
          referrals['as_referred'] is Map || referrals['asReferred'] is Map
              ? ReferralProgress.fromJson(
                  _asMap(referrals['as_referred'] ?? referrals['asReferred']),
                )
              : null,
      metrics: ReferralMetrics.fromJson(_asMap(referrals['metrics'])),
      referrerPoints: _parseDouble(
            settings['referrer_points'] ?? settings['referrerPoints'],
          ) ??
          0,
      referredPoints: _parseDouble(
            settings['referred_points'] ?? settings['referredPoints'],
          ) ??
          0,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }
}

class ReferralProgress {
  final String status;
  final int? referrerId;
  final int? appointmentId;
  final int? transactionId;

  const ReferralProgress({
    required this.status,
    this.referrerId,
    this.appointmentId,
    this.transactionId,
  });

  factory ReferralProgress.fromJson(Map<String, dynamic> json) {
    return ReferralProgress(
      status: (json['status'] ?? '').toString(),
      referrerId: _parseInt(json['referrer_id'] ?? json['referrerId']),
      appointmentId: _parseInt(json['appointment_id'] ?? json['appointmentId']),
      transactionId: _parseInt(json['transaction_id'] ?? json['transactionId']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class ReferralMetrics {
  final int total;
  final int registered;
  final int appointmentCreated;
  final int rewarded;
  final int reversed;

  const ReferralMetrics({
    required this.total,
    required this.registered,
    required this.appointmentCreated,
    required this.rewarded,
    required this.reversed,
  });

  factory ReferralMetrics.empty() {
    return const ReferralMetrics(
      total: 0,
      registered: 0,
      appointmentCreated: 0,
      rewarded: 0,
      reversed: 0,
    );
  }

  factory ReferralMetrics.fromJson(Map<String, dynamic> json) {
    return ReferralMetrics(
      total: _parseInt(json['total']) ?? 0,
      registered: _parseInt(json['registered']) ?? 0,
      appointmentCreated: _parseInt(
            json['appointment_created'] ?? json['appointmentCreated'],
          ) ??
          0,
      rewarded: _parseInt(json['rewarded']) ?? 0,
      reversed: _parseInt(json['reversed']) ?? 0,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
