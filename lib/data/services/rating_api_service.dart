import 'package:dio/dio.dart';

import '../models/rating_dto.dart';

class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  /// 결과가 없으면 빈 배열(200), memberId 형식이 틀리면 400, 없는 유저면 404입니다.
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get<List<dynamic>>('/v5/members/$memberId/ratings');
    return [
      for (final item in response.data ?? const <dynamic>[])
        RatingDto.fromJson(item as Map<String, dynamic>),
    ];
  }
}

String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
