import 'package:dio/dio.dart';

import '../core/network/api_error.dart';
import '../data/services/rating_api_service.dart';

/// 평점 등록·수정·삭제 실패를 화면이 어떻게 보여줄지 나눈 종류입니다.
enum RatingWriteKind {
  /// 입력칸 근처에 서버 message를 보여주고 Dialog를 열어 둡니다(400, 네트워크 실패).
  inline,

  /// Dialog를 닫고 Snackbar로 안내합니다. 로그아웃하지 않습니다(403, 404, 409).
  notice,

  /// Dialog만 조용히 닫습니다. 세션이 만료됐거나(401) 이전 세션의 늦은 응답이라 화면은 Router가 맡습니다.
  dismissed,
}

class RatingWriteException implements Exception {
  const RatingWriteException(this.message, this.kind, {this.code});

  final String message;
  final RatingWriteKind kind;

  /// 서버 오류 code입니다(예: RATING409_1). 네트워크 실패면 null입니다.
  final String? code;

  @override
  String toString() => 'RatingWriteException($kind, $code)';
}

/// 서버 오류 code를 화면 처리 종류로 바꿉니다.
/// 401(AUTH401_2/3/4)은 세션 정리를 호출부(ViewModel)가 맡으므로 여기서는 [RatingWriteKind.dismissed]로만 표시합니다.
RatingWriteException classifyRatingWriteError(DioException error) {
  final code = apiErrorCode(error);
  final message = writeErrorMessage(error);

  if (isSessionExpiredCode(code)) {
    return RatingWriteException(message, RatingWriteKind.dismissed, code: code);
  }
  return switch (code) {
    // 같은 영화에 이미 평점이 있음 / 남의 평점 / 없는 평점·회원은 안내만 하고 로그인 상태를 유지합니다.
    'RATING409_1' || 'RATING403_1' || 'RATING404_1' || 'MEMBER404_1' =>
      RatingWriteException(message, RatingWriteKind.notice, code: code),
    // COMMON400(별점 범위·후기 길이)과 네트워크 실패는 서버 message 또는 기본 문구를 입력 화면에 보여줍니다.
    _ => RatingWriteException(message, RatingWriteKind.inline, code: code),
  };
}
