/// v6 공통 응답 형식입니다. `{ isSuccess, code, message, result }`
///
/// 성공 응답(회원가입·평점 등록·수정)과 모든 API의 실패 응답을 이 형식으로 파싱합니다.
/// 평점 삭제 성공(204)은 본문이 없고, v5부터 있던 닉네임·이메일 확인과 평점 조회의
/// 성공 응답은 직접 객체/배열이라 이 형식으로 감싸지 않습니다.
class CommonResponse<T> {
  const CommonResponse({
    required this.isSuccess,
    required this.code,
    required this.message,
    this.result,
  });

  final bool isSuccess;
  final String code;
  final String message;

  /// API마다 담기는 값이 달라 제네릭으로 둡니다. 값이 없거나 실패 응답이면 null입니다.
  final T? result;

  factory CommonResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? value) parseResult,
  ) {
    final rawResult = json['result'];
    return CommonResponse<T>(
      isSuccess: json['isSuccess'] as bool,
      code: json['code'] as String,
      message: json['message'] as String,
      result: rawResult == null ? null : parseResult(rawResult),
    );
  }
}
