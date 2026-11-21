import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

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

  group('MovieListViewModel (page based)', () {
    test('shows only the first page; more pages come from loadNextPage, de-duplicated by id', () async {
      final service = FakeTmdbMovieService(pageSize: 20)..overlap = 5;
      final viewModel = MovieListViewModel(service);

      await viewModel.load();

      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.paged.movies, hasLength(20));
      expect(service.discoverCalls.map((c) => c.page), [1]); // 5주차의 30개 수집이 아니라 첫 page만 조회합니다.

      await viewModel.paged.loadNextPage();

      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
      expect(viewModel.paged.movies, hasLength(35)); // 겹친 5편은 제외됩니다.
      expect(viewModel.paged.movies.map((m) => m.id).toSet(), hasLength(35));
    });

    test('selecting a genre re-requests from page 1 with that genre and empties the old list', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();
      await viewModel.paged.loadNextPage();
      service.discoverCalls.clear();

      await viewModel.selectGenre(878);

      expect(viewModel.selectedGenreId, 878);
      expect(service.discoverCalls.single.page, 1);
      expect(service.discoverCalls.single.genreId, 878);
      expect(viewModel.paged.nextPage, 2);
      expect(viewModel.paged.movies.first.genreIds, [878]);
    });

    test('selecting 전체 (null) sends no genre', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();
      await viewModel.selectGenre(878);
      service.discoverCalls.clear();

      await viewModel.selectGenre(null);

      expect(viewModel.selectedGenreId, isNull);
      expect(service.discoverCalls.single.genreId, isNull);
    });

    test('a slow response of the previous genre never mixes into the new list', () async {
      final service = FakeTmdbMovieService();
      service.conditionDelays['genre:878'] = const Duration(milliseconds: 60); // 이전 장르는 느리게
      final viewModel = MovieListViewModel(service);
      await viewModel.load();

      final slow = viewModel.selectGenre(878);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final fast = viewModel.selectGenre(18); // 요청 중에도 바꿀 수 있습니다.
      await Future.wait([slow, fast]);

      expect(viewModel.selectedGenreId, 18);
      expect(viewModel.paged.movies, isNotEmpty);
      expect(viewModel.paged.movies.every((m) => m.genreIds.contains(18)), isTrue);
      expect(viewModel.paged.movies.any((m) => m.genreIds.contains(878)), isFalse);
    });

    test('first page failure is Error and retry keeps the selected genre from page 1', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();

      service.failDiscover = true;
      await viewModel.selectGenre(18);
      expect(viewModel.phase, LoadPhase.error);
      expect(viewModel.paged.errorMessage, movieListLoadFailedMessage);

      service
        ..failDiscover = false
        ..discoverCalls.clear();
      await viewModel.retry();

      expect(viewModel.phase, LoadPhase.ready);
      expect(service.discoverCalls.single.page, 1);
      expect(service.discoverCalls.single.genreId, 18);
    });

    test('empty result is Empty', () async {
      final service = FakeTmdbMovieService();
      final viewModel = MovieListViewModel(service);
      await viewModel.load();

      service.emptyDiscover = true;
      await viewModel.selectGenre(18);

      expect(viewModel.phase, LoadPhase.empty);
    });

    test('genre API failure becomes Error and loads genres again on retry', () async {
      final service = FakeTmdbMovieService()..failGenres = true;
      final viewModel = MovieListViewModel(service);

      await viewModel.load();
      expect(viewModel.phase, LoadPhase.error);

      service.failGenres = false;
      await viewModel.retry();
      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.genres, sampleGenres);
    });

    test('restores a saved genre id and falls back when it no longer exists', () async {
      final restored = MovieListViewModel(
        FakeTmdbMovieService(),
        genrePreference: MemoryGenrePreference(878),
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
      final viewModel = MovieListViewModel(FakeTmdbMovieService(), genrePreference: preference);
      await viewModel.load();

      await viewModel.selectGenre(18);

      expect(preference.value, 18);
    });

    test('does not notify after dispose', () async {
      final service = FakeTmdbMovieService(delay: const Duration(milliseconds: 20));
      final viewModel = MovieListViewModel(service);

      final loading = viewModel.load();
      viewModel.dispose();

      await loading; // 예외 없이 끝나야 합니다.
    });
  });
}
