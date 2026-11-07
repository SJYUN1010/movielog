import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/signup_screen.dart';
import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, FakeMemberCheckService service) async {
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
  await tester.enterText(fields.at(2), 'password123');
  await tester.pump();
}

void main() {
  group('SignUpScreen', () {
    testWidgets('starts empty: check buttons disabled, nothing is flagged', (tester) async {
      final service = FakeMemberCheckService();
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
      await _pump(tester, FakeMemberCheckService());

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
      final service = FakeMemberCheckService(delay: const Duration(milliseconds: 100));
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
      final service = FakeMemberCheckService();
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
      final service = FakeMemberCheckService();
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
      final service = FakeMemberCheckService();
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
      final service = FakeMemberCheckService()..fail = true;
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
      await _pump(tester, FakeMemberCheckService());
      await tester.enterText(find.byType(TextFormField).at(1), 'movie@umc.com');
      await tester.pump();

      await tester.tap(_checkButton(1));
      await tester.pumpAndSettle();

      expect(find.text('이미 사용 중인 이메일입니다.'), findsOneWidget);
    });

    testWidgets('submit needs both checks, a valid password and the terms', (tester) async {
      await _pump(tester, FakeMemberCheckService());
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
      await _pump(tester, FakeMemberCheckService());

      final submitWidth = tester.getSize(_submit).width;
      final checkWidth = tester.getSize(_checkButton(0)).width;

      expect(submitWidth, greaterThan(300));
      expect(checkWidth, lessThan(140));
      expect(tester.getSize(_checkButton(0)).height, 44);
    });
  });
}
