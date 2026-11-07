import 'package:flutter/foundation.dart';

/// 화면 캡처나 개발 중에 가입 없이 학습용 회원을 지정할 때만 씁니다.
/// 기본값 0은 "지정하지 않음"입니다. 예: `--dart-define=LEARNING_MEMBER_ID=12`
const int _debugMemberId = int.fromEnvironment('LEARNING_MEMBER_ID', defaultValue: 0);

/// 회원가입 결과의 memberId를 앱 안에 보관하는 학습용 세션입니다.
///
/// 이 값만 알고 있다는 사실은 인증이 아닙니다. 메모리에만 있어 앱을 재시작하면 사라지고,
/// JWT 주차에는 memberId path를 없애고 서버가 토큰으로 현재 회원을 식별하도록 바꿉니다.
class LearningMemberSession extends ChangeNotifier {
  LearningMemberSession({this.memberId});

  /// [_debugMemberId]가 지정된 경우에만 그 값으로 시작합니다.
  factory LearningMemberSession.fromEnvironment() {
    return LearningMemberSession(memberId: _debugMemberId > 0 ? _debugMemberId : null);
  }

  int? memberId;

  bool get hasMember => memberId != null;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}
