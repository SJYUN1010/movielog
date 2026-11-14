import 'package:dio/dio.dart';

import '../models/login_models.dart';

/// 로그인을 담당합니다. 토큰이 아직 없는 요청이라 공개용 Client를 씁니다.
class AuthApiService {
  AuthApiService(this._publicDio);

  final Dio _publicDio;

  /// 401 AUTH401_1(이메일·비밀번호 불일치)은 로그인 Form 오류이고 세션 만료가 아닙니다.
  Future<LoginResult> login(LoginRequest request) async {
    final response = await _publicDio.post<dynamic>(
      '/v7/auth/login',
      data: request.toJson(),
    );
    return parseLoginResult(response.data);
  }
}
