class PointsSummary {
  final bool enabled;
  final bool mycredAvailable;
  final double balance;
  final double totalEarned;
  final String pointType;
  final String label;
  final int nextGoal;
  final double toNextGoal;
  final bool redeemEnabled;
  final bool redeemProductsEnabled;
  final bool redeemBookingsEnabled;
  final double redeemPointsPerUsd;
  final double redeemMinPoints;
  final double redeemMaxPercent;
  final bool bookingPointsEnabled;
  final bool orderPointsEnabled;

  const PointsSummary({
    required this.enabled,
    required this.mycredAvailable,
    required this.balance,
    required this.totalEarned,
    required this.pointType,
    required this.label,
    required this.nextGoal,
    required this.toNextGoal,
    required this.redeemEnabled,
    required this.redeemProductsEnabled,
    required this.redeemBookingsEnabled,
    required this.redeemPointsPerUsd,
    required this.redeemMinPoints,
    required this.redeemMaxPercent,
    required this.bookingPointsEnabled,
    required this.orderPointsEnabled,
  });

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    final enabled = _parseBool(json['enabled']) ?? false;
    return PointsSummary(
      enabled: enabled,
      mycredAvailable: _parseBool(
            json['mycred_available'] ?? json['mycredAvailable'],
          ) ??
          false,
      balance: _parseDouble(json['balance']) ?? 0,
      totalEarned:
          _parseDouble(json['total_earned'] ?? json['totalEarned']) ?? 0,
      pointType: (json['point_type'] ?? json['pointType'] ?? 'mycred_default')
          .toString(),
      label: (json['label'] ?? 'Puntos').toString(),
      nextGoal: _parseInt(json['next_goal'] ?? json['nextGoal']) ?? 0,
      toNextGoal: _parseDouble(json['to_next_goal'] ?? json['toNextGoal']) ?? 0,
      redeemEnabled: _parseBool(
            json['redeem_enabled'] ?? json['redeemEnabled'],
          ) ??
          false,
      redeemProductsEnabled: _parseBool(
            json['redeem_products_enabled'] ?? json['redeemProductsEnabled'],
          ) ??
          false,
      redeemBookingsEnabled: _parseBool(
            json['redeem_bookings_enabled'] ?? json['redeemBookingsEnabled'],
          ) ??
          false,
      redeemPointsPerUsd: _parseDouble(
            json['redeem_points_per_usd'] ?? json['redeemPointsPerUsd'],
          ) ??
          100,
      redeemMinPoints: _parseDouble(
            json['redeem_min_points'] ?? json['redeemMinPoints'],
          ) ??
          1,
      redeemMaxPercent: _parseDouble(
            json['redeem_max_percent'] ?? json['redeemMaxPercent'],
          ) ??
          50,
      bookingPointsEnabled: _parseBool(
            json['booking_points_enabled'] ?? json['bookingPointsEnabled'],
          ) ??
          enabled,
      orderPointsEnabled: _parseBool(
            json['order_points_enabled'] ?? json['orderPointsEnabled'],
          ) ??
          enabled,
    );
  }

  String get formattedBalance => formatPoints(balance);
  String get formattedTotalEarned => formatPoints(totalEarned);
  String get formattedToNextGoal => formatPoints(toNextGoal);

  static String formatPoints(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    if ((rounded - rounded.roundToDouble()).abs() < 0.00001) {
      return rounded.round().toString();
    }
    return rounded
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
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
