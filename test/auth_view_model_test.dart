import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/auth_view_model.dart';

import 'support/fakes.dart';

class _Harness {
  _Harness({String? token}) : storage = MemoryTokenStorage(token) {
    viewModel = AuthViewModel(auth, members, storage);
  }

  final auth = FakeAuthApiService();
  final members = FakeMemberApiService();
  final MemoryTokenStorage storage;
  late final AuthViewModel viewModel;
}

void main() {
  group('login', () {
    test('saves the token, becomes signedIn, and does not call GET me itself', () async {
      final h = _Harness();
      await h.viewModel.restoreSession(); // 토큰 없음 → signedOut
      expect(h.viewModel.status, AuthStatus.signedOut);

      await h.viewModel.login('movie@example.com', 'Umc1234!');

      expect(h.viewModel.status, AuthStatus.signedIn);
      expect(h.storage.token, 'secret-token-1');
      expect(h.members.fetchCount, 0); // 내 정보는 MainScreen.loadMember()가 불러옵니다.
      expect(h.viewModel.member, isNull);
      expect(h.viewModel.sessionExpired, isFalse);
    });

    test('sends the trimmed email and never keeps the password', () async {
      final h = _Harness();

      await h.viewModel.login('  movie@example.com  ', 'Umc1234!');

      expect(h.auth.requests.single.email, '  movie@example.com  ');
      expect(h.auth.requests.single.toJson()['email'], 'movie@example.com');
      expect(h.auth.requests.single.toString(), isNot(contains('Umc1234!')));
      expect(h.viewModel.message, isNull);
    });

    test('AUTH401_1 is a form error: signedOut, no expiry flag, no token saved', () async {
      final h = _Harness();
      h.auth.error = commonFailure(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.');

      await h.viewModel.login('movie@example.com', 'wrong');

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.viewModel.message, loginFailedMessage);
      expect(h.viewModel.sessionExpired, isFalse);
      expect(h.storage.token, isNull);
    });

    test('a network failure is not reported as a wrong password', () async {
      final h = _Harness();
      h.auth.error = dioFailure('/v7/auth/login');

      await h.viewModel.login('movie@example.com', 'Umc1234!');

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.viewModel.message, loginRequestFailedMessage);
    });

    test('a token write failure is its own message and does not sign in', () async {
      final h = _Harness();
      h.storage.failWrite = true;

      await h.viewModel.login('movie@example.com', 'Umc1234!');

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.viewModel.message, tokenSaveFailedMessage);
    });

    test('ignores a second login while one is running', () async {
      final h = _Harness();
      h.auth.delay = const Duration(milliseconds: 20);

      final first = h.viewModel.login('movie@example.com', 'Umc1234!');
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      await first;

      expect(h.auth.requests, hasLength(1));
    });

    test('a login response that arrives after logout is dropped', () async {
      final h = _Harness();
      h.auth.delay = const Duration(milliseconds: 20);

      final login = h.viewModel.login('movie@example.com', 'Umc1234!');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.viewModel.logout();
      await login;

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.storage.token, isNull);
    });
  });

  group('restoreSession', () {
    test('without a token it goes to signedOut and never calls GET me', () async {
      final h = _Harness();

      await h.viewModel.restoreSession();

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.members.fetchCount, 0);
    });

    test('a stored token only counts after GET me succeeds', () async {
      final h = _Harness(token: 'stored-token');
      h.members.delay = const Duration(milliseconds: 20);

      final restoring = h.viewModel.restoreSession();
      expect(h.viewModel.status, AuthStatus.initializing);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.viewModel.status, AuthStatus.initializing); // 토큰이 있어도 아직 검증 전입니다.
      await restoring;

      expect(h.viewModel.status, AuthStatus.signedIn);
      expect(h.viewModel.member?.nickname, '무비러버');
      expect(h.viewModel.memberStatus, MemberLoadStatus.success);
    });

    test('AUTH401_2/3/4 clear the token and flag the expiry', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        final h = _Harness(token: 'stored-token');
        h.members
          ..meError = commonFailure(401, code, '만료')
          ..failMeTimes = 1;

        await h.viewModel.restoreSession();

        expect(h.viewModel.status, AuthStatus.signedOut, reason: code);
        expect(h.viewModel.sessionExpired, isTrue, reason: code);
        expect(h.storage.token, isNull, reason: code);
      }
    });

    test('a network failure keeps the token and asks for a retry instead of signing out', () async {
      final h = _Harness(token: 'stored-token');
      h.members
        ..meError = dioFailure('/v7/members/me')
        ..failMeTimes = 1;

      await h.viewModel.restoreSession();

      expect(h.viewModel.status, AuthStatus.retryRequired);
      expect(h.viewModel.message, sessionCheckFailedMessage);
      expect(h.storage.token, 'stored-token');
      expect(h.storage.deleteCount, 0);

      await h.viewModel.restoreSession(); // 다시 시도
      expect(h.viewModel.status, AuthStatus.signedIn);
    });

    test('a 5xx is also a retry, not an expiry', () async {
      final h = _Harness(token: 'stored-token');
      h.members
        ..meError = dioFailure('/v7/members/me', statusCode: 500, data: {'message': 'x'})
        ..failMeTimes = 1;

      await h.viewModel.restoreSession();

      expect(h.viewModel.status, AuthStatus.retryRequired);
      expect(h.storage.token, 'stored-token');
    });

    test('a storage read failure is its own retry message', () async {
      final h = _Harness(token: 'stored-token');
      h.storage.failRead = true;

      await h.viewModel.restoreSession();

      expect(h.viewModel.status, AuthStatus.retryRequired);
      expect(h.viewModel.message, storageReadFailedMessage);
    });
  });

  group('loadMember', () {
    test('loads once, reuses the member, and refetches only when forced', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');

      await h.viewModel.loadMember();
      await h.viewModel.loadMember();
      expect(h.members.fetchCount, 1);

      await h.viewModel.loadMember(force: true);
      expect(h.members.fetchCount, 2);
    });

    test('does nothing unless signed in', () async {
      final h = _Harness();

      await h.viewModel.loadMember();

      expect(h.members.fetchCount, 0);
    });

    test('a network failure leaves a retryable error and keeps the session', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      h.members
        ..meError = dioFailure('/v7/members/me')
        ..failMeTimes = 1;

      await h.viewModel.loadMember();

      expect(h.viewModel.memberStatus, MemberLoadStatus.error);
      expect(h.viewModel.status, AuthStatus.signedIn);
      expect(h.storage.token, 'secret-token-1');

      await h.viewModel.loadMember(force: true);
      expect(h.viewModel.memberStatus, MemberLoadStatus.success);
    });

    test('an expired token signs out with the expiry flag', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      h.members
        ..meError = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다.')
        ..failMeTimes = 1;

      await h.viewModel.loadMember();

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.viewModel.sessionExpired, isTrue);
      expect(h.storage.token, isNull);
    });

    test('a late response from the previous session does not fill the new one', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      h.members.delay = const Duration(milliseconds: 20);

      final loading = h.viewModel.loadMember();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await h.viewModel.logout();
      await loading;

      expect(h.viewModel.member, isNull);
      expect(h.viewModel.status, AuthStatus.signedOut);
    });
  });

  group('logout and expiry', () {
    test('logout clears token and member without the expiry flag', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      await h.viewModel.loadMember();

      await h.viewModel.logout();

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.viewModel.member, isNull);
      expect(h.viewModel.sessionExpired, isFalse);
      expect(h.storage.token, isNull);
    });

    test('several 401s expire the session only once', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      final version = h.viewModel.sessionVersion;
      var notifications = 0;
      h.viewModel.addListener(() => notifications++);

      await Future.wait([
        h.viewModel.expireSession(fromVersion: version),
        h.viewModel.expireSession(fromVersion: version),
        h.viewModel.expireSession(fromVersion: version),
      ]);

      expect(h.storage.deleteCount, 1);
      expect(notifications, lessThanOrEqualTo(2));
      expect(h.viewModel.sessionExpired, isTrue);
    });

    test('a 401 that belongs to an older session cannot sign out the new one', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      final oldVersion = h.viewModel.sessionVersion;
      await h.viewModel.logout();
      await h.viewModel.login('movie@example.com', 'Umc1234!');

      await h.viewModel.expireSession(fromVersion: oldVersion);

      expect(h.viewModel.status, AuthStatus.signedIn);
      expect(h.storage.token, 'secret-token-1');
    });

    test('a failed token delete is reported instead of ignored', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      h.storage.failDelete = true;

      await h.viewModel.logout();

      expect(h.viewModel.status, AuthStatus.signedOut);
      expect(h.viewModel.message, storageClearFailedMessage);
    });

    test('consumeSessionExpired turns the flag off so the notice shows once', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      await h.viewModel.expireSession();

      expect(h.viewModel.sessionExpired, isTrue);
      h.viewModel.consumeSessionExpired();
      expect(h.viewModel.sessionExpired, isFalse);
    });

    test('a new login resets the expiry flag', () async {
      final h = _Harness();
      await h.viewModel.login('movie@example.com', 'Umc1234!');
      await h.viewModel.expireSession();

      await h.viewModel.login('movie@example.com', 'Umc1234!');

      expect(h.viewModel.sessionExpired, isFalse);
      expect(h.viewModel.status, AuthStatus.signedIn);
    });
  });

  test('updateMember replaces the member only while signed in', () async {
    final h = _Harness();
    h.viewModel.updateMember(memberInfo(nickname: '무시됨'));
    expect(h.viewModel.member, isNull);

    await h.viewModel.login('movie@example.com', 'Umc1234!');
    h.viewModel.updateMember(memberInfo(nickname: '새닉네임'));

    expect(h.viewModel.member?.nickname, '새닉네임');
  });
}
