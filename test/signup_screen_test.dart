import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, FakeSignUpService service) async {
  _useMobileViewport(tester);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SignUpViewModel(service),
      child: MaterialApp(theme: AppTheme.light, home: const SignUpScreen()),
    ),
  );
}

Finder _checkButton(int index) =>
    find.widgetWithText(MovieLogButton, '중복 확인').at(index);

ElevatedButton _buttonOf(WidgetTester tester, Finder button) =>
    tester.widget<ElevatedButton>(
      find.descendant(of: button, matching: find.byType(ElevatedButton)),
    );

Finder get _submit => find.widgetWithText(MovieLogButton, '가입하기');

Future<void> _enterAll(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), '새닉네임');
  await tester.enterText(fields.at(1), 'new@umc.com');
  await tester.enterText(fields.at(2), 'Password1!');
  await tester.pump();
}

void main() {
  group('SignUpScreen', () {
    testWidgets('starts empty: check buttons disabled, nothing is flagged', (tester) async {
      final service = FakeSignUpService();
      await _pump(tester, service);

      expect(find.text('닉네임'), findsOneWidget);
      expect(find.text('이메일'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(_buttonOf(tester, _checkButton(0)).onPressed, isNull);
      expect(_buttonOf(tester, _checkButton(1)).onPressed, isNull);
      expect(_buttonOf(tester, _submit).onPressed, isNull);
      expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsNothing);
    });

    testWidgets('shows the form validation errors for invalid input', (tester) async {
      await _pump(tester, FakeSignUpService());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'a');
      await tester.enterText(fields.at(1), 'test@');
      await tester.enterText(fields.at(2), '123');
      await tester.pump();

      expect(find.text('닉네임은 2자 이상이어야 합니다.'), findsOneWidget);
      expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
      expect(find.text('비밀번호는 8자 이상이어야 합니다.'), findsOneWidget);
      expect(_buttonOf(tester, _checkButton(0)).onPressed, isNull);
      expect(_buttonOf(tester, _checkButton(1)).onPressed, isNull);
    });

    testWidgets('checking shows a gray disabled button with only an indicator', (tester) async {
      final service = FakeSignUpService(delay: const Duration(milliseconds: 100));
      await _pump(tester, service);
      await tester.enterText(find.byType(TextFormField).at(0), '새닉네임');
      await tester.pump();

      await tester.tap(_checkButton(0));
      await tester.pump();

      expect(find.text('닉네임 사용 가능 여부를 확인 중입니다.'), findsOneWidget);
      final button = find.widgetWithText(MovieLogButton, '중복 확인');
      // 통신 중인 닉네임 버튼은 라벨 대신 인디케이터만 그립니다.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(button, findsOneWidget); // 이메일 버튼의 라벨만 남습니다.

      await tester.pump(const Duration(milliseconds: 150));
    });

    testWidgets('an available nickname shows the success text and a check icon', (tester) async {
      final service = FakeSignUpService();
      await _pump(tester, service);
      await tester.enterText(find.byType(TextFormField).at(0), '새닉네임');
      await tester.pump();

      await tester.tap(_checkButton(0));
      await tester.pumpAndSettle();

      expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);
      expect(service.nicknameCalls, ['새닉네임']);
    });

    testWidgets('a taken nickname turns the field into an error and locks the button', (
      tester,
    ) async {
      final service = FakeSignUpService();
      await _pump(tester, service);
      await tester.enterText(find.byType(TextFormField).at(0), '영화광');
      await tester.pump();

      await tester.tap(_checkButton(0));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(_buttonOf(tester, _checkButton(0)).onPressed, isNull);
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator).first)
          .decoration;
      expect(decoration.fillColor, AppColors.errorFill);
    });

    testWidgets('editing clears the old result, retyping the same text restores it instantly', (
      tester,
    ) async {
      final service = FakeSignUpService();
      await _pump(tester, service);
      final nickname = find.byType(TextFormField).at(0);
      await tester.enterText(nickname, '영화광');
      await tester.pump();
      await tester.tap(_checkButton(0));
      await tester.pumpAndSettle();
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);

      await tester.enterText(nickname, '영화광2');
      await tester.pump();
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsNothing);
      expect(_buttonOf(tester, _checkButton(0)).onPressed, isNotNull);

      await tester.enterText(nickname, '영화광');
      await tester.pump();
      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(_buttonOf(tester, _checkButton(0)).onPressed, isNull);
      expect(service.nicknameCalls, hasLength(1));
    });

    testWidgets('a communication failure shows a different message from a duplicate', (
      tester,
    ) async {
      final service = FakeSignUpService()..fail = true;
      await _pump(tester, service);
      await tester.enterText(find.byType(TextFormField).at(1), 'new@umc.com');
      await tester.pump();

      await tester.tap(_checkButton(1));
      await tester.pumpAndSettle();

      expect(find.text(checkFailedMessage), findsOneWidget);
      expect(find.text('이미 사용 중인 이메일입니다.'), findsNothing);
      expect(_buttonOf(tester, _checkButton(1)).onPressed, isNotNull);
    });

    testWidgets('a taken email shows its own duplicate message', (tester) async {
      await _pump(tester, FakeSignUpService());
      await tester.enterText(find.byType(TextFormField).at(1), 'movie@umc.com');
      await tester.pump();

      await tester.tap(_checkButton(1));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
    });

    testWidgets('submit needs both checks, a valid password and the terms', (tester) async {
      await _pump(tester, FakeSignUpService());
      await _enterAll(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(_buttonOf(tester, _submit).onPressed, isNull);

      await tester.tap(_checkButton(0));
      await tester.pumpAndSettle();
      expect(_buttonOf(tester, _submit).onPressed, isNull);

      await tester.tap(_checkButton(1));
      await tester.pumpAndSettle();
      expect(_buttonOf(tester, _submit).onPressed, isNotNull);

      await tester.enterText(find.byType(TextFormField).at(0), '새닉네임2');
      await tester.pump();
      expect(_buttonOf(tester, _submit).onPressed, isNull);
    });

    testWidgets('the submit button is full width and the check buttons hug their label', (
      tester,
    ) async {
      await _pump(tester, FakeSignUpService());

      final submitWidth = tester.getSize(_submit).width;
      final checkWidth = tester.getSize(_checkButton(0)).width;

      expect(submitWidth, greaterThan(300));
      expect(checkWidth, lessThan(140));
      expect(tester.getSize(_checkButton(0)).height, 44);
    });
  });

  group('SignUpScreen submit (v6)', () {
    Future<LearningMemberSession> pumpWithRouter(
      WidgetTester tester,
      FakeSignUpService service,
    ) async {
      _useMobileViewport(tester);
      final session = LearningMemberSession();
      final router = GoRouter(
        initialLocation: '/signup',
        routes: [
          GoRoute(
            path: '/signup',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => SignUpViewModel(service),
              child: const SignUpScreen(),
            ),
          ),
          GoRoute(path: '/movies', builder: (context, state) => const Scaffold(body: Text('영화 목록 화면'))),
          GoRoute(path: '/start', builder: (context, state) => const Scaffold(body: Text('시작 화면'))),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<LearningMemberSession>.value(
          value: session,
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      return session;
    }

    Future<void> fillAndCheckAll(WidgetTester tester) async {
      await _enterAll(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(_checkButton(0));
      await tester.pumpAndSettle();
      await tester.tap(_checkButton(1));
      await tester.pumpAndSettle();
    }

    testWidgets('a successful sign up stores the memberId and goes to /movies', (tester) async {
      final service = FakeSignUpService()..nextMemberId = 31;
      final session = await pumpWithRouter(tester, service);
      await fillAndCheckAll(tester);

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(service.signUpRequests, hasLength(1));
      expect(service.signUpRequests.single.nickname, '새닉네임');
      expect(session.memberId, 31);
      expect(find.text('영화 목록 화면'), findsOneWidget);
    });

    testWidgets('a final 409 is shown in a Snackbar and the screen stays', (tester) async {
      final service = FakeSignUpService()
        ..signUpError = commonFailure(409, 'COMMON409', '이미 사용 중인 이메일입니다.');
      final session = await pumpWithRouter(tester, service);
      await fillAndCheckAll(tester);

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget); // Snackbar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(session.memberId, isNull);
      expect(find.text('영화 목록 화면'), findsNothing);
      expect(find.text('환영합니다!'), findsOneWidget);
    });

    testWidgets('a password 400 is shown on the password field, not in a Snackbar, until it is edited', (
      tester,
    ) async {
      const serverMessage = '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.';
      final service = FakeSignUpService()
        ..signUpError = commonFailure(400, 'COMMON400', serverMessage);
      await pumpWithRouter(tester, service);
      await fillAndCheckAll(tester);

      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(find.text(serverMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      // 로컬 형식 검사는 통과했지만 서버가 거부한 값이라 계속 에러로 보입니다.
      await tester.enterText(find.byType(TextFormField).at(2), 'Passw0rd!x');
      await tester.pump();
      expect(find.text(serverMessage), findsNothing);
    });

    testWidgets('while submitting: loading button, no second request, no back', (tester) async {
      final service = FakeSignUpService()..signUpDelay = const Duration(milliseconds: 300);
      await pumpWithRouter(tester, service);
      await fillAndCheckAll(tester);

      await tester.tap(_submit);
      await tester.pump();

      final submit = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(ElevatedButton),
      );
      expect(submit, findsOneWidget);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      expect(service.signUpRequests, hasLength(1));

      // 뒤로가기(시스템/앱바)를 눌러도 화면을 벗어나지 못합니다.
      await tester.binding.handlePopRoute();
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pump();
      expect(find.text('시작 화면'), findsNothing);
      expect(find.text('환영합니다!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('영화 목록 화면'), findsOneWidget);
    });

    testWidgets('after a failed submit the screen can be left again', (tester) async {
      final service = FakeSignUpService()..signUpError = dioFailure('/v6/members');
      await pumpWithRouter(tester, service);
      await fillAndCheckAll(tester);
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.text('시작 화면'), findsOneWidget);
    });
  });
}
