import 'common_response.dart';
import 'favorite_response_dto.dart';
import 'rating_dto.dart';

/// `POST /v8/movie-records` 요청입니다. 평점 등록과 즐겨찾기 등록을 한 트랜잭션으로 묶습니다.
class MovieRecordRequest {
  const MovieRecordRequest({
    required this.movieId,
    required this.score,
    required this.addToFavorites,
    this.comment,
  });

  final int movieId;

  /// 1~5의 정수입니다.
  final int score;

  /// 필수 boolean입니다. false면 응답의 favorite이 null인 것이 정상입니다.
  final bool addToFavorites;

  /// 선택입니다. 평점 API와 달리 서버에 길이 제한이 없지만 Dialog는 500자로 제한합니다.
  final String? comment;

  Map<String, dynamic> toJson() {
    final text = comment?.trim();
    return {
      'movieId': movieId,
      'score': score,
      if (text != null && text.isNotEmpty) 'comment': text,
      'addToFavorites': addToFavorites,
    };
  }
}

/// `POST /v8/movie-records` 성공 result입니다.
class MovieRecordResult {
  const MovieRecordResult({required this.rating, required this.favorite});

  factory MovieRecordResult.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('MovieRecordResult must be a JSON object.');
    }
    final favorite = json['favorite'];
    return MovieRecordResult(
      rating: RatingDto.fromJson(json['rating'] as Map<String, dynamic>),
      favorite: favorite == null ? null : FavoriteResponseDto.fromJson(favorite),
    );
  }

  final RatingDto rating;

  /// addToFavorites가 false였으면 null입니다.
  final FavoriteResponseDto? favorite;
}

MovieRecordResult parseMovieRecordResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('영화 기록 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<MovieRecordResult>.fromJson(data, MovieRecordResult.fromJson);
  final result = common.result;
  if (result == null) throw StateError('영화 기록 result가 없습니다.');
  return result;
}
