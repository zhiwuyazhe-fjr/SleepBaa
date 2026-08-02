import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/utils/noise_statistics.dart';

void main() {
  test('calculates median, peak and energy-equivalent Leq', () {
    final NoiseStatistics result = calculateNoiseStatistics(
      meanSamplesDb: <double>[30, 40],
      peakSamplesDb: <double>[42, 50],
    );

    expect(result.medianDb, 35);
    expect(result.peakDb, 50);
    expect(result.leqDb, closeTo(37.4036, 0.0001));
  });

  test('applies calibration offset to all reported metrics', () {
    final NoiseStatistics result = calculateNoiseStatistics(
      meanSamplesDb: <double>[30, 40],
      peakSamplesDb: <double>[42, 50],
      calibrationOffsetDb: -2,
    );

    expect(result.medianDb, 33);
    expect(result.peakDb, 48);
    expect(result.leqDb, closeTo(35.4036, 0.0001));
  });

  test('ignores invalid samples and falls back to the mean peak', () {
    final NoiseStatistics result = calculateNoiseStatistics(
      meanSamplesDb: <double>[double.nan, -1, 42],
      peakSamplesDb: <double>[double.infinity],
    );

    expect(result.medianDb, 42);
    expect(result.peakDb, 42);
    expect(result.leqDb, closeTo(42, 0.0001));
  });
}
