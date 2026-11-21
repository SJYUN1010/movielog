import 'package:dio/dio.dart';

import '../models/common_response.dart';
import '../models/favorite_check_dto.dart';
import '../models/favorite_response_dto.dart';
import '../models/movie_record_models.dart';

/// MovieLog 즐겨찾기 API(`/v8/favorites`)와 영화 기록 저장(`/v8/movie-records`)을 호출합니다.
/// 보호용 MovieLog Dio(JWT Interceptor 포함)를 주입받습니다. memberId는 어디에도 보내지 않습니다.
class FavoriteApiService {
  FavoriteApiService(this._dio);

  final Dio _dio;

  /// 즐겨찾기 등록: 201, result에 FavoriteResponseDto가 담깁니다.
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final response = await _dio.post<dynamic>('/v8/favorites', data: {'movieId': movieId});
    final body = CommonResponse<FavoriteResponseDto>.fromJson(
      response.data as Map<String, dynamic>,
      FavoriteResponseDto.fromJson,
    );
    final result = body.result;
    if (result == null) throw StateError('즐겨찾기 result가 없습니다.');
    return result;
  }

  /// 내 즐겨찾기 조회: 200, result가 배열입니다. 없으면 빈 배열입니다. page 파라미터는 없습니다.
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final response = await _dio.get<dynamic>('/v8/favorites');
    final body = CommonResponse<List<FavoriteResponseDto>>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => [for (final item in value as List<dynamic>) FavoriteResponseDto.fromJson(item)],
    );
    return body.result ?? const [];
  }

  /// 특정 영화의 즐겨찾기 여부 조회: 응답에 movieId가 없어서 요청한 값을 함께 넘깁니다.
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final response = await _dio.get<dynamic>('/v8/favorites/$movieId');
    final body = CommonResponse<FavoriteCheckDto>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => FavoriteCheckDto.fromJson(value, movieId: movieId),
    );
    final result = body.result;
    if (result == null) throw StateError('즐겨찾기 여부 result가 없습니다.');
    return result;
  }

  /// 즐겨찾기 해제: 200이고 result는 null입니다. 평점 삭제의 204와 다릅니다.
  /// 응답 body를 DTO로 파싱하지 않고, DioException이 없으면 성공으로 처리합니다.
  Future<void> deleteFavorite({required int movieId}) async {
    await _dio.delete<dynamic>('/v8/favorites/$movieId');
  }

  /// 평점 등록 + 즐겨찾기 등록을 한 트랜잭션으로 저장합니다(Challenge).
  /// 둘 중 하나라도 실패하면 모두 저장되지 않습니다.
  Future<MovieRecordResult> saveMovieRecord(MovieRecordRequest request) async {
    final response = await _dio.post<dynamic>('/v8/movie-records', data: request.toJson());
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 영화 기록 응답: ${response.statusCode}');
    }
    return parseMovieRecordResult(response.data);
  }
}
