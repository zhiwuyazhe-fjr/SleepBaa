import 'package:flutter/foundation.dart';

/// One microphone noise sample with local timestamp.
@immutable
class DormNoiseSample {
  const DormNoiseSample({required this.decibel, required this.timestamp});

  /// Sound level in dB (typically positive).
  final double decibel;

  /// When the sample was taken (device local time).
  final DateTime timestamp;
}

/// Result of [computeDormQuietRating].
@immutable
class DormQuietRatingResult {
  const DormQuietRatingResult({
    required this.lEq,
    required this.stars,
    required this.sampleCount,
  });

  /// Time-weighted equivalent noise level (dB).
  final double lEq;

  /// 1–5 stars (5 = quietest).
  final int stars;

  /// Number of samples used in [lEq] (may be 0).
  final int sampleCount;
}

/// Day: 08:00–23:00 → weight 1.0; night: 23:00–08:00 → weight 1.5.
double dormNoiseTimeWeight(DateTime local) {
  final int hour = local.hour;
  final bool isNight = hour >= 23 || hour < 8;
  return isNight ? 1.5 : 1.0;
}

/// L_eq = Σ(Lᵢ × Wᵢ) / Σ(Wᵢ)  (time-weighted mean; weights from [dormNoiseTimeWeight])
DormQuietRatingResult computeDormQuietRating(List<DormNoiseSample> samples) {
  if (samples.isEmpty) {
    return const DormQuietRatingResult(lEq: 0, stars: 3, sampleCount: 0);
  }
  double sumWeighted = 0;
  double sumWeights = 0;
  int n = 0;
  for (final DormNoiseSample s in samples) {
    if (!s.decibel.isFinite || s.decibel < 0) {
      continue;
    }
    final double w = dormNoiseTimeWeight(s.timestamp.toLocal());
    sumWeighted += s.decibel * w;
    sumWeights += w;
    n += 1;
  }
  if (n == 0 || sumWeights <= 0) {
    return const DormQuietRatingResult(lEq: 0, stars: 3, sampleCount: 0);
  }
  final double lEq = sumWeighted / sumWeights;
  return DormQuietRatingResult(
    lEq: lEq,
    stars: starsFromEquivalentNoise(lEq),
    sampleCount: n,
  );
}

/// Maps L_eq to 1–5 stars per product spec.
int starsFromEquivalentNoise(double lEq) {
  if (!lEq.isFinite || lEq < 0) {
    return 3;
  }
  if (lEq <= 35) {
    return 5;
  }
  if (lEq <= 50) {
    return 4;
  }
  if (lEq <= 65) {
    return 3;
  }
  if (lEq <= 80) {
    return 2;
  }
  return 1;
}
