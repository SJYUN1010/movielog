import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';

import 'support/fakes.dart';

void main() {
  group('MovieHomeViewModel', () {
    test('keeps only the first 5 popular movies', () async {
      final service = FakeTmdbMovieService(
        popular: [for (var i = 1; i <= 20; i++) movieDto(i)],
      );
      final viewModel = MovieHomeViewModel(service);

      await viewModel.load();

      expect(viewModel.status, MovieHomeLoadStatus.success);
      expect(viewModel.popularMovies.map((m) => m.id), [1, 2, 3, 4, 5]);
    });

    test('handles fewer than 5 results without a range error', () async {
      final service = FakeTmdbMovieService(popular: [movieDto(1), movieDto(2)]);
      final viewModel = MovieHomeViewModel(service);

      await viewModel.load();

      expect(viewModel.popularMovies, hasLength(2));
    });

    test('empty result is Empty, failure is Error and retry recovers', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieHomeViewModel(service);

      await viewModel.load();
      expect(viewModel.status, MovieHomeLoadStatus.empty);

      service
        ..failPopular = true
        ..popular = [movieDto(1)];
      await viewModel.load();
      expect(viewModel.status, MovieHomeLoadStatus.error);

      service.failPopular = false;
      await viewModel.load();
      expect(viewModel.status, MovieHomeLoadStatus.success);
      expect(service.popularCalls, 3);
    });

    test('goes through Loading before the result', () async {
      final service = FakeTmdbMovieService(
        popular: [movieDto(1)],
        delay: const Duration(milliseconds: 10),
      );
      final viewModel = MovieHomeViewModel(service);
      final statuses = <MovieHomeLoadStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.status));

      await viewModel.load();

      expect(statuses, [MovieHomeLoadStatus.loading, MovieHomeLoadStatus.success]);
    });
  });

  group('MovieListViewModel', () {
    test('builds at most 30 movies from pages, de-duplicating by id', () async {
      final service = FakeTmdbMovieService()..overlap = 10;
      final viewModel = MovieListViewModel(service);

      await viewModel.load();

      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.movies.length, 30);
      expect(viewModel.movies.map((m) => m.id).toSet().length, 30);
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
    });

    test('stops when there are no more pages and shows what exists', () async {
      final service = FakeTmdbMovieService(pageSize: 8, totalPages: 2);
      final viewModel = MovieListViewModel(service);

      await viewModel.load();

      expect(viewModel.movies.length, 16);
      expect(service.discoverCalls.length, 2);
    });

    test('selecting a genre re-requests from page 1 with with_genres', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();
      service.discoverCalls.clear();

      await viewModel.selectGenre(878);

      expect(viewModel.selectedGenreId, 878);
      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.first.genreId, 878);
      expect(viewModel.movies, isNotEmpty);
    });

    test('selecting 전체 (null) sends no genre', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();
      await viewModel.selectGenre(878);
      service.discoverCalls.clear();

      await viewModel.selectGenre(null);

      expect(viewModel.selectedGenreId, isNull);
      expect(service.discoverCalls.every((c) => c.genreId == null), isTrue);
    });

    test('ignores genre changes while a request is in flight', () async {
      final service = FakeTmdbMovieService(delay: const Duration(milliseconds: 20));
      final viewModel = MovieListViewModel(service);

      final loading = viewModel.load();
      await viewModel.selectGenre(878);
      await loading;

      expect(viewModel.selectedGenreId, isNull);
      expect(service.discoverCalls.every((c) => c.genreId == null), isTrue);
    });

    test('empty and error statuses; retry keeps the selected genre', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();

      service.emptyDiscover = true;
      await viewModel.selectGenre(18);
      expect(viewModel.status, MovieListLoadStatus.empty);

      service
        ..emptyDiscover = false
        ..failDiscover = true;
      await viewModel.load();
      expect(viewModel.status, MovieListLoadStatus.error);

      service
        ..failDiscover = false
        ..discoverCalls.clear();
      await viewModel.retry();
      expect(viewModel.status, MovieListLoadStatus.success);
      expect(service.discoverCalls.first.genreId, 18);
      expect(service.discoverCalls.first.page, 1);
    });

    test('genre API failure becomes Error and loads genres again on retry', () async {
      final service = FakeTmdbMovieService()..failGenres = true;
      final viewModel = MovieListViewModel(service);

      await viewModel.load();
      expect(viewModel.status, MovieListLoadStatus.error);

      service.failGenres = false;
      await viewModel.retry();
      expect(viewModel.status, MovieListLoadStatus.success);
      expect(viewModel.genres, sampleGenres);
    });

    test('restores a saved genre id and falls back when it no longer exists', () async {
      final saved = MemoryGenrePreference(878);
      final restored = MovieListViewModel(
        FakeTmdbMovieService(),
        genrePreference: saved,
      );
      await restored.load();
      expect(restored.selectedGenreId, 878);

      final fallback = MovieListViewModel(
        FakeTmdbMovieService(),
        genrePreference: MemoryGenrePreference(99999),
      );
      await fallback.load();
      expect(fallback.selectedGenreId, isNull);
    });

    test('saves the selected genre id', () async {
      final preference = MemoryGenrePreference();
      final viewModel = MovieListViewModel(
        FakeTmdbMovieService(),
        genrePreference: preference,
      );
      await viewModel.load();

      await viewModel.selectGenre(18);

      expect(preference.value, 18);
    });
  });
}
