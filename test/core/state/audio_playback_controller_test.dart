import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';

void main() {
  test('audio controller toggles playback state for the same track', () async {
    final _FakeAudioPlaybackEngine engine = _FakeAudioPlaybackEngine();
    final AudioPlaybackController controller = AudioPlaybackController(
      engine: engine,
    );
    const AudioTrack track = AudioTrack(
      id: 'ocean',
      title: 'Ocean',
      subtitle: 'Calm waves',
      duration: Duration(minutes: 10),
      sourceUrl: 'https://example.com/audio/ocean.wav',
    );

    await controller.toggleTrack(track);
    expect(controller.playbackState, PlaybackState.playing);
    expect(controller.currentTrack?.id, track.id);
    expect(engine.loadedSource, track.sourceUrl);

    await controller.toggleTrack(track);
    expect(controller.playbackState, PlaybackState.paused);

    await controller.resume();
    expect(controller.playbackState, PlaybackState.playing);

    engine.emitPosition(const Duration(minutes: 2));
    await Future<void>.delayed(Duration.zero);
    expect(controller.position, const Duration(minutes: 2));

    engine.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.playbackState, PlaybackState.completed);
    expect(controller.position, track.duration);

    await controller.stop();
    expect(controller.playbackState, PlaybackState.stopped);
    expect(controller.currentTrack, isNull);
    controller.dispose();
  });
}

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<AudioEngineState> _stateController =
      StreamController<AudioEngineState>.broadcast();

  String? loadedSource;
  AudioEngineState _lastState = const AudioEngineState(
    playing: false,
    processingState: AudioEngineProcessingState.idle,
  );

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<AudioEngineState> get stateStream => _stateController.stream;

  @override
  Future<void> setTrack(AudioTrack track) async {
    loadedSource = track.sourceUrl ?? track.assetPath;
    _emitState(
      const AudioEngineState(
        playing: false,
        processingState: AudioEngineProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> play() async {
    _emitState(
      const AudioEngineState(
        playing: true,
        processingState: AudioEngineProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> pause() async {
    _emitState(
      const AudioEngineState(
        playing: false,
        processingState: AudioEngineProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _emitState(
      const AudioEngineState(
        playing: false,
        processingState: AudioEngineProcessingState.idle,
      ),
    );
  }

  void emitPosition(Duration position) {
    _positionController.add(position);
  }

  void complete() {
    _emitState(
      const AudioEngineState(
        playing: false,
        processingState: AudioEngineProcessingState.completed,
      ),
    );
  }

  void _emitState(AudioEngineState state) {
    _lastState = state;
    _stateController.add(state);
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    if (!_stateController.isClosed) {
      _stateController.add(_lastState);
      await _stateController.close();
    }
  }
}
