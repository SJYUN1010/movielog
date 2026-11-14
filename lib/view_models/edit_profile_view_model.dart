import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../data/services/member_api_service.dart';
import 'auth_view_model.dart';

enum EditProfileStatus { idle, saving, success, failure }

const nicknameLengthMessage = '닉네임은 2~12자로 입력해 주세요.';
const nicknameTakenMessage = '이미 사용 중인 닉네임이에요.';
const networkRetryMessage = '네트워크 상태를 확인하고 다시 시도해 주세요.';

/// 프로필 수정 화면의 닉네임 저장을 맡습니다.
///
/// 오류는 보여줄 곳에 따라 나눕니다. 특정 입력칸의 문제(길이·중복)는 [nicknameError]로 필드 아래에,
/// 입력과 무관한 문제(네트워크·서버)는 [message]로 Snackbar에 보여줍니다.
/// 네트워크 실패로는 로그아웃하지 않고, 401(AUTH401_2/3/4)일 때만 세션을 정리합니다.
class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel(this._memberApi, this._auth);

  final MemberApiService _memberApi;
  final AuthViewModel _auth;

  EditProfileStatus status = EditProfileStatus.idle;
  String? nicknameError;
  String? message;
  bool _disposed = false;

  bool get isSaving => status == EditProfileStatus.saving;

  /// 서버에 보내기 전에 확인할 수 있는 규칙은 클라이언트에서 먼저 검사합니다.
  String? validateNickname(String value) {
    final nickname = value.trim();
    if (nickname.length < 2 || nickname.length > 12) return nicknameLengthMessage;
    return null;
  }

  /// 저장하지 않은 변경이 있는지 알려줍니다(뒤로가기 확인 Dialog에 씁니다).
  bool hasChanges(String input) => input.trim() != (_auth.member?.nickname ?? '');

  /// 입력을 고치기 시작하면 이전 서버 오류를 지웁니다. 입력값은 그대로 유지됩니다.
  void onNicknameChanged() {
    if (nicknameError == null) return;
    nicknameError = null;
    _notify();
  }

  Future<bool> save(String input) async {
    if (isSaving) return false; // 중복 탭 방지
    final version = _auth.sessionVersion;
    if (_disposed || _auth.status != AuthStatus.signedIn || _auth.member == null) return false;

    final nickname = input.trim();
    nicknameError = validateNickname(nickname);
    message = null;
    if (nicknameError != null) {
      _notify();
      return false;
    }

    // 현재 닉네임과 같으면 요청 없이 완료로 처리합니다. 같은 값은 409가 아니지만 호출할 이유가 없습니다.
    if (nickname == _auth.member?.nickname) {
      status = EditProfileStatus.success;
      _notify();
      return true;
    }

    status = EditProfileStatus.saving;
    _notify();

    try {
      final updated = await _memberApi.updateNickname(nickname);
      if (_isStale(version)) return false;
      _auth.updateMember(updated); // 마이페이지가 바로 새 닉네임을 보여줍니다.
      status = EditProfileStatus.success;
      _notify();
      return true;
    } on DioException catch (error) {
      if (_isStale(version)) return false;
      status = EditProfileStatus.failure;
      final code = apiErrorCode(error);
      if (isSessionExpiredCode(code)) {
        // 안내와 이동은 로그인 화면과 Router가 처리합니다.
        await _auth.expireSession(fromVersion: version);
      } else if (code == 'MEMBER409_1') {
        nicknameError = nicknameTakenMessage; // 입력값은 유지합니다.
      } else if (code == 'COMMON400') {
        nicknameError = apiErrorMessage(error) ?? '닉네임 형식을 확인해 주세요.';
      } else if (code == 'MEMBER404_1') {
        message = '회원 정보를 찾을 수 없어요.';
      } else {
        message = networkRetryMessage; // 로그아웃하지 않습니다.
      }
    } catch (_) {
      if (_isStale(version)) return false;
      status = EditProfileStatus.failure;
      message = '알 수 없는 오류가 발생했어요.';
    }
    _notify();
    return false;
  }

  bool _isStale(int version) => _disposed || version != _auth.sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
