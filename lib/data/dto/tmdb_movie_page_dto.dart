import 'tmdb_movie_dto.dart';

class TmdbMoviePageDto {
  const TmdbMoviePageDto({
    required this.page,
    required this.results,
    required this.totalPages,
    required this.totalResults,
  });

  factory TmdbMoviePageDto.fromJson(Map<String, dynamic> json) {
    return TmdbMoviePageDto(
      page: (json['page'] as num?)?.toInt() ?? 1,
      results: [
        for (final item in (json['results'] as List<dynamic>?) ?? const [])
          TmdbMovieDto.fromJson(item as Map<String, dynamic>),
      ],
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
      totalResults: (json['total_results'] as num?)?.toInt() ?? 0,
    );
  }

  final int page;
  final List<TmdbMovieDto> results;
  final int totalPages;
  final int totalResults;
}
