import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_category_page.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_page.dart';
import 'package:sleep_dorm_app/features/sleep_encyclopedia/presentation/pages/sleep_encyclopedia_topic_page.dart';

void main() {
  testWidgets('home encyclopedia cards trim subtitle full stops', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_wrap(const SleepEncyclopediaPage()));

    expect(find.text('不是立刻逼自己入睡，而是先把身体降速'), findsOneWidget);
    expect(find.text('不是立刻逼自己入睡，而是先把身体降速。'), findsNothing);
    expect(find.text('围绕难入睡、越躺越清醒、睡前习惯调整这些真实场景展开'), findsOneWidget);
    expect(find.text('围绕难入睡、越躺越清醒、睡前习惯调整这些真实场景展开。'), findsNothing);
  });

  testWidgets('category topic cards trim subtitle full stops', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _wrap(const SleepEncyclopediaCategoryPage(categorySlug: 'fall-asleep')),
    );

    expect(
      find.text(
        '很多人一发现自己睡不着，就会开始焦虑地数时间、反复看手机，结果越急越清醒。更有效的做法是先从灯光、呼吸、动作节奏开始，让身体收到“现在可以休息”的信号',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '很多人一发现自己睡不着，就会开始焦虑地数时间、反复看手机，结果越急越清醒。更有效的做法是先从灯光、呼吸、动作节奏开始，让身体收到“现在可以休息”的信号。',
      ),
      findsNothing,
    );
  });

  testWidgets('topic page card subtitles trim full stops but body remains', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      _wrap(const SleepEncyclopediaTopicPage(topicSlug: 'cant-fall-asleep')),
    );

    expect(find.text('不是立刻逼自己入睡，而是先把身体降速'), findsOneWidget);
    expect(find.text('不是立刻逼自己入睡，而是先把身体降速。'), findsNothing);
    expect(
      find.textContaining('让身体收到“现在可以休息”的信号。'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('不要一刀切，而是先缩短最后那段高刺激时间'),
      500,
    );
    expect(find.text('不要一刀切，而是先缩短最后那段高刺激时间'), findsOneWidget);
    expect(find.text('不要一刀切，而是先缩短最后那段高刺激时间。'), findsNothing);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(theme: ThemeData(useMaterial3: true), home: child);
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
