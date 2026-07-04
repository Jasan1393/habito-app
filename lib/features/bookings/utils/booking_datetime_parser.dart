DateTime? parseBookingWallDateTime(String? value) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return null;

  final wallTimeMatch = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(clean);

  if (wallTimeMatch != null) {
    final year = int.tryParse(wallTimeMatch.group(1) ?? '');
    final month = int.tryParse(wallTimeMatch.group(2) ?? '');
    final day = int.tryParse(wallTimeMatch.group(3) ?? '');
    final hour = int.tryParse(wallTimeMatch.group(4) ?? '');
    final minute = int.tryParse(wallTimeMatch.group(5) ?? '');
    final second = int.tryParse(wallTimeMatch.group(6) ?? '0') ?? 0;

    if (year != null &&
        month != null &&
        day != null &&
        hour != null &&
        minute != null) {
      return DateTime(year, month, day, hour, minute, second);
    }
  }

  final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(clean);
  if (dateOnlyMatch != null) {
    final year = int.tryParse(dateOnlyMatch.group(1) ?? '');
    final month = int.tryParse(dateOnlyMatch.group(2) ?? '');
    final day = int.tryParse(dateOnlyMatch.group(3) ?? '');

    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  try {
    return DateTime.parse(clean);
  } catch (_) {}

  try {
    return DateTime.parse(clean.replaceFirst(' ', 'T'));
  } catch (_) {}

  return null;
}
