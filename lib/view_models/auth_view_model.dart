import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/storage/token_storage.dart';
import '../data/models/login_models.dart';
import '../data/models/member_info.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';

/// 앱의 인증 상태입니다.
/// - initializing: 앱 시작 직후 저장소를 확인하는 중(보호 화면이나 로그인 화면을 보여주지 않습니다)
/// - signedOut: 로그인하지 않음(직접 로그아웃, 만료, 토큰 없음)
/// - authenticating: 로그인 요청 중
/// - signedIn: 서버가 확인한 로그인 상태
/// - retryRequired: 세션을 확인하지 못함(네트워크·저장소 오류). 토큰은 지우지 않고 재시도를 안내합니다.
enum AuthStatus { initializing, signedOut, authenticating, signedIn, retryRequired }

enum MemberLoadStatus { idle, loading, success, error }

const loginFailedMessage = '이메일 또는 비밀번호를 확인해 주세요.';
const loginRequestFailedMessage = '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
const tokenSaveFailedMessage = '로그인 정보를 안전하게 저장하지 못했어요.';
const sessionCheckFailedMessage = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
const storageReadFailedMessage = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
const memberLoadFailedMessage = '내 정보를 불러오지 못했어요.';
const storageClearFailedMessage = '저장된 인증 정보를 지우지 못했어요. 앱 재실행 전에 저장소 상태를 확인해 주세요.';

/// 로그인·세션 복원·로그아웃·만료와 내 정보(member)를 관리합니다.
///
/// 상태만 바꾸고 화면 이동은 하지 않습니다. GoRouter가 이 객체를 refreshListenable로 구독해
/// 상태에 맞는 화면으로 보냅니다. 비밀번호와 토큰 원문은 로그·메시지·화면에 남기지 않습니다.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;

  /// 로그인 실패·세션 확인 실패처럼 화면에 보여줄 안내 문구입니다.
  String? message;

  /// 세션이 만료돼 로그아웃된 경우에만 true입니다. 직접 로그아웃과 로그인 실패(AUTH401_1)에서는 켜지 않습니다.
  bool sessionExpired = false;

  /// 로그아웃·만료 정리 중에는 새 로그인을 막습니다.
  bool storageCleanupInProgress = false;

  int _sessionVersion = 0;
  bool _disposed = false;
  Future<void>? _tokenWrite;

  /// 로그인·복원·정리가 시작될 때마다 늘어납니다. 이전 세션에서 늦게 도착한 응답을 걸러내는 데 씁니다.
  int get sessionVersion => _sessionVersion;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 앱 시작 시 저장된 토큰을 읽고 `GET /v7/members/me`로 서버 검증을 마친 뒤에만 signedIn이 됩니다.
  /// 토큰 문자열이 존재한다는 이유만으로 로그인 상태를 확정하지 않습니다.
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();

    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verified = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verified;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크가 잠시 끊겼다고 유효한 토큰을 삭제하지 않습니다.
      status = AuthStatus.retryRequired;
      message = sessionCheckFailedMessage;
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.retryRequired;
      message = storageReadFailedMessage;
    }
    if (_isCurrent(version)) _notify();
  }

  Future<void> login(String email, String password) async {
    if (_disposed || storageCleanupInProgress || status == AuthStatus.authenticating) return;
    final version = ++_sessionVersion;
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    _notify();

    try {
      final result = await _authApi.login(LoginRequest(email: email, password: password));
      if (!_isCurrent(version)) return;
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;
      // 신규 로그인: 토큰 저장 → signedIn → MainScreen.loadMember()가 내 정보를 불러옵니다.
      status = AuthStatus.signedIn;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      // AUTH401_1은 로그인 Form 오류입니다. 세션 만료 처리를 하지 않습니다.
      message = apiErrorCode(error) == 'AUTH401_1'
          ? loginFailedMessage
          : loginRequestFailedMessage;
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = tokenSaveFailedMessage;
    }
    _notify();
  }

  /// 홈·영화·마이 탭을 감싸는 MainScreen이 처음 열릴 때 호출합니다. 이미 들고 있으면 다시 부르지 않습니다.
  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답은 무시합니다.
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      memberStatus = MemberLoadStatus.error; // 네트워크 실패: 로그아웃하지 않고 재시도할 수 있습니다.
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
    }
    _notify();
  }

  /// 프로필 수정 성공 응답으로 메모리의 내 정보를 교체합니다. GET me를 다시 호출하지 않습니다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    memberStatus = MemberLoadStatus.success;
    _notify();
  }

  /// 다른 ViewModel이 AUTH401_2/3/4를 받았을 때 세션 정리를 요청하는 공개 진입점입니다.
  /// 이미 정리됐거나 이전 세션에서 늦게 도착한 401이면 [fromVersion]이 달라 무시합니다.
  Future<void> expireSession({int? fromVersion}) async {
    if (fromVersion != null && fromVersion != _sessionVersion) return;
    if (status == AuthStatus.signedOut || storageCleanupInProgress) return; // 알림·이동은 한 번만
    await _clearCurrentSession(expired: true);
  }

  /// 직접 로그아웃입니다. 만료 안내 Snackbar는 켜지 않습니다.
  /// 이 앱의 저장소·메모리만 비우며, 서버에서 토큰이 즉시 폐기됐다고 보장하지는 않습니다.
  Future<void> logout() => _clearCurrentSession(expired: false);

  void consumeSessionExpired() {
    sessionExpired = false;
  }

  /// 로그인 입력을 고치기 시작하면 이전 로그인 실패 문구를 지웁니다.
  void clearMessage() {
    if (message == null || status != AuthStatus.signedOut) return;
    message = null;
    _notify();
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();
    try {
      // 진행 중이던 토큰 저장이 있으면 끝날 때까지 기다린 뒤 삭제합니다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장이 실패했어도 삭제는 시도합니다.
      }
      await _storage.deleteAccessToken();
    } catch (_) {
      if (_isCurrent(version)) message = storageClearFailedMessage;
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
