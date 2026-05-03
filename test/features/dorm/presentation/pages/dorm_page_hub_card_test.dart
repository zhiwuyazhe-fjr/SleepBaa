import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sleep_dorm_app/app/app.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/app/theme/app_spacing.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'dorm hub cards keep the action detail copy away from the bottom edge',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(tester, initialLocation: AppRoutes.dorm);

      await tester.scrollUntilVisible(
        find.text('查看勋章'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        _detailBottomGap(tester, '查看详情'),
        greaterThanOrEqualTo(AppSpacing.sm),
        reason: '宿舍公约卡片的底部留白太紧了。',
      );
      expect(
        _detailBottomGap(tester, '查看勋章'),
        greaterThanOrEqualTo(AppSpacing.sm),
        reason: '宿舍勋章卡片的底部留白太紧了。',
      );
      expect(
        _verticalGapBetweenCards(tester, '宿舍公约', '宿舍勋章'),
        moreOrLessEquals(AppSpacing.sm, epsilon: 0.1),
        reason: '2x2 卡片之间的默认纵向间距不应该被意外改窄。',
      );
      expect(
        _cardHeight(tester, '宿舍公约'),
        lessThanOrEqualTo(120),
        reason: '宿舍公约卡片本身还偏高。',
      );
      expect(
        _cardHeight(tester, '宿舍勋章'),
        lessThanOrEqualTo(120),
        reason: '宿舍勋章卡片本身还偏高。',
      );
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  await tester.pumpWidget(
    SleepDormApp(
      initialLocation: initialLocation,
      clock: DateTime.now,
      showNightWelcomeOutsideNightInDebug: false,
    ),
  );
  await tester.pumpAndSettle();
}

double _detailBottomGap(WidgetTester tester, String label) {
  final Finder textFinder = find.text(label).first;
  final Finder cardFinder = find.ancestor(
    of: textFinder,
    matching: find.byType(AppCard),
  ).first;

  return tester.getRect(cardFinder).bottom - tester.getRect(textFinder).bottom;
}

double _verticalGapBetweenCards(
  WidgetTester tester,
  String upperTitle,
  String lowerTitle,
) {
  final Finder upperCard = find.ancestor(
    of: find.text(upperTitle).first,
    matching: find.byType(AppCard),
  ).first;
  final Finder lowerCard = find.ancestor(
    of: find.text(lowerTitle).first,
    matching: find.byType(AppCard),
  ).first;

  return tester.getRect(lowerCard).top - tester.getRect(upperCard).bottom;
}

double _cardHeight(WidgetTester tester, String title) {
  final Finder cardFinder = find.ancestor(
    of: find.text(title).first,
    matching: find.byType(AppCard),
  ).first;

  return tester.getSize(cardFinder).height;
}
