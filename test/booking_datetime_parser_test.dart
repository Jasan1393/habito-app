import 'package:flutter_test/flutter_test.dart';
import 'package:habito/features/bookings/utils/booking_datetime_parser.dart';

void main() {
  group('parseBookingWallDateTime', () {
    test('keeps Amelia local wall-clock time when an offset is present', () {
      final parsed = parseBookingWallDateTime('2026-07-04T16:20:00-05:00');

      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 7);
      expect(parsed.day, 4);
      expect(parsed.hour, 16);
      expect(parsed.minute, 20);
    });

    test('keeps Amelia local wall-clock time when Z is present', () {
      final parsed = parseBookingWallDateTime('2026-07-04T16:20:00Z');

      expect(parsed, isNotNull);
      expect(parsed!.hour, 16);
      expect(parsed.minute, 20);
    });

    test('parses the plain backend date-time format used when booking', () {
      final parsed = parseBookingWallDateTime('2026-07-04 16:20');

      expect(parsed, isNotNull);
      expect(parsed!.hour, 16);
      expect(parsed.minute, 20);
    });
  });
}
