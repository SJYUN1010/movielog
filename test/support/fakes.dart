import 'package:dio/dio.dart';

import 'package:movielog/data/dto/tmdb_genre_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/genre_preference.dart';

TmdbMovieDto movieDto(
  int id, {
  String? title,
  String? posterPath = '/poster.jpg',
  double voteAverage = 8.0,
  List<int> genreIds = const [18],
  String releaseDate = '2024-05-01',
}) {
  return TmdbMovieDto(
    id: id,
    title: title ?? '영화 $id',
    overview: '영화 $id 줄거리',
    posterPath: posterPath,
    genreIds: genreIds,
    releaseDate: releaseDate,
    voteAverage: voteAverage,
    voteCount: 100,
  );
}

const sampleGenres = [
  TmdbGenreDto(id: 18, name: '드라마'),
  TmdbGenreDto(id: 878, name: 'SF'),
];

class DiscoverCall {
  const DiscoverCall(this.page, this.genreId);

  final int page;
  final int? genreId;
}

class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService({
    this.popular = const [],
    this.genres = sampleGenres,
    this.pageSize = 20,
    this.totalPages = 5,
    this.delay = Duration.zero,
  }) : super(Dio());

  List<TmdbMovieDto> popular;
  List<TmdbGenreDto> genres;
  int pageSize;
  int totalPages;
  Duration delay;

  bool failPopular = false;
  bool failDiscover = false;
  bool failGenres = false;
  bool emptyDiscover = false;

  int popularCalls = 0;
  int genreCalls = 0;
  final discoverCalls = <DiscoverCall>[];

  /// 페이지 사이에 id가 겹치도록 하려면 [overlap]만큼 이전 페이지 id를 다시 내려줍니다.
  int overlap = 0;

  Future<void> _wait() => Future<void>.delayed(delay);

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularCalls++;
    await _wait();
    if (failPopular) throw DioException(requestOptions: RequestOptions(path: '/movie/popular'));
    return TmdbMoviePageDto(
      page: page,
      results: popular,
      totalPages: 1,
      totalResults: popular.length,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({int page = 1, int? genreId}) async {
    discoverCalls.add(DiscoverCall(page, genreId));
    await _wait();
    if (failDiscover) throw DioException(requestOptions: RequestOptions(path: '/discover/movie'));
    if (emptyDiscover) {
      return const TmdbMoviePageDto(page: 1, results: [], totalPages: 1, totalResults: 0);
    }
    final start = (page - 1) * (pageSize - overlap);
    return TmdbMoviePageDto(
      page: page,
      results: [for (var i = 0; i < pageSize; i++) movieDto(start + i + 1, genreIds: [genreId ?? 18])],
      totalPages: totalPages,
      totalResults: totalPages * pageSize,
    );
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    genreCalls++;
    await _wait();
    if (failGenres) throw DioException(requestOptions: RequestOptions(path: '/genre/movie/list'));
    return genres;
  }
}

class MemoryGenrePreference implements GenrePreference {
  MemoryGenrePreference([this.value]);

  int? value;

  @override
  Future<int?> read() async => value;

  @override
  Future<void> save(int? genreId) async => value = genreId;
}
