import 'dart:math' as math;

class NoiseStatistics {
  const NoiseStatistics({
    required this.medianDb,
    required this.peakDb,
    required this.leqDb,
    required this.calibrationOffsetDb,
  });

  final double medianDb;
  final double peakDb;
  final double leqDb;
  final double calibrationOffsetDb;
}

NoiseStatistics calculateNoiseStatistics({
  required List<double> meanSamplesDb,
  required List<double> peakSamplesDb,
  double calibrationOffsetDb = 0,
}) {
  final List<double> means = meanSamplesDb
      .where((double value) => value.isFinite && value > 0)
      .map((double value) => value + calibrationOffsetDb)
      .toList(growable: false);
  if (means.isEmpty) {
    throw ArgumentError.value(
      meanSamplesDb,
      'meanSamplesDb',
      'At least one positive finite sample is required.',
    );
  }

  final List<double> sortedMeans = List<double>.from(means)..sort();
  final int middle = sortedMeans.length ~/ 2;
  final double median = sortedMeans.length.isOdd
      ? sortedMeans[middle]
      : (sortedMeans[middle - 1] + sortedMeans[middle]) / 2;

  final double linearEnergy = means.fold<double>(
    0,
    (double total, double value) => total + math.pow(10, value / 10),
  );
  final double leq = 10 * (math.log(linearEnergy / means.length) / math.ln10);

  final List<double> peaks = peakSamplesDb
      .where((double value) => value.isFinite && value > 0)
      .map((double value) => value + calibrationOffsetDb)
      .toList(growable: false);
  final double peak = peaks.isEmpty
      ? means.reduce(math.max)
      : peaks.reduce(math.max);

  return NoiseStatistics(
    medianDb: median,
    peakDb: peak,
    leqDb: leq,
    calibrationOffsetDb: calibrationOffsetDb,
  );
}
