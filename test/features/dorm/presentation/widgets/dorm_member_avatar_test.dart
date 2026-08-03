import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/avatar_resource.dart';
import 'package:sleep_dorm_app/core/widgets/avatar_image.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_member_avatar.dart';

void main() {
  testWidgets('renders the current signed network URL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DormMemberAvatar(
            size: 44,
            accentColor: Color(0xFF4458D8),
            fallbackSeed: 'Roommate',
            resource: AvatarResource(
              url: 'https://cdn.example.com/avatar.png?sig=first',
              storagePath: 'avatars/roommate.png',
            ),
          ),
        ),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, contains('avatar.png'));
    expect(image.gaplessPlayback, isTrue);
    expect(find.byType(AvatarImage), findsOneWidget);
  });

  testWidgets('renders local preview bytes before a remote avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DormMemberAvatar(
            size: 44,
            accentColor: const Color(0xFF2D9272),
            fallbackSeed: 'Me',
            resource: AvatarResource(
              bytes: base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
              ),
              url: 'https://cdn.example.com/avatar.png',
            ),
          ),
        ),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });
}
