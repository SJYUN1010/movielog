import 'package:dio/dio.dart';

import '../dto/tmdb_genre_dto.dart';
import '../dto/tmdb_movie_dto.dart';
import '../dto/tmdb_movie_page_dto.dart';

class TmdbMovieService {
  TmdbMovieService(this._dio);

  final Dio _dio;

  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movie/popular',
      queryParameters: {'page': page},
    );
    return TmdbMoviePageDto.fromJson(response.data!);
  }

  Future<TmdbMoviePageDto> discoverMovies({
    int page = 1,
    int? genreId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/discover/movie',
      queryParameters: {
        'page': page,
        'sort_by': 'popularity.desc',
        'with_genres': ?genreId,
      },
    );
    return TmdbMoviePageDto.fromJson(response.data!);
  }

  Future<List<TmdbGenreDto>> fetchGenres() async {
    final response = await _dio.get<Map<String, dynamic>>('/genre/movie/list');
    return [
      for (final item in (response.data!['genres'] as List<dynamic>?) ?? const [])
        TmdbGenreDto.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// 영화 한 편을 조회합니다. 없는 id는 404 DioException을 던집니다.
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    final response = await _dio.get<Map<String, dynamic>>('/movie/$movieId');
    return TmdbMovieDto.fromJson(response.data!);
  }

  /// 404만 null로 바꿉니다. 그 밖의 네트워크 오류는 그대로 다시 던집니다.
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    try {
      return await fetchMovieDetail(movieId);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
