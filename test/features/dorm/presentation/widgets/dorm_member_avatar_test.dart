import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/widgets/dorm_member_avatar.dart';

void main() {
  testWidgets('renders a network image when avatarUrl is present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DormMemberAvatar(
            size: 44,
            accentColor: Color(0xFF4458D8),
            fallbackSeed: 'Roommate',
            avatarUrl: 'https://cdn.example.com/avatar.png?sig=first',
          ),
        ),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, contains('avatar.png'));
    expect(image.gaplessPlayback, isTrue);
  });

  testWidgets('renders memory bytes before any network avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DormMemberAvatar(
            size: 44,
            accentColor: const Color(0xFF2D9272),
            fallbackSeed: 'Me',
            avatarBytes: Uint8List.fromList(const <int>[
              137,
              80,
              78,
              71,
              13,
              10,
              26,
              10,
              0,
              0,
              0,
              13,
              73,
              72,
              68,
              82,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              1,
              8,
              6,
              0,
              0,
              0,
              31,
              21,
              196,
              137,
              0,
              0,
              0,
              13,
              73,
              68,
              65,
              84,
              120,
              156,
              99,
              248,
              255,
              255,
              63,
              0,
              5,
              254,
              2,
              254,
              167,
              53,
              129,
              164,
              0,
              0,
              0,
              0,
              73,
              69,
              78,
              68,
              174,
              66,
              96,
              130,
            ]),
            avatarUrl: 'https://cdn.example.com/avatar.png',
          ),
        ),
      ),
    );

    final Image image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });
}
