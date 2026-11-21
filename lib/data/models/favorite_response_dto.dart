/// 즐겨찾기 응답(`FavoriteResponseDto`)입니다. 제목·포스터는 없고 TMDB 영화 id만 있습니다.
/// 화면에 보여줄 영화 정보는 [movieId]로 TMDB에서 가져와 합칩니다.
class FavoriteResponseDto {
  const FavoriteResponseDto({
    required this.favoriteId,
    required this.movieId,
    required this.createdAt,
  });

  factory FavoriteResponseDto.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('FavoriteResponseDto must be a JSON object.');
    }
    return FavoriteResponseDto(
      favoriteId: (json['favoriteId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int favoriteId;

  /// TMDB 영화 id입니다. 해제·여부 조회 경로에도 favoriteId가 아니라 이 값을 씁니다.
  final int movieId;
  final DateTime createdAt;
}
