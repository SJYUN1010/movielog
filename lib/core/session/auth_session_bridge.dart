import 'package:flutter/foundation.dart';

import 'session_guard.dart';

/// AuthViewModel의 상태 변화를 [SessionGuard]에 전달합니다. AuthViewModel을 대체하지 않습니다.
///
/// 인증 상태의 기준은 8주차 AuthViewModel이 그대로 가지고, 이 클래스는 연결만 맡습니다.
class AuthSessionBridge {
  AuthSessionBridge({
    required this.authSignals,
    required this.sessionVersion,
    required this.verifiedEmail,
  }) {
    authSignals.addListener(_sync);
    _sync();
  }

  final Listenable authSignals;

  /// AuthViewModel.sessionVersion입니다. 로그인·복원·로그아웃마다 바뀝니다.
  final int Function() sessionVersion;

  /// signedIn이고 내 정보 조회가 끝나 member가 생기기 전까지는 null을 반환합니다.
  final String? Function() verifiedEmail;

  final guard = SessionGuard();
  int? _seenVersion;
  String? _seenEmail;
  bool _disposed = false;

  void _sync() {
    if (_disposed) return;
    final version = sessionVersion();
    final email = verifiedEmail();
    // 닉네임 수정처럼 version·email이 그대로인 변경으로는 세션을 다시 시작하지 않습니다.
    if (version == _seenVersion && email == _seenEmail) return;
    _seenVersion = version;
    _seenEmail = email;
    guard.invalidate();
    if (email != null) guard.startSession(email);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    authSignals.removeListener(_sync);
    guard.invalidate();
  }
}
