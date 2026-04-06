import 'dart:math';

abstract final class IdGenerator {
  static final Random _random = Random();

  static String next(String prefix) {
    final int now = DateTime.now().microsecondsSinceEpoch;
    final int salt = _random.nextInt(1 << 20);
    return '$prefix-$now-$salt';
  }
}
