class PointsHistoryEntry {
  final int id;
  final String title;
  final String subtitle;
  final String type;
  final double amount;
  final String amountFormatted;
  final String dateIso;
  final String dateDisplay;
  final String reference;
  final int referenceId;

  const PointsHistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.amount,
    required this.amountFormatted,
    required this.dateIso,
    required this.dateDisplay,
    required this.reference,
    required this.referenceId,
  });

  factory PointsHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PointsHistoryEntry(
      id: _parseInt(json['id']) ?? 0,
      title: (json['title'] ?? 'Movimiento de puntos').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      type: (json['type'] ?? 'neutral').toString(),
      amount: _parseDouble(json['amount']) ?? 0,
      amountFormatted: (json['amount_formatted'] ?? json['amountFormatted'] ?? '0')
          .toString(),
      dateIso: (json['date_iso'] ?? json['dateIso'] ?? '').toString(),
      dateDisplay:
          (json['date_display'] ?? json['dateDisplay'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      referenceId:
          _parseInt(json['reference_id'] ?? json['referenceId']) ?? 0,
    );
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
}
