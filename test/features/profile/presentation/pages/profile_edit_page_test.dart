import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('preset role can be saved from profile edit page', (
    WidgetTester tester,
  ) async {
    await _pumpProfileSettings(tester);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('早起的鸟儿有虫吃'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('早起的鸟儿有虫吃'), findsOneWidget);
  });

  testWidgets('custom role can be saved from Others field', (
    WidgetTester tester,
  ) async {
    await _pumpProfileSettings(tester);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Others……'),
      '我的自定义角色',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('我的自定义角色'), findsOneWidget);
  });

  testWidgets('saving without any role shows reminder', (
    WidgetTester tester,
  ) async {
    await _pumpProfileSettings(tester);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Others……'), '');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pump();

    expect(find.text('请先选择角色'), findsOneWidget);
    expect(find.text('编辑个人资料'), findsOneWidget);
  });
}

Future<void> _pumpProfileSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    const SleepDormApp(initialLocation: AppRoutes.profileSettings),
  );
  await tester.pumpAndSettle();
}
