import '../dto/tmdb_movie_dto.dart';
import 'rating_dto.dart';

/// 평점 기록과 그 영화의 TMDB 정보를 한 쌍으로 묶습니다.
class RatingWithMovie {
  const RatingWithMovie({required this.rating, this.movie});

  final RatingDto rating;

  /// TMDB에서 찾지 못했으면 null입니다. 평점 기록은 자체 백엔드가 주인이라 그대로 남깁니다.
  final TmdbMovieDto? movie;
}
