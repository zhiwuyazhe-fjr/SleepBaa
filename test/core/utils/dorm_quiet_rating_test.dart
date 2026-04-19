import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/utils/dorm_quiet_rating.dart';

void main() {
  test('empty samples yields placeholder stars', () {
    final DormQuietRatingResult r = computeDormQuietRating(<DormNoiseSample>[]);
    expect(r.sampleCount, 0);
    expect(r.stars, 3);
  });

  test('night weight is 1.5 between 23:00 and 08:00', () {
    expect(dormNoiseTimeWeight(DateTime(2026, 4, 18, 7, 30)), 1.5);
    expect(dormNoiseTimeWeight(DateTime(2026, 4, 18, 23, 30)), 1.5);
    expect(dormNoiseTimeWeight(DateTime(2026, 4, 18, 12, 0)), 1.0);
  });

  test('L_eq and 5 stars when daytime sample is 30 dB', () {
    final DormQuietRatingResult r = computeDormQuietRating(<DormNoiseSample>[
      DormNoiseSample(decibel: 30, timestamp: _day),
    ]);
    expect(r.lEq, 30);
    expect(r.stars, 5);
  });

  test('night weight scales level by weight sum, not sample count', () {
    final DateTime night = DateTime(2026, 4, 18, 23, 30);
    final DormQuietRatingResult r = computeDormQuietRating(<DormNoiseSample>[
      DormNoiseSample(decibel: 30, timestamp: night),
    ]);
    expect(r.lEq, 30);
    expect(r.sampleCount, 1);
  });

  test('mixed day and night weights use true weighted mean', () {
    final DormQuietRatingResult r = computeDormQuietRating(<DormNoiseSample>[
      DormNoiseSample(decibel: 40, timestamp: _day),
      DormNoiseSample(decibel: 40, timestamp: DateTime(2026, 4, 18, 23, 0)),
    ]);
    expect(r.lEq, 40);
    expect(r.sampleCount, 2);
  });

  test('invalid decibel values are skipped', () {
    final DormQuietRatingResult r = computeDormQuietRating(<DormNoiseSample>[
      DormNoiseSample(decibel: -1, timestamp: _day),
      DormNoiseSample(decibel: 40, timestamp: _day),
    ]);
    expect(r.sampleCount, 1);
    expect(r.lEq, 40);
  });
}

final DateTime _day = DateTime(2026, 4, 18, 14, 0);
