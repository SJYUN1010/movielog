import 'package:dio/dio.dart';

import '../models/check_result.dart';
import '../models/common_response.dart';
import '../models/create_member_request.dart';
import '../models/sign_up_models.dart';

/// 회원가입과 중복 확인을 담당합니다. 6주차의 MemberCheckService를 v6로 확장한 것입니다.
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  /// 성공은 `{ "available": bool }` 직접 객체, 오류는 v6 공통 응답입니다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/v6/members/nickname/$encoded',
    );
    return CheckResult.fromJson(response.data!).available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get<Map<String, dynamic>>(
      '/v6/members/email/$encoded',
    );
    return CheckResult.fromJson(response.data!).available;
  }

  /// 201 성공 시 result에 회원 객체가 담깁니다. 400(비밀번호 형식), 409(중복)는 DioException입니다.
  Future<CommonResponse<SignUpResult>> signUp(CreateMemberRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v6/members',
      data: request.toJson(),
    );

    return CommonResponse<SignUpResult>.fromJson(
      response.data!,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

/// 회원가입 오류 문구입니다. 서버 message에 사용자에게 보여줄 문장이 이미 들어 있습니다.
String writeSignUpErrorMessage(DioException error) {
  final data = error.response?.data;
  CommonResponse<Object?>? common;
  if (data is Map<String, dynamic>) {
    try {
      common = CommonResponse<Object?>.fromJson(data, (value) => value);
    } catch (_) {
      common = null;
    }
  }
  return common?.message ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
