import 'dart:math';

final _random = Random.secure();

/// 128 bits of randomness; no device or user information is embedded.
String newEntityId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
