import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/tmdb_client.dart';
import 'package:movielog/data/dto/tmdb_genre_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_page_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.body);

  final Map<String, dynamic> body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TmdbMovieService _serviceWith(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: TmdbClient.baseUrl))
    ..httpClientAdapter = adapter;
  return TmdbMovieService(dio);
}

void main() {
  group('DTO', () {
    test('converts snake_case JSON and keeps poster_path null', () {
      final movie = TmdbMovieDto.fromJson({
        'id': 7,
        'title': '별빛 아래 우리',
        'overview': '줄거리',
        'poster_path': null,
        'genre_ids': [18, 878],
        'release_date': '2024-12-25',
        'vote_average': 8,
        'vote_count': 12,
      });

      expect(movie.id, 7);
      expect(movie.posterPath, isNull);
      expect(movie.genreIds, [18, 878]);
      expect(movie.releaseYear, 2024);
      expect(movie.voteAverage, 8.0);
      expect(movie.fiveStarRating, 4.0);
    });

    test('survives missing optional fields', () {
      final movie = TmdbMovieDto.fromJson({'id': 1});

      expect(movie.title, isEmpty);
      expect(movie.genreIds, isEmpty);
      expect(movie.releaseYear, isNull);
      expect(movie.voteAverage, 0);
    });

    test('page and genre DTOs parse their lists', () {
      final page = TmdbMoviePageDto.fromJson({
        'page': 2,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
        'total_pages': 9,
        'total_results': 180,
      });
      final genre = TmdbGenreDto.fromJson({'id': 18, 'name': '드라마'});

      expect(page.page, 2);
      expect(page.results.map((m) => m.id), [1, 2]);
      expect(page.totalPages, 9);
      expect(genre.name, '드라마');
    });
  });

  group('TmdbMovieService', () {
    test('discover sends with_genres only when a genre is selected', () async {
      final adapter = _RecordingAdapter({'page': 1, 'results': [], 'total_pages': 1});
      final service = _serviceWith(adapter);

      await service.discoverMovies(page: 1, genreId: 878);
      await service.discoverMovies(page: 2);

      expect(adapter.requests[0].path, '/discover/movie');
      expect(adapter.requests[0].queryParameters['with_genres'], 878);
      expect(adapter.requests[0].queryParameters['page'], 1);
      expect(adapter.requests[1].queryParameters.containsKey('with_genres'), isFalse);
      expect(adapter.requests[1].queryParameters['page'], 2);
    });

    test('popular and genre endpoints use the expected paths', () async {
      final adapter = _RecordingAdapter({
        'page': 1,
        'results': [],
        'genres': [
          {'id': 18, 'name': '드라마'},
        ],
      });
      final service = _serviceWith(adapter);

      await service.fetchPopular();
      final genres = await service.fetchGenres();

      expect(adapter.requests[0].path, '/movie/popular');
      expect(adapter.requests[1].path, '/genre/movie/list');
      expect(genres.single.name, '드라마');
    });
  });
}
