import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 성공은 직접 배열입니다. 결과가 없으면 빈 배열(200), 없는 유저면 공통 응답 404입니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get<List<dynamic>>('/v6/members/$memberId/ratings');
    return [
      for (final item in response.data ?? const <dynamic>[])
        RatingDto.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 201을 성공으로 처리합니다. result는 Swagger 설명(숫자)과 예시(null)가 달라
  /// 계약이 확정되기 전에는 파싱하지 않고, 등록 뒤 GET으로 목록을 다시 확인합니다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  /// PATCH지만 score가 필수이고, comment를 생략하면 기존 후기가 null로 덮입니다.
  /// 그래서 comment는 항상 보냅니다(비우면 null로 지우겠다는 뜻).
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await _dio.patch<dynamic>(
      '/v6/members/$memberId/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
  }

  /// 204는 본문이 없으므로 JSON으로 파싱하지 않습니다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response = await _dio.delete<dynamic>(
      '/v6/members/$memberId/ratings/$ratingId',
    );
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

CommonResponse<Object?>? _parseCommonError(DioException error) {
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  try {
    return CommonResponse<Object?>.fromJson(data, (value) => value);
  } catch (_) {
    return null;
  }
}

/// 서버 message를 그대로 보여줍니다. code별로 문구를 새로 만들면 같은 COMMON404라도
/// 등록에서는 "유저", 수정·삭제에서는 "평점"을 가리키는 차이를 놓칩니다.
String writeErrorMessage(
  DioException error, {
  String fallback = '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
}) {
  return _parseCommonError(error)?.message ?? fallback;
}

/// 403·404는 화면에 남은 목록이 서버 상태와 어긋났다는 뜻이므로 다시 조회해서 맞춥니다.
/// 400(별점 범위)과 409(중복 등록)는 값만 고치거나 다시 시도하면 되어 재조회가 필요 없습니다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = _parseCommonError(error)?.code;
  return code == 'COMMON403' || code == 'COMMON404';
}
