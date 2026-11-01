class TmdbMovieDto {
  const TmdbMovieDto({
    required this.id,
    required this.title,
    required this.overview,
    required this.genreIds,
    required this.voteAverage,
    required this.voteCount,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
  });

  factory TmdbMovieDto.fromJson(Map<String, dynamic> json) {
    return TmdbMovieDto(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      genreIds: _parseGenreIds(json),
      releaseDate: json['release_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// 목록 응답은 `genre_ids`, 상세 응답은 `genres: [{id, name}]`로 장르를 내려줍니다.
  static List<int> _parseGenreIds(Map<String, dynamic> json) {
    final ids = json['genre_ids'] as List<dynamic>?;
    if (ids != null) return [for (final id in ids) (id as num).toInt()];

    final genres = json['genres'] as List<dynamic>?;
    return [
      for (final genre in genres ?? const <dynamic>[])
        ((genre as Map<String, dynamic>)['id'] as num).toInt(),
    ];
  }

  final int id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final List<int> genreIds;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;

  int? get releaseYear {
    final date = releaseDate;
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  double get fiveStarRating => voteAverage / 2;
}
