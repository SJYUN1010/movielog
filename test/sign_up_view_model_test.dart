import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fakes.dart';

void main() {
  group('SignUpViewModel nickname', () {
    test('goes idle → checking → available', () async {
      final service = FakeSignUpService(delay: const Duration(milliseconds: 10));
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
      final viewModel = SignUpViewModel(FakeSignUpService());

      viewModel.onNicknameChanged('영화광');
      expect(viewModel.canCheckNickname, isTrue);
      await viewModel.checkNickname('영화광');

      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
      expect(viewModel.nicknameErrorText, duplicatedNicknameMessage);
      expect(viewModel.canCheckNickname, isFalse);
    });

    test('editing the value clears the previous result immediately', () async {
      final viewModel = SignUpViewModel(FakeSignUpService());
      viewModel.onNicknameChanged('영화광');
      await viewModel.checkNickname('영화광');

      viewModel.onNicknameChanged('영화광2');

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
      expect(viewModel.canCheckNickname, isTrue);
    });

    test('an available result is also cleared when the input changes', () async {
      final viewModel = SignUpViewModel(FakeSignUpService());
      viewModel.onNicknameChanged('새닉네임');
      await viewModel.checkNickname('새닉네임');
      expect(viewModel.nicknameCheckStatus, CheckStatus.available);

      viewModel.onNicknameChanged('새닉네임!');

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    });

    test('typing the previously duplicated value again restores the error without asking the server', () async {
      final service = FakeSignUpService();
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
      final service = FakeSignUpService()..fail = true;
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
      final service = FakeSignUpService(delay: const Duration(milliseconds: 30));
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('영화광');

      final pending = viewModel.checkNickname('영화광');
      viewModel.onNicknameChanged('다른닉네임');
      await pending;

      expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
      expect(viewModel.nicknameErrorText, isNull);
    });

    test('cannot be pressed while checking, so the same request is not sent twice', () async {
      final service = FakeSignUpService(delay: const Duration(milliseconds: 20));
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('새닉네임');

      final first = viewModel.checkNickname('새닉네임');
      expect(viewModel.canCheckNickname, isFalse);
      final second = viewModel.checkNickname('새닉네임');
      await Future.wait([first, second]);

      expect(service.nicknameCalls, hasLength(1));
    });

    test('empty or too short values cannot be checked', () async {
      final service = FakeSignUpService();
      final viewModel = SignUpViewModel(service);

      viewModel.onNicknameChanged('');
      expect(viewModel.canCheckNickname, isFalse);
      viewModel.onNicknameChanged('가');
      expect(viewModel.canCheckNickname, isFalse);
      await viewModel.checkNickname('가');

      expect(service.nicknameCalls, isEmpty);
    });

    test('surrounding spaces are trimmed before asking the server', () async {
      final service = FakeSignUpService();
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('  영화광  ');

      await viewModel.checkNickname('  영화광  ');

      expect(service.nicknameCalls, ['영화광']);
      expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    });

    test('a response after dispose does not notify', () async {
      final service = FakeSignUpService(delay: const Duration(milliseconds: 20));
      final viewModel = SignUpViewModel(service);
      viewModel.onNicknameChanged('새닉네임');

      final pending = viewModel.checkNickname('새닉네임');
      viewModel.dispose();

      await expectLater(pending, completes);
    });
  });

  group('SignUpViewModel email', () {
    test('uses the same structure as nickname', () async {
      final service = FakeSignUpService();
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
      final viewModel = SignUpViewModel(FakeSignUpService());

      viewModel.onEmailChanged('movie@');

      expect(viewModel.canCheckEmail, isFalse);
    });

    test('nickname and email states do not affect each other', () async {
      final viewModel = SignUpViewModel(FakeSignUpService());
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
      final viewModel = SignUpViewModel(FakeSignUpService());
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

  group('SignUpViewModel submit', () {
    const request = CreateMemberRequest(
      email: 'new@umc.com',
      password: 'Passw0rd!',
      nickname: '무비러버',
    );

    test('a 201 stores the memberId read from result and ends in success', () async {
      final service = FakeSignUpService()..nextMemberId = 31;
      final viewModel = SignUpViewModel(service);
      final statuses = <SubmitStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.submitStatus));

      await viewModel.submit(request);

      expect(statuses, [SubmitStatus.submitting, SubmitStatus.success]);
      expect(viewModel.createdMemberId, 31);
      expect(viewModel.snackbarMessage, isNull);
      expect(viewModel.passwordErrorText, isNull);
      expect(service.signUpRequests.single.nickname, '무비러버');
    });

    test('a missing memberId is not treated as a completed sign up', () async {
      final service = FakeSignUpService()..missingResult = true;
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.createdMemberId, isNull);
      expect(viewModel.snackbarMessage, unknownSignUpResultMessage);
    });

    test('a 400 about the password goes to passwordErrorText, not the snackbar', () async {
      final service = FakeSignUpService()
        ..signUpError = commonFailure(
          400,
          'COMMON400',
          '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
        );
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.passwordErrorText, contains('비밀번호는'));
      expect(viewModel.snackbarMessage, isNull);
    });

    test('another 400 and a 409 go to the snackbar with the server message', () async {
      for (final failure in [
        commonFailure(400, 'COMMON400', '요청 값이 올바르지 않습니다.'),
        commonFailure(409, 'COMMON409', '이미 사용 중인 이메일입니다.'),
      ]) {
        final service = FakeSignUpService()..signUpError = failure;
        final viewModel = SignUpViewModel(service);

        await viewModel.submit(request);

        expect(viewModel.passwordErrorText, isNull);
        expect(
          viewModel.snackbarMessage,
          (failure.response!.data as Map<String, dynamic>)['message'],
        );
      }
    });

    test('a network failure gets the generic message', () async {
      final service = FakeSignUpService()..signUpError = dioFailure('/v6/members');
      final viewModel = SignUpViewModel(service);

      await viewModel.submit(request);

      expect(viewModel.snackbarMessage, '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    });

    test('a second submit while one is running is ignored', () async {
      final service = FakeSignUpService()..signUpDelay = const Duration(milliseconds: 20);
      final viewModel = SignUpViewModel(service);

      final first = viewModel.submit(request);
      expect(viewModel.isSubmitting, isTrue);
      final second = viewModel.submit(request);
      await Future.wait([first, second]);

      expect(service.signUpRequests, hasLength(1));
    });

    test('editing the password clears the server password error', () async {
      final service = FakeSignUpService()
        ..signUpError = commonFailure(400, 'COMMON400', '비밀번호는 형식에 맞아야 합니다.');
      final viewModel = SignUpViewModel(service);
      await viewModel.submit(request);
      expect(viewModel.passwordErrorText, isNotNull);

      viewModel.onPasswordChanged();

      expect(viewModel.passwordErrorText, isNull);
    });

    test('editing the nickname or email invalidates the previous submit error', () async {
      final service = FakeSignUpService()
        ..signUpError = commonFailure(409, 'COMMON409', '이미 사용 중인 이메일입니다.');
      final viewModel = SignUpViewModel(service);
      await viewModel.submit(request);
      expect(viewModel.submitStatus, SubmitStatus.error);

      viewModel.onEmailChanged('another@umc.com');

      expect(viewModel.submitStatus, SubmitStatus.idle);
      expect(viewModel.snackbarMessage, isNull);
    });

    test('a retry after a failure starts clean and can succeed', () async {
      final service = FakeSignUpService()..signUpError = dioFailure('/v6/members');
      final viewModel = SignUpViewModel(service);
      await viewModel.submit(request);

      service.signUpError = null;
      await viewModel.submit(request);

      expect(viewModel.submitStatus, SubmitStatus.success);
      expect(viewModel.snackbarMessage, isNull);
    });

    test('a result after dispose does not notify', () async {
      final service = FakeSignUpService()..signUpDelay = const Duration(milliseconds: 20);
      final viewModel = SignUpViewModel(service);

      final pending = viewModel.submit(request);
      viewModel.dispose();

      await expectLater(pending, completes);
    });
  });
}
