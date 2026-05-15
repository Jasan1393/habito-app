import 'points_summary.dart';

class PointsQuote {
  final bool enabled;
  final String context;
  final double points;
  final double discount;
  final double balance;
  final double rate;
  final double minPoints;
  final double maxPercent;
  final double remainingBalance;
  final String message;
  final String verificationNotice;

  const PointsQuote({
    required this.enabled,
    required this.context,
    required this.points,
    required this.discount,
    required this.balance,
    required this.rate,
    required this.minPoints,
    required this.maxPercent,
    required this.remainingBalance,
    required this.message,
    this.verificationNotice = '',
  });

  bool get canRedeem => enabled && points > 0 && discount > 0;

  factory PointsQuote.fromJson(Map<String, dynamic> json) {
    return PointsQuote(
      enabled: _parseBool(json['enabled']) ?? false,
      context: (json['context'] ?? '').toString(),
      points: _parseDouble(json['points']) ?? 0,
      discount: _parseDouble(json['discount']) ?? 0,
      balance: _parseDouble(json['balance']) ?? 0,
      rate: _parseDouble(json['rate']) ?? 100,
      minPoints: _parseDouble(json['min_points'] ?? json['minPoints']) ?? 1,
      maxPercent: _parseDouble(json['max_percent'] ?? json['maxPercent']) ?? 50,
      remainingBalance: _parseDouble(
            json['remaining_balance'] ?? json['remainingBalance'],
          ) ??
          0,
      message: (json['message'] ?? '').toString(),
      verificationNotice:
          (json['verification_notice'] ?? json['verificationNotice'] ?? '')
              .toString()
              .trim(),
    );
  }

  String get formattedPoints => PointsSummary.formatPoints(points);
  String get formattedBalance => PointsSummary.formatPoints(balance);
  String get formattedRemainingBalance =>
      PointsSummary.formatPoints(remainingBalance);

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
