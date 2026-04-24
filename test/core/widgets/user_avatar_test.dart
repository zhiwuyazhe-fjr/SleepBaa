import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';

void main() {
  testWidgets('UserAvatar keeps network avatar gapless across url refreshes', (
    WidgetTester tester,
  ) async {
    const UserProfile profile = UserProfile(
      uid: 'user-1',
      displayName: 'User',
      tagline: '',
      role: '',
      avatarUrl: 'https://cdn.example.com/avatar.png?sig=first',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(profile: profile)),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    expect(image.gaplessPlayback, isTrue);
  });
}
