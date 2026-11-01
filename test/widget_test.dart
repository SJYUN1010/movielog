import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/screens/profile_screen.dart';
import 'package:movielog/screens/rating_screen.dart';
import 'package:movielog/screens/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('StartScreen shows title, logo and start button', (tester) async {
    await tester.pumpWidget(_app(const StartScreen()));

    expect(find.text('영화의 순간을 기록하세요'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });

  testWidgets('ProfileScreen shows nickname, stats, genres and edit button', (
    tester,
  ) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(_app(const ProfileScreen()));

    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    expect(find.text('342'), findsOneWidget);
    expect(find.text('선호하는 장르'), findsOneWidget);
    expect(find.text('프로필 수정'), findsOneWidget);
  });

  group('RatingScreen', () {
    testWidgets('enables the save button after a rating is selected', (
      tester,
    ) async {
      _useMobileViewport(tester);
      await tester.pumpWidget(_app(const RatingScreen()));

      ElevatedButton saveButton() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      expect(find.text('별을 눌러 평점을 선택해주세요'), findsOneWidget);
      expect(saveButton().onPressed, isNull);

      await tester.tapAt(tester.getCenter(find.byType(RatingBar)));
      await tester.pump();

      expect(find.text('별을 눌러 평점을 선택해주세요'), findsNothing);
      expect(saveButton().onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.textContaining('점을 저장했어요.'), findsOneWidget);
    });
  });
}
