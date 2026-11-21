/// "지금 도착한 응답이 현재 로그인 세션의 것인지"를 판정합니다.
///
/// 계정이 바뀌거나 로그아웃·재로그인이 일어나면 [generation]이 바뀌어서, 이전 세션에서 보낸 요청의
/// 늦은 응답이 현재 화면에 반영되지 않게 합니다. memberId를 쓰지 않고 `/members/me`로 확인한 email을
/// 현재 계정으로 사용합니다.
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  /// 인증 호스트(AuthSessionBridge)가 검증된 새 세션을 시작할 때만 호출합니다.
  /// 화면이나 ViewModel에서 호출하지 않고, build마다 호출하지도 않습니다.
  /// 같은 계정이라도 토큰이 새로 발급되면 새 세션입니다.
  int startSession(String accountId) {
    _accountId = accountId;
    return ++_generation;
  }

  /// 로그아웃·만료·계정 전환으로 현재 세션을 더 쓸 수 없을 때 호출합니다.
  void invalidate() {
    _accountId = null;
    _generation++;
  }

  bool isCurrent(int generation, String accountId) =>
      _generation == generation && _accountId == accountId;
}
