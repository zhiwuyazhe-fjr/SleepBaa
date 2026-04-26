import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/core/app_scope.dart';
import 'package:sleep_dorm_app/core/backend/app_environment.dart';
import 'package:sleep_dorm_app/core/widgets/primary_button.dart';
import 'package:sleep_dorm_app/features/profile/presentation/pages/profile_edit_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('preset role can be saved from profile edit page', (
    WidgetTester tester,
  ) async {
    await _pumpProfileEdit(tester);

    await tester.tap(find.text('早起的鸟儿有虫吃'));
    await tester.pumpAndSettle();
    await _tapSaveButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('早起的鸟儿有虫吃'), findsOneWidget);
  });

  testWidgets('custom role can be saved from Others field', (
    WidgetTester tester,
  ) async {
    await _pumpProfileEdit(tester);

    await tester.enterText(find.byType(TextField).last, '我的自定义角色');
    await _tapSaveButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('我的自定义角色'), findsOneWidget);
  });

  testWidgets('saving without any role shows reminder', (
    WidgetTester tester,
  ) async {
    await _pumpProfileEdit(tester);

    await tester.enterText(find.byType(TextField).last, '');
    await _tapSaveButton(tester);
    await tester.pump();

    expect(find.text('请先选择角色'), findsOneWidget);
    expect(find.text('编辑个人资料'), findsOneWidget);
  });
}

Future<void> _pumpProfileEdit(WidgetTester tester) async {
  await tester.pumpWidget(
    const AppScope(
      environment: AppEnvironment(
        target: AppBackendTarget.inMemory,
        appIdPrefix: 'test',
      ),
      child: MaterialApp(home: ProfileEditPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSaveButton(WidgetTester tester) async {
  final Finder saveButton = find.byType(PrimaryButton);
  await tester.scrollUntilVisible(
    saveButton,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
}
