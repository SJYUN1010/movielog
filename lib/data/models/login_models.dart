import 'common_response.dart';

/// `POST /v7/auth/login` 요청입니다. 비밀번호는 서버로 보내기만 하고 어디에도 저장하지 않습니다.
class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email.trim(), 'password': password};

  /// 로그에 찍혀도 비밀번호가 새지 않도록 막습니다.
  @override
  String toString() => 'LoginRequest(email: $email, password: ****)';
}

/// `POST /v7/auth/login` 성공 result입니다. memberId는 없습니다.
/// JWT payload에 memberId가 있을 것이라고 추정하지 않습니다.
class LoginResult {
  const LoginResult({required this.nickname, required this.accessToken});

  final String nickname;
  final String accessToken;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      nickname: json['nickname'] as String,
      accessToken: json['accessToken'] as String,
    );
  }

  /// accessToken 원문이 로그나 화면에 남지 않도록 막습니다.
  @override
  String toString() => 'LoginResult(nickname: $nickname, accessToken: ****)';
}

/// 로그인 응답 body에서 [LoginResult]를 꺼냅니다. 형식이 다르면 StateError입니다.
LoginResult parseLoginResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('로그인 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<LoginResult>.fromJson(
    data,
    (value) => LoginResult.fromJson(value as Map<String, dynamic>),
  );
  final result = common.result;
  if (result == null) throw StateError('로그인 result가 없습니다.');
  return result;
}
