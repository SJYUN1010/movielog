import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';
import '../models/common_response.dart';
import '../models/rating_dto.dart';
import '../models/rating_request.dart';

/// 평점 응답(등록·수정의 result)을 [RatingDto]로 바꿉니다. result가 없거나 형식이 다르면 StateError입니다.
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

/// 유저별 평점 조회는 공통 응답으로 감싸지 않은 직접 배열입니다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return [for (final value in data) RatingDto.fromJson(value as Map<String, dynamic>)];
}

/// v7 평점 API입니다.
///
/// - 유저별 평점 조회는 공개 API라 토큰 없는 공개용 Client로 보냅니다(memberId는 path에 유지).
/// - 등록·수정·삭제는 보호 API라 [AuthInterceptor]가 달린 보호용 Client로 보냅니다.
///   memberId는 URL·query·body 어디에도 보내지 않습니다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  /// 공개 조회입니다. 성공은 직접 배열이고, 없는 회원이면 MEMBER404_1입니다.
  /// 로그인·내 정보 응답에는 memberId가 없어서 현재 화면에서는 쓰지 않습니다.
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get<dynamic>('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  /// 201 + result: Rating 객체입니다. v6의 "ratingId 숫자 하나"와 다릅니다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post<dynamic>('/v7/ratings', data: request.toJson());
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
    return parseRatingResult(response.data);
  }

  /// PATCH지만 score가 필수이고 comment를 생략하면 기존 후기가 null로 덮입니다(전체 교체).
  /// 그래서 comment는 항상 보냅니다. 비우면 null로 지우겠다는 뜻입니다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final response = await _authDio.patch<dynamic>(
      '/v7/ratings/$ratingId',
      data: {'score': score, 'comment': comment},
    );
    return parseRatingResult(response.data);
  }

  /// v6의 204(본문 없음)와 달리 200 + `result: null`입니다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete<dynamic>('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

/// 서버 message를 그대로 보여줍니다. code별로 문구를 새로 만들지 않습니다.
String writeErrorMessage(
  DioException error, {
  String fallback = '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
}) {
  return apiErrorMessage(error) ?? fallback;
}
