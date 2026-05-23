import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/features/assistant/presentation/widgets/assistant_surface.dart';

void main() {
  test('assistant tool statuses decode navigation suggestion tokens', () {
    final String token =
        'agent_navigation:${Uri.encodeComponent('/sleep/audio_catalog')}:'
        '${Uri.encodeComponent('打开助眠音频')}';

    final List<AssistantToolStatus> statuses =
        assistantToolStatusesFromSurfaceIds(<String>[token]);

    expect(statuses, hasLength(1));
    expect(statuses.single.canNavigate, true);
    expect(statuses.single.navigationRoute, '/sleep/audio_catalog');
    expect(statuses.single.navigationLabel, '打开助眠音频');
    expect(statuses.single.label, '可跳转：打开助眠音频');
  });
}
