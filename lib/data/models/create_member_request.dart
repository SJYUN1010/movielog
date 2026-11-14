/// `POST /v6/members` 요청 body입니다.
class CreateMemberRequest {
  const CreateMemberRequest({
    required this.email,
    required this.password,
    required this.nickname,
  });

  final String email;
  final String password;
  final String nickname;

  /// Dart 객체를 요청 body로 바꾸는 방향입니다.
  /// 비밀번호는 입력한 문자가 의미 있으므로 trim()으로 값을 바꾸지 않습니다.
  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
    'nickname': nickname.trim(),
  };
}
