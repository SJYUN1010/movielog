import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';

import 'support/fakes.dart';

class _Harness {
  final auth = FakeAuthApiService();
  final members = FakeMemberApiService();
  final storage = MemoryTokenStorage();
  late final AuthViewModel authViewModel = AuthViewModel(auth, members, storage);
  late final EditProfileViewModel viewModel = EditProfileViewModel(members, authViewModel);

  Future<void> signIn() async {
    await authViewModel.login('movie@example.com', 'Umc1234!');
    await authViewModel.loadMember();
  }
}

void main() {
  test('validates 2~12 characters before sending anything', () async {
    final h = _Harness();
    await h.signIn();

    expect(await h.viewModel.save('a'), isFalse);
    expect(h.viewModel.nicknameError, nicknameLengthMessage);
    expect(await h.viewModel.save('가' * 13), isFalse);
    expect(await h.viewModel.save('   '), isFalse);
    expect(h.members.nicknames, isEmpty);
  });

  test('a changed nickname is saved and replaces the member without another GET me', () async {
    final h = _Harness();
    await h.signIn();
    final fetches = h.members.fetchCount;

    final saved = await h.viewModel.save('  새닉네임  ');

    expect(saved, isTrue);
    expect(h.members.nicknames, ['새닉네임']); // 앞뒤 공백은 보내지 않습니다.
    expect(h.authViewModel.member?.nickname, '새닉네임');
    expect(h.members.fetchCount, fetches);
    expect(h.viewModel.status, EditProfileStatus.success);
  });

  test('the same nickname completes without a request (and is never a 409)', () async {
    final h = _Harness();
    await h.signIn();

    expect(await h.viewModel.save('무비러버'), isTrue);

    expect(h.members.nicknames, isEmpty);
  });

  test('MEMBER409_1 shows the duplicate message under the field and keeps the session', () async {
    final h = _Harness();
    await h.signIn();
    h.members.updateError = commonFailure(409, 'MEMBER409_1', '이미 사용 중인 닉네임입니다.');

    expect(await h.viewModel.save('taken'), isFalse);

    expect(h.viewModel.nicknameError, nicknameTakenMessage);
    expect(h.viewModel.message, isNull);
    expect(h.authViewModel.member?.nickname, '무비러버'); // 실패하면 내 정보는 그대로입니다.
    expect(h.authViewModel.status, AuthStatus.signedIn);
  });

  test('COMMON400 shows the server message under the field', () async {
    final h = _Harness();
    await h.signIn();
    h.members.updateError = commonFailure(400, 'COMMON400', '닉네임은 2자 이상 12자 이하여야 합니다.');

    await h.viewModel.save('abcdef');

    expect(h.viewModel.nicknameError, '닉네임은 2자 이상 12자 이하여야 합니다.');
  });

  test('a network failure is a retryable snackbar message and does not sign out', () async {
    final h = _Harness();
    await h.signIn();
    h.members.updateError = dioFailure('/v7/members/me');

    expect(await h.viewModel.save('새닉네임'), isFalse);

    expect(h.viewModel.message, networkRetryMessage);
    expect(h.viewModel.nicknameError, isNull);
    expect(h.authViewModel.status, AuthStatus.signedIn);
    expect(h.storage.token, isNotNull);

    h.members.updateError = null; // 같은 입력으로 바로 다시 저장할 수 있습니다.
    expect(await h.viewModel.save('새닉네임'), isTrue);
  });

  test('AUTH401_4 expires the session so the router can show the login screen', () async {
    final h = _Harness();
    await h.signIn();
    h.members.updateError = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다.');

    expect(await h.viewModel.save('새닉네임'), isFalse);

    expect(h.authViewModel.status, AuthStatus.signedOut);
    expect(h.authViewModel.sessionExpired, isTrue);
    expect(h.storage.token, isNull);
  });

  test('MEMBER404_1 is reported without signing out', () async {
    final h = _Harness();
    await h.signIn();
    h.members.updateError = commonFailure(404, 'MEMBER404_1', '해당 회원을 찾을 수 없습니다.');

    await h.viewModel.save('새닉네임');

    expect(h.viewModel.message, '회원 정보를 찾을 수 없어요.');
    expect(h.authViewModel.status, AuthStatus.signedIn);
  });

  test('ignores a second save while one is running', () async {
    final h = _Harness();
    await h.signIn();
    h.members.delay = const Duration(milliseconds: 20);

    final first = h.viewModel.save('새닉네임');
    expect(await h.viewModel.save('또다른'), isFalse);
    await first;

    expect(h.members.nicknames, ['새닉네임']);
  });

  test('a response that arrives after logout is not applied', () async {
    final h = _Harness();
    await h.signIn();
    h.members.delay = const Duration(milliseconds: 20);

    final saving = h.viewModel.save('새닉네임');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await h.authViewModel.logout();

    expect(await saving, isFalse);
    expect(h.authViewModel.member, isNull);
  });

  test('hasChanges compares the trimmed input with the current nickname', () async {
    final h = _Harness();
    await h.signIn();

    expect(h.viewModel.hasChanges('무비러버'), isFalse);
    expect(h.viewModel.hasChanges('  무비러버 '), isFalse);
    expect(h.viewModel.hasChanges('무비러버2'), isTrue);
  });

  test('editing the field clears the previous server error but not the input', () async {
    final h = _Harness();
    await h.signIn();
    h.members.updateError = commonFailure(409, 'MEMBER409_1', '중복');
    await h.viewModel.save('taken');
    expect(h.viewModel.nicknameError, isNotNull);

    h.viewModel.onNicknameChanged();

    expect(h.viewModel.nicknameError, isNull);
  });

  test('joinedLabel formats createdAt as "2026.10.10 가입"', () {
    expect(memberInfo(createdAt: DateTime(2026, 10, 10, 12)).joinedLabel, '2026.10.10 가입');
    expect(memberInfo(createdAt: DateTime(2026, 3, 5, 12)).joinedLabel, '2026.03.05 가입');
  });
}
