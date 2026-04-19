import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/utils/dorm_quiet_rating.dart';

/// In-memory history of dorm noise samples for time-weighted L_eq.
///
/// Samples are appended after local microphone probes and when the server
/// dorm aggregate [noiseDb] changes (see [maybeRecordDormAggregate]).
class DormNoiseSampleLedger extends ChangeNotifier {
  static const int _maxSamples = 400;

  final List<DormNoiseSample> _samples = <DormNoiseSample>[];
  int? _lastRecordedAggregateDb;

  List<DormNoiseSample> get samples =>
      List<DormNoiseSample>.unmodifiable(_samples);

  void recordSample(double decibel, DateTime timestamp) {
    if (!decibel.isFinite || decibel < 0) {
      return;
    }
    _samples.add(DormNoiseSample(decibel: decibel, timestamp: timestamp));
    while (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
    notifyListeners();
  }

  /// Records one sample when the dorm-level aggregate from the server changes.
  void maybeRecordDormAggregate(int noiseDb) {
    if (noiseDb < 0 || _lastRecordedAggregateDb == noiseDb) {
      return;
    }
    _lastRecordedAggregateDb = noiseDb;
    recordSample(noiseDb.toDouble(), DateTime.now());
  }

  void clear() {
    _samples.clear();
    _lastRecordedAggregateDb = null;
    notifyListeners();
  }
}
