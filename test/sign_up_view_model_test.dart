import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fakes.dart';

void main() {
  group('SignUpViewModel nickname', () {
    test('goes idle → checking → available', () async {
      final service = FakeMemberCheckService(delay: const Duration(milliseconds: 10));
      final viewModel = SignUpViewModel(service);
      final statuses = <CheckStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.nicknameCheckStatus));

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      viewModel.onNicknameChanged('새닉네임');
      await viewModel.checkNickname('새닉네임');

      expect(statuses, [CheckStatus.idle, CheckStatus.checking, CheckStatus.available]);
      expect(viewModel.nicknameErrorText, isNull);
      expect(service.nicknameCalls, ['새닉네임']);
    });

    test('a taken nickname becomes duplicated with an error text and locks the button', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());

      viewModel.onNicknameChanged('영화광');
      expect(viewModel.canCheckNickname, isTrue);
      await viewModel.checkNickname('영화광');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, duplicatedNicknameMessage);
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('editing the value clears the previous result immediately', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');

      viewModel.onNicknameChanged('영화광2');

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
      expect(viewModel.canCheckNickname, isTrue);
    });

    test('an available result is also cleared when the input changes', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('새닉네임');
      await viewModel.checkNickname('새닉네임');
      expect(viewModel.nicknameCheckStatus, CheckStatus.available);

      viewModel.onNicknameChanged('새닉네임!');

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    });

    test('typing the previously duplicated value again restores the error without asking the server', () async {
      final service = FakeMemberCheckService();
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');
      viewModel.onNicknameChanged('영화광2');
      expect(service.nicknameCalls, hasLength(1));

      viewModel.onNicknameChanged('영화광');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, duplicatedNicknameMessage);
      expect(viewModel.canCheckNickname, isFalse);
      expect(service.nicknameCalls, hasLength(1));
    });

    test('a communication failure is a different state and text from a duplicate', () async {
      final service = FakeMemberCheckService()..fail = true;
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('영화광');

      await viewModel.checkNickname('영화광');

      expect(viewModel.nicknameCheckStatus, CheckStatus.error);
      expect(viewModel.nicknameErrorText, checkFailedMessage);
      expect(viewModel.nicknameErrorText, isNot(duplicatedNicknameMessage));
      // 통신 실패는 중복이 아니므로 버튼을 다시 눌러 재시도할 수 있습니다.
      expect(viewModel.canCheckNickname, isTrue);

      service.fail = false;
      await viewModel.checkNickname('영화광');
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    });

    test('a response that arrives after the input changed is ignored', () async {
      final service = FakeMemberCheckService(delay: const Duration(milliseconds: 30));
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('영화광');

      final pending = viewModel.checkNickname('영화광');
      viewModel.onNicknameChanged('다른닉네임');
      await pending;

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('cannot be pressed while checking, so the same request is not sent twice', () async {
      final service = FakeMemberCheckService(delay: const Duration(milliseconds: 20));
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('새닉네임');

      final first = viewModel.checkNickname('새닉네임');
      expect(viewModel.canCheckNickname, isFalse);
      final second = viewModel.checkNickname('새닉네임');
      await Future.wait([first, second]);

      expect(service.nicknameCalls, hasLength(1));
    });

    test('empty or too short values cannot be checked', () async {
      final service = FakeMemberCheckService();
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('');
      expect(viewModel.canCheckNickname, isFalse);
      viewModel.onNicknameChanged('가');
      expect(viewModel.canCheckNickname, isFalse);
      await viewModel.checkNickname('가');

      expect(service.nicknameCalls, isEmpty);
    });

    test('surrounding spaces are trimmed before asking the server', () async {
      final service = FakeMemberCheckService();
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('  영화광  ');

      await viewModel.checkNickname('  영화광  ');

      expect(service.nicknameCalls, ['영화광']);
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    });

    test('a response after dispose does not notify', () async {
      final service = FakeMemberCheckService(delay: const Duration(milliseconds: 20));
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('새닉네임');

      final pending = viewModel.checkNickname('새닉네임');
      viewModel.dispose();

      await expectLater(pending, completes);
    });
  });

  group('SignUpViewModel email', () {
    test('uses the same structure as nickname', () async {
      final service = FakeMemberCheckService();
      final viewModel = SignUpViewModel(service);

      viewModel.onEmailChanged('movie@umc.com');
      await viewModel.checkEmail('movie@umc.com');
      expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
      expect(viewModel.emailErrorText, duplicatedEmailMessage);
      expect(viewModel.canCheckEmail, isFalse);

      viewModel.onEmailChanged('new@umc.com');
      expect(viewModel.emailCheckStatus, CheckStatus.idle);
      await viewModel.checkEmail('new@umc.com');
      expect(viewModel.emailCheckStatus, CheckStatus.available);

      viewModel.onEmailChanged('movie@umc.com');
      expect(viewModel.emailCheckStatus, CheckStatus.duplicated);
      expect(service.emailCalls, ['movie@umc.com', 'new@umc.com']);
    });

    test('an invalid email format cannot be checked', () {
      final viewModel = SignUpViewModel(FakeMemberCheckService());

      viewModel.onEmailChanged('movie@');

      expect(viewModel.canCheckEmail, isFalse);
    });

    test('nickname and email states do not affect each other', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('영화광');
      viewModel.onEmailChanged('new@umc.com');

      await viewModel.checkNickname('영화광');
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.emailCheckStatus, CheckStatus.idle);

      await viewModel.checkEmail('new@umc.com');
      expect(viewModel.emailCheckStatus, CheckStatus.available);
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);

      viewModel.onEmailChanged('another@umc.com');
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    });

    test('bothAvailable needs both fields confirmed', () async {
      final viewModel = SignUpViewModel(FakeMemberCheckService());
      viewModel.onNicknameChanged('새닉네임');
      viewModel.onEmailChanged('new@umc.com');
      expect(viewModel.bothAvailable, isFalse);

      await viewModel.checkNickname('새닉네임');
      expect(viewModel.bothAvailable, isFalse);

      await viewModel.checkEmail('new@umc.com');
      expect(viewModel.bothAvailable, isTrue);

      viewModel.onNicknameChanged('새닉네임2');
      expect(viewModel.bothAvailable, isFalse);
    });
  });
}
