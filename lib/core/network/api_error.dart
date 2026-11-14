import 'package:dio/dio.dart';

/// 서버 공통 오류 응답 `{ isSuccess:false, code, message, result }`에서 code를 꺼냅니다.
/// 응답 body가 없거나(네트워크 실패) 형식이 다르면 null입니다.
String? apiErrorCode(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final code = data['code'];
  return code is String ? code : null;
}

/// 서버가 사용자에게 보여주라고 내려준 message를 꺼냅니다. 없으면 null입니다.
String? apiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final message = data['message'];
  return message is String ? message : null;
}

/// 보호 요청에서 토큰이 없거나(AUTH401_2), 무효이거나(AUTH401_3), 만료된(AUTH401_4) 경우입니다.
/// 로그인 입력 오류(AUTH401_1)와 403(권한 부족), 네트워크 실패는 포함하지 않습니다.
bool isSessionExpiredCode(String? code) {
  return code == 'AUTH401_2' || code == 'AUTH401_3' || code == 'AUTH401_4';
}

bool isSessionExpiredError(DioException error) {
  return isSessionExpiredCode(apiErrorCode(error));
}
