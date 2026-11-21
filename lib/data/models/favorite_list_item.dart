import '../dto/tmdb_movie_dto.dart';
import 'favorite_response_dto.dart';

/// 내 즐겨찾기 목록의 카드 한 장입니다. 즐겨찾기(MovieLog)와 영화 정보(TMDB)를 movieId로 합칩니다.
/// 영화 정보를 가져오지 못한 카드는 [movie]가 null이고 [errorMessage]가 채워집니다.
class FavoriteListItem {
  const FavoriteListItem({required this.favorite, this.movie, this.errorMessage});

  final FavoriteResponseDto favorite;
  final TmdbMovieDto? movie;
  final String? errorMessage;

  bool get hasMovie => movie != null;
}
