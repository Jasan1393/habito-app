class BirthdayPromotionSummary {
  final bool enabled;
  final bool active;
  final double pointsAvailable;
  final String pointsFormatted;
  final String? expiresAt;

  const BirthdayPromotionSummary({
    required this.enabled,
    required this.active,
    required this.pointsAvailable,
    required this.pointsFormatted,
    this.expiresAt,
  });

  factory BirthdayPromotionSummary.empty() {
    return const BirthdayPromotionSummary(
      enabled: false,
      active: false,
      pointsAvailable: 0,
      pointsFormatted: '0',
    );
  }

  factory BirthdayPromotionSummary.fromJson(Map<String, dynamic> json) {
    return BirthdayPromotionSummary(
      enabled: _parseBool(json['enabled']) ?? false,
      active: _parseBool(json['active']) ?? false,
      pointsAvailable: _parseDouble(
            json['points_available'] ?? json['pointsAvailable'],
          ) ??
          0,
      pointsFormatted: (json['points_formatted'] ??
              json['pointsFormatted'] ??
              _formatPoints(_parseDouble(
                    json['points_available'] ?? json['pointsAvailable'],
                  ) ??
                  0))
          .toString(),
      expiresAt: (json['expires_at'] ?? json['expiresAt'])?.toString(),
    );
  }

  static String _formatPoints(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    if ((rounded - rounded.roundToDouble()).abs() < 0.00001) {
      return rounded.round().toString();
    }
    return rounded
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
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
