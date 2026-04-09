import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';

void main() {
  test('assistant message timestamps are converted from UTC strings to local', () {
    final DateTime expected = DateTime.parse(
      '2026-04-08T00:00:00.000Z',
    ).toLocal();

    final message = ModelSerializers.assistantMessageFromMap(
      <String, dynamic>{
        'id': 'msg-1',
        'threadId': 'thread-1',
        'role': 'assistant',
        'content': 'hello',
        'createdAt': '2026-04-08T00:00:00.000Z',
      },
    );

    expect(message.createdAt, expected);
    expect(message.createdAt.isUtc, isFalse);
  });

  test('assistant profile timestamps are converted from firestore maps to local', () {
    final DateTime expected = DateTime.fromMillisecondsSinceEpoch(
      1712534400000,
      isUtc: true,
    ).toLocal();

    final profile = ModelSerializers.assistantProfileFromMap(
      <String, dynamic>{
        'userId': 'user-1',
        'assistantName': '小眠',
        'identityPrompt': '陪伴入睡',
        'tone': '温柔',
        'relationshipRole': '睡前助手',
        'updatedAt': <String, dynamic>{
          '_seconds': 1712534400,
          '_nanoseconds': 0,
        },
      },
    );

    expect(profile.updatedAt, expected);
    expect(profile.updatedAt.isUtc, isFalse);
  });
}
