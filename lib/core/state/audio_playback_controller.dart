import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AudioPlaybackController extends ChangeNotifier {
  AudioTrack? _currentTrack;
  PlaybackState _playbackState = PlaybackState.stopped;
  Duration _position = Duration.zero;
  Timer? _ticker;

  AudioTrack? get currentTrack => _currentTrack;
  PlaybackState get playbackState => _playbackState;
  Duration get position => _position;
  bool get isPlaying => _playbackState == PlaybackState.playing;

  Future<void> toggleTrack(AudioTrack track) async {
    if (_currentTrack?.id == track.id &&
        _playbackState == PlaybackState.playing) {
      await pause();
      return;
    }

    if (_currentTrack?.id == track.id &&
        _playbackState == PlaybackState.paused) {
      await resume();
      return;
    }

    await play(track);
  }

  Future<void> play(AudioTrack track) async {
    _currentTrack = track;
    _playbackState = PlaybackState.playing;
    _position = Duration.zero;
    _startTicker();
    notifyListeners();
  }

  Future<void> pause() async {
    _playbackState = PlaybackState.paused;
    _ticker?.cancel();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentTrack == null) {
      return;
    }

    _playbackState = PlaybackState.playing;
    _startTicker();
    notifyListeners();
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _currentTrack = null;
    _playbackState = PlaybackState.stopped;
    _position = Duration.zero;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_currentTrack == null || _playbackState != PlaybackState.playing) {
        return;
      }

      final Duration nextPosition = _position + const Duration(seconds: 1);
      if (nextPosition >= _currentTrack!.duration) {
        _position = _currentTrack!.duration;
        _playbackState = PlaybackState.completed;
        _ticker?.cancel();
      } else {
        _position = nextPosition;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
