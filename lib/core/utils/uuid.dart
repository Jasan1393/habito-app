import 'dart:math';

final Random _idempotencyRandom = Random.secure();

/// Lightweight idempotency key generator without adding a UUID package.
String newIdempotencyKey({String prefix = 'habito'}) {
  final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(
        36,
      );
  final randomPart = List<int>.generate(
    16,
    (_) => _idempotencyRandom.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  return '$prefix-$timestamp-$randomPart';
}
