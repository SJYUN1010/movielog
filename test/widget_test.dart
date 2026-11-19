import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/profile_screen.dart';
import 'package:movielog/screens/rating_screen.dart';
import 'package:movielog/screens/splash_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support/fakes.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('SplashScreen shows the logo, title and a progress indicator while checking the session', (
    tester,
  ) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(_app(const SplashScreen()));

    expect(find.textContaining('영화의 순간을'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
    expect(find.text('시작하기'), findsNothing);
  });

  testWidgets('SplashScreen keeps its content centered while checking (no full-width button below)', (
    tester,
  ) async {
    // 회귀 테스트: 확인 중 상태에서는 하단에 전체 너비 위젯이 없어 Column이 내용 너비로 줄어
    // 로고·문구가 화면 왼쪽으로 치우쳤습니다(에뮬레이터에서 발견).
    _useMobileViewport(tester);
    await tester.pumpWidget(_app(const SplashScreen()));

    expect(tester.getCenter(find.byType(SvgPicture)).dx, closeTo(195, 1));
    expect(tester.getCenter(find.textContaining('영화의 순간을')).dx, closeTo(195, 1));
    expect(tester.getCenter(find.byType(CircularProgressIndicator)).dx, closeTo(195, 1));
  });

  testWidgets('SplashScreen shows the message and a retry button when the check failed', (tester) async {
    _useMobileViewport(tester);
    var retried = 0;
    await tester.pumpWidget(
      _app(SplashScreen(message: '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.', onRetry: () => retried++)),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retried, 1);
  });

  group('ProfileScreen', () {
    Future<AuthViewModel> pumpProfile(WidgetTester tester, {bool loadMember = true}) async {
      _useMobileViewport(tester);
      final auth = (await tester.runAsync(signedInAuthViewModel))!;
      if (loadMember) await tester.runAsync(auth.loadMember);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(value: auth, child: _app(const ProfileScreen())),
      );
      return auth;
    }

    testWidgets('shows the member from GET me, the join date, stats, genres, edit and logout', (tester) async {
      await pumpProfile(tester);

      expect(find.text('내 프로필'), findsOneWidget);
      expect(find.text('무비러버'), findsOneWidget);
      expect(find.text('movie@example.com'), findsOneWidget);
      expect(find.text('2026.10.10 가입'), findsOneWidget);
      expect(find.text('342'), findsOneWidget);
      expect(find.text('선호하는 장르'), findsOneWidget);
      expect(find.text('프로필 수정'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
    });

    testWidgets('while the member is loading the whole body is an indicator', (tester) async {
      await pumpProfile(tester, loadMember: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('프로필 수정'), findsNothing);
    });

    testWidgets('a failed load shows a message and retry, and retry loads the member', (tester) async {
      final members = FakeMemberApiService()
        ..meError = dioFailure('/v7/members/me')
        ..failMeTimes = 1;
      _useMobileViewport(tester);
      final auth = (await tester.runAsync(() => signedInAuthViewModel(members: members)))!;
      await tester.runAsync(auth.loadMember);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(value: auth, child: _app(const ProfileScreen())),
      );

      expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(auth.status, AuthStatus.signedIn); // 실패해도 로그아웃하지 않습니다.

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('무비러버'), findsOneWidget);
    });

    testWidgets('logout clears the token and the member', (tester) async {
      final storage = MemoryTokenStorage();
      _useMobileViewport(tester);
      final auth = (await tester.runAsync(() => signedInAuthViewModel(storage: storage)))!;
      await tester.runAsync(auth.loadMember);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(value: auth, child: _app(const ProfileScreen())),
      );

      await tester.tap(find.text('로그아웃'));
      await tester.pump(); // 내 정보가 사라지면 로딩 인디케이터가 계속 돌아 pumpAndSettle은 끝나지 않습니다.
      await tester.pump();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.member, isNull);
      expect(auth.sessionExpired, isFalse);
      expect(storage.token, isNull);
    });
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
