import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/email_preference.dart';
import 'package:movielog/screens/edit_profile_screen.dart';
import 'package:movielog/screens/login_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/data/services/member_api_service.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _LoginSetup {
  final authApi = FakeAuthApiService();
  final members = FakeMemberApiService();
  final storage = MemoryTokenStorage();
  final email = MemoryEmailPreference();
  late final AuthViewModel auth = AuthViewModel(authApi, members, storage);

  Future<void> pump(WidgetTester tester) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          Provider<EmailPreference>.value(value: email),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder get _emailField => find.byType(TextField).at(0);
Finder get _passwordField => find.byType(TextField).at(1);

void main() {
  group('LoginScreen', () {
    testWidgets('shows the title, both fields, the save-email checkbox and the sign up link', (tester) async {
      await _LoginSetup().pump(tester);

      expect(find.text('MovieLog에 로그인'), findsOneWidget);
      expect(find.text('이메일'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(find.text('이메일 저장'), findsOneWidget);
      expect(find.text('회원가입'), findsOneWidget);
      expect(tester.widget<TextField>(_passwordField).obscureText, isTrue);
    });

    testWidgets('empty input shows field messages and sends nothing', (tester) async {
      final s = _LoginSetup();
      await s.pump(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pump();

      expect(find.text('이메일을 입력해 주세요.'), findsOneWidget);
      expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
      expect(s.authApi.requests, isEmpty);
    });

    testWidgets('a successful login saves the token and the router-less screen only calls login()', (tester) async {
      final s = _LoginSetup();
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'Umc1234!');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(s.authApi.requests.single.email, 'movie@example.com');
      expect(s.auth.status, AuthStatus.signedIn);
      expect(s.storage.token, 'secret-token-1');
      expect(s.email.email, isNull); // 체크하지 않았으니 이메일도 저장하지 않습니다.
    });

    testWidgets('while logging in the button shows a spinner and the fields are locked', (tester) async {
      final s = _LoginSetup();
      s.authApi.delay = const Duration(milliseconds: 300);
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'Umc1234!');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(_emailField).enabled, isFalse);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(s.authApi.requests, hasLength(1)); // 통신 중에는 다시 보내지 않습니다.

      await tester.pumpAndSettle();
    });

    testWidgets('AUTH401_1 shows the form error under the password and typing clears it', (tester) async {
      final s = _LoginSetup();
      s.authApi.error = commonFailure(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.');
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'wrong');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing); // 만료 안내가 아닙니다.
      expect(s.auth.sessionExpired, isFalse);

      await tester.enterText(_passwordField, 'wrong2');
      await tester.pump();
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsNothing);
    });

    testWidgets('a network failure is a different message from a wrong password', (tester) async {
      final s = _LoginSetup();
      s.authApi.error = dioFailure('/v7/auth/login');
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'Umc1234!');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsNothing);
    });

    testWidgets('a token save failure has its own message', (tester) async {
      final s = _LoginSetup();
      s.storage.failWrite = true;
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'Umc1234!');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(find.text('로그인 정보를 안전하게 저장하지 못했어요.'), findsOneWidget);
      expect(s.auth.status, AuthStatus.signedOut);
    });

    testWidgets('save-email: a checked login stores only the email', (tester) async {
      final s = _LoginSetup();
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'Umc1234!');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(s.email.email, 'movie@example.com');
      expect(s.email.email, isNot(contains('Umc1234')));

    });

    testWidgets('a saved email fills the field with the box checked; unchecking and logging in clears it', (
      tester,
    ) async {
      final next = _LoginSetup()..email.email = 'movie@example.com';
      await next.pump(tester);
      expect(tester.widget<TextField>(_emailField).controller!.text, 'movie@example.com');
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.enterText(_passwordField, 'Umc1234!');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();
      expect(next.email.email, isNull);
    });

    testWidgets('a failed login does not store the email', (tester) async {
      final s = _LoginSetup();
      s.authApi.error = commonFailure(401, 'AUTH401_1', 'x');
      await s.pump(tester);

      await tester.enterText(_emailField, 'movie@example.com');
      await tester.enterText(_passwordField, 'wrong');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pumpAndSettle();

      expect(s.email.email, isNull);
    });

    testWidgets('after an expired session the login screen explains why, once', (tester) async {
      final s = _LoginSetup();
      await tester.runAsync(() => s.auth.login('movie@example.com', 'Umc1234!'));
      await tester.runAsync(s.auth.expireSession);
      expect(s.auth.sessionExpired, isTrue);

      await s.pump(tester);

      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
      expect(s.auth.sessionExpired, isFalse); // 한 번 보여주면 꺼집니다.
    });

    testWidgets('a direct logout does not show the expiry notice', (tester) async {
      final s = _LoginSetup();
      await tester.runAsync(() => s.auth.login('movie@example.com', 'Umc1234!'));
      await tester.runAsync(s.auth.logout);

      await s.pump(tester);

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('EditProfileScreen', () {
    Future<({AuthViewModel auth, FakeMemberApiService members, GoRouter router})> pumpEdit(
      WidgetTester tester,
    ) async {
      _useMobileViewport(tester);
      final members = FakeMemberApiService();
      final auth = (await tester.runAsync(() => signedInAuthViewModel(members: members)))!;
      await tester.runAsync(auth.loadMember);
      final router = GoRouter(
        initialLocation: '/my',
        routes: [
          GoRoute(
            path: '/my',
            builder: (context, state) => const Scaffold(body: Text('마이 화면')),
            routes: [
              GoRoute(
                path: 'profile/edit',
                builder: (context, state) => ChangeNotifierProvider<EditProfileViewModel>(
                  create: (context) => EditProfileViewModel(context.read<MemberApiService>(), auth),
                  child: const EditProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            Provider<MemberApiService>.value(value: members),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      router.push('/my/profile/edit');
      await tester.pumpAndSettle();
      return (auth: auth, members: members, router: router);
    }

    testWidgets('shows a read-only email, the current nickname and a character counter', (tester) async {
      await pumpEdit(tester);

      expect(find.text('이메일 (변경할 수 없습니다)'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).enabled, isFalse);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, 'movie@example.com');
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '무비러버');
      expect(find.text('4 / 12'), findsOneWidget);
    });

    testWidgets('saving a new nickname shows a Snackbar, updates the member and returns to the my page', (
      tester,
    ) async {
      final s = await pumpEdit(tester);

      await tester.enterText(find.byType(TextField).at(1), '새닉네임');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(s.members.nicknames, ['새닉네임']);
      expect(s.auth.member?.nickname, '새닉네임');
      expect(find.text('프로필을 수정했어요.'), findsOneWidget);
      expect(find.text('마이 화면'), findsOneWidget); // 변경 확인 Dialog 없이 닫힙니다.
      expect(find.text('변경 내용을 버릴까요?'), findsNothing);
    });

    testWidgets('a duplicate nickname (409) stays on the screen with the input and an error under the field', (
      tester,
    ) async {
      final s = await pumpEdit(tester);
      s.members.updateError = commonFailure(409, 'MEMBER409_1', '이미 사용 중인 닉네임입니다.');

      await tester.enterText(find.byType(TextField).at(1), 'taken');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, 'taken');
      expect(find.text('마이 화면'), findsNothing);
      expect(s.auth.status, AuthStatus.signedIn);

      await tester.enterText(find.byType(TextField).at(1), 'taken2');
      await tester.pump();
      expect(find.text('이미 사용 중인 닉네임이에요.'), findsNothing);
    });

    testWidgets('a network failure shows a Snackbar and keeps the screen so it can be retried', (tester) async {
      final s = await pumpEdit(tester);
      s.members.updateError = dioFailure('/v7/members/me');

      await tester.enterText(find.byType(TextField).at(1), '새닉네임');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('네트워크 상태를 확인하고 다시 시도해 주세요.'), findsOneWidget);
      expect(s.auth.status, AuthStatus.signedIn);
      expect(find.text('마이 화면'), findsNothing);
    });

    testWidgets('a too short nickname is rejected before any request', (tester) async {
      final s = await pumpEdit(tester);

      await tester.enterText(find.byType(TextField).at(1), 'a');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('닉네임은 2~12자로 입력해 주세요.'), findsOneWidget);
      expect(s.members.nicknames, isEmpty);
    });

    testWidgets('while saving the button spins and back is blocked', (tester) async {
      final s = await pumpEdit(tester);
      s.members.delay = const Duration(milliseconds: 300);

      await tester.enterText(find.byType(TextField).at(1), '새닉네임');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '저장'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pump();
      expect(find.text('변경 내용을 버릴까요?'), findsNothing);
      expect(find.text('마이 화면'), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('back without changes leaves immediately', (tester) async {
      await pumpEdit(tester);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.text('마이 화면'), findsOneWidget);
      expect(find.text('변경 내용을 버릴까요?'), findsNothing);
    });

    testWidgets('back with unsaved changes asks first: "계속 수정" stays, "나가기" returns to the my page', (
      tester,
    ) async {
      await pumpEdit(tester);
      await tester.enterText(find.byType(TextField).at(1), '바꾼닉네임');
      await tester.pump();

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      expect(find.text('변경 내용을 버릴까요?'), findsOneWidget);
      expect(find.text('저장하지 않은 내용은 사라집니다.'), findsOneWidget);

      await tester.tap(find.text('계속 수정'));
      await tester.pumpAndSettle();
      expect(find.text('변경 내용을 버릴까요?'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '바꾼닉네임');
      expect(find.text('마이 화면'), findsNothing);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.text('마이 화면'), findsOneWidget);
    });

    testWidgets('the system back gesture goes through the same confirmation', (tester) async {
      await pumpEdit(tester);
      await tester.enterText(find.byType(TextField).at(1), '바꾼닉네임');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('변경 내용을 버릴까요?'), findsOneWidget);
    });
  });
}
