import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class AudioPlaybackController extends ChangeNotifier {
  AudioPlaybackController({AudioPlaybackEngine? engine})
    : _engine = engine ?? JustAudioPlaybackEngine() {
    _positionSubscription = _engine.positionStream.listen(_handlePositionChanged);
    _stateSubscription = _engine.stateStream.listen(_handleStateChanged);
  }

  final AudioPlaybackEngine _engine;

  AudioTrack? _currentTrack;
  PlaybackState _playbackState = PlaybackState.stopped;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<AudioEngineState>? _stateSubscription;

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
        (_playbackState == PlaybackState.paused ||
            _playbackState == PlaybackState.completed)) {
      if (_playbackState == PlaybackState.completed) {
        await play(track);
        return;
      }
      await resume();
      return;
    }

    await play(track);
  }

  Future<void> play(AudioTrack track) async {
    final bool hasAssetPath =
        track.assetPath != null && track.assetPath!.trim().isNotEmpty;
    final bool hasSourceUrl =
        track.sourceUrl != null && track.sourceUrl!.trim().isNotEmpty;
    if (!hasAssetPath && !hasSourceUrl) {
      _currentTrack = track;
      _playbackState = PlaybackState.stopped;
      _position = Duration.zero;
      notifyListeners();
      return;
    }

    _currentTrack = track;
    _position = Duration.zero;
    _playbackState = PlaybackState.paused;
    notifyListeners();
    await _engine.setTrack(track);
    await _engine.play();
  }

  Future<void> pause() async {
    if (_currentTrack == null) {
      return;
    }
    await _engine.pause();
  }

  Future<void> resume() async {
    if (_currentTrack == null) {
      return;
    }
    await _engine.play();
  }

  Future<void> stop() async {
    await _engine.stop();
    _currentTrack = null;
    _playbackState = PlaybackState.stopped;
    _position = Duration.zero;
    notifyListeners();
  }

  void _handlePositionChanged(Duration nextPosition) {
    final Duration? duration = _currentTrack?.duration;
    _position = duration == null
        ? nextPosition
        : nextPosition > duration
        ? duration
        : nextPosition;
    notifyListeners();
  }

  void _handleStateChanged(AudioEngineState state) {
    final PlaybackState nextState;
    if (_currentTrack == null) {
      nextState = PlaybackState.stopped;
    } else if (state.processingState == AudioEngineProcessingState.completed) {
      nextState = PlaybackState.completed;
      _position = _currentTrack!.duration;
    } else if (state.playing) {
      nextState = PlaybackState.playing;
    } else if (state.processingState == AudioEngineProcessingState.idle) {
      nextState = PlaybackState.stopped;
    } else {
      nextState = PlaybackState.paused;
    }

    _playbackState = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    unawaited(_engine.dispose());
    super.dispose();
  }
}

abstract interface class AudioPlaybackEngine {
  Stream<Duration> get positionStream;
  Stream<AudioEngineState> get stateStream;

  Future<void> setTrack(AudioTrack track);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

enum AudioEngineProcessingState { idle, loading, buffering, ready, completed }

class AudioEngineState {
  const AudioEngineState({
    required this.playing,
    required this.processingState,
  });

  final bool playing;
  final AudioEngineProcessingState processingState;
}

class JustAudioPlaybackEngine implements AudioPlaybackEngine {
  JustAudioPlaybackEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<AudioEngineState> get stateStream =>
      _player.playerStateStream.map((PlayerState state) {
        return AudioEngineState(
          playing: state.playing,
          processingState: switch (state.processingState) {
            ProcessingState.idle => AudioEngineProcessingState.idle,
            ProcessingState.loading => AudioEngineProcessingState.loading,
            ProcessingState.buffering => AudioEngineProcessingState.buffering,
            ProcessingState.ready => AudioEngineProcessingState.ready,
            ProcessingState.completed => AudioEngineProcessingState.completed,
          },
        );
      });

  @override
  Future<void> setTrack(AudioTrack track) async {
    final String? assetPath = track.assetPath;
    if (assetPath != null && assetPath.trim().isNotEmpty) {
      await _player.setAsset(assetPath);
      return;
    }
    final String? sourceUrl = track.sourceUrl;
    if (sourceUrl == null || sourceUrl.trim().isEmpty) {
      throw StateError('Audio sourceUrl or assetPath is required for playback.');
    }
    await _player.setUrl(sourceUrl);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
