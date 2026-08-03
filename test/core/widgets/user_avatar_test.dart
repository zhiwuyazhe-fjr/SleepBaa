import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/avatar_image.dart';
import 'package:sleep_dorm_app/core/widgets/user_avatar.dart';

void main() {
  testWidgets('UserAvatar adopts a refreshed signed URL', (
    WidgetTester tester,
  ) async {
    const UserProfile firstProfile = UserProfile(
      uid: 'user-1',
      displayName: 'User',
      tagline: '',
      role: '',
      avatarUrl: 'https://cdn.example.com/avatar.png?sig=first',
      avatarStoragePath: 'avatars/user-1.png',
    );
    const UserProfile secondProfile = UserProfile(
      uid: 'user-1',
      displayName: 'User',
      tagline: '',
      role: '',
      avatarUrl: 'https://cdn.example.com/avatar.png?sig=second',
      avatarStoragePath: 'avatars/user-1.png',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(profile: firstProfile)),
      ),
    );
    Image image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, contains('sig=first'));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UserAvatar(profile: secondProfile)),
      ),
    );
    image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, contains('sig=second'));
    expect(image.gaplessPlayback, isTrue);
    expect(find.byType(AvatarImage), findsOneWidget);
  });
}
