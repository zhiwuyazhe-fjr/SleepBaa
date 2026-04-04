import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/audio_playback_controller.dart';

void main() {
  test('audio controller toggles playback state for the same track', () async {
    final AudioPlaybackController controller = AudioPlaybackController();
    const AudioTrack track = AudioTrack(
      id: 'ocean',
      title: 'Ocean',
      subtitle: 'Calm waves',
      duration: Duration(minutes: 10),
    );

    await controller.toggleTrack(track);
    expect(controller.playbackState, PlaybackState.playing);
    expect(controller.currentTrack?.id, track.id);

    await controller.toggleTrack(track);
    expect(controller.playbackState, PlaybackState.paused);

    await controller.resume();
    expect(controller.playbackState, PlaybackState.playing);

    await controller.stop();
    expect(controller.playbackState, PlaybackState.stopped);
    expect(controller.currentTrack, isNull);
    controller.dispose();
  });
}
