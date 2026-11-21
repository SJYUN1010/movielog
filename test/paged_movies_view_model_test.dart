import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/data/dto/tmdb_movie_page_dto.dart';
import 'package:movielog/view_models/load_phase.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';

import 'support/fakes.dart';

void main() {
  group('first page', () {
    test('replaces the list, sets nextPage, and goes Loading → Ready', () async {
      final service = FakeTmdbMovieService(pageSize: 20, delay: const Duration(milliseconds: 5));
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      final phases = <LoadPhase>[];
      viewModel.addListener(() => phases.add(viewModel.phase));

      await viewModel.loadInitial();

      expect(phases.first, LoadPhase.loading);
      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.movies, hasLength(20));
      expect(viewModel.nextPage, 2);
      expect(viewModel.hasMore, isTrue);
    });

    test('an empty page is Empty, a failure is Error with its own message', () async {
      final service = FakeTmdbMovieService()..emptyDiscover = true;
      final viewModel = PagedMoviesViewModel(tmdbApi: service);

      await viewModel.loadInitial();
      expect(viewModel.phase, LoadPhase.empty);

      service
        ..emptyDiscover = false
        ..failDiscover = true;
      await viewModel.loadInitial();
      expect(viewModel.phase, LoadPhase.error);
      expect(viewModel.errorMessage, movieListLoadFailedMessage);

      await viewModel.loadInitial(query: '별빛'); // 검색 조건이면 검색 오류 문구
      service.failSearch = true;
      await viewModel.loadInitial(query: '별빛');
      expect(viewModel.errorMessage, movieSearchFailedMessage);
    });

    test('inconsistent page metadata is treated as a failure instead of corrupting the list', () async {
      final service = _WrongPageService();
      final viewModel = PagedMoviesViewModel(tmdbApi: service);

      await viewModel.loadInitial();

      expect(viewModel.phase, LoadPhase.error);
      expect(viewModel.movies, isEmpty);
    });
  });

  group('next page', () {
    test('appends, skips movies that are already shown, and advances nextPage', () async {
      final service = FakeTmdbMovieService(pageSize: 20)..overlap = 5;
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();

      await viewModel.loadNextPage();

      expect(viewModel.movies, hasLength(35));
      expect(viewModel.movies.map((m) => m.id).toSet(), hasLength(35));
      expect(viewModel.nextPage, 3);
      expect(viewModel.isLoadingMore, isFalse);
    });

    test('while loading more, the shown cards stay and only isLoadingMore is on', () async {
      final service = FakeTmdbMovieService();
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();
      service.pageDelays[2] = const Duration(milliseconds: 30);

      final loading = viewModel.loadNextPage();
      expect(viewModel.isLoadingMore, isTrue);
      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.movies, isNotEmpty);

      await loading;
      expect(viewModel.isLoadingMore, isFalse);
    });

    test('a second request while one is in flight is ignored', () async {
      final service = FakeTmdbMovieService();
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();
      service.pageDelays[2] = const Duration(milliseconds: 20);
      service.discoverCalls.clear();

      final first = viewModel.loadNextPage();
      final second = viewModel.loadNextPage();
      await Future.wait([first, second]);

      expect(service.discoverCalls.map((c) => c.page), [2]);
    });

    test('a failure keeps the list and nextPage, and the retry asks for the SAME page', () async {
      final service = FakeTmdbMovieService(pageSize: 20);
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();
      final shown = viewModel.movies.length;

      service.failingPages.add(2);
      await viewModel.loadNextPage();

      expect(viewModel.loadMoreError, loadMoreFailedMessage);
      expect(viewModel.movies, hasLength(shown)); // 기존 목록 유지
      expect(viewModel.nextPage, 2); // page 번호가 넘어가지 않음
      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.isLoadingMore, isFalse);

      service
        ..failingPages.clear()
        ..discoverCalls.clear();
      await viewModel.loadNextPage();

      expect(service.discoverCalls.single.page, 2);
      expect(viewModel.loadMoreError, isNull);
      expect(viewModel.movies, hasLength(shown + 20)); // 한 page도 빠지지 않음
      expect(viewModel.nextPage, 3);
    });

    test('the last page turns hasMore off and stops requesting', () async {
      final service = FakeTmdbMovieService(totalPages: 2);
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();
      await viewModel.loadNextPage();
      service.discoverCalls.clear();

      expect(viewModel.hasMore, isFalse);
      await viewModel.loadNextPage();

      expect(service.discoverCalls, isEmpty);
    });

    test('never asks for a page above TMDB limit 500 even if total_pages is larger', () async {
      final service = FakeTmdbMovieService(totalPages: 10000);
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();

      expect(viewModel.totalPages, PagedMoviesViewModel.maxTmdbPage);
      viewModel.nextPage = PagedMoviesViewModel.maxTmdbPage + 1;
      expect(viewModel.hasMore, isFalse);
    });
  });

  group('changing the condition', () {
    test('resets list, page and the loading-more state/error, then loads page 1', () async {
      final service = FakeTmdbMovieService();
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();
      service.failingPages.add(2);
      await viewModel.loadNextPage();
      expect(viewModel.loadMoreError, isNotNull);
      service
        ..failingPages.clear()
        ..discoverCalls.clear();

      await viewModel.loadInitial(genreId: 878);

      expect(viewModel.loadMoreError, isNull);
      expect(viewModel.isLoadingMore, isFalse);
      expect(viewModel.nextPage, 2);
      expect(service.discoverCalls.single.page, 1);
      expect(service.discoverCalls.single.genreId, 878);
    });

    test('a slow response of the OLD genre is dropped, the newest request wins', () async {
      final service = FakeTmdbMovieService();
      service.conditionDelays['genre:878'] = const Duration(milliseconds: 60);
      final viewModel = PagedMoviesViewModel(tmdbApi: service);

      final slow = viewModel.loadInitial(genreId: 878);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final fast = viewModel.loadInitial(genreId: 18);
      await Future.wait([slow, fast]);

      expect(viewModel.condition.genreId, 18);
      expect(viewModel.movies.every((m) => m.genreIds.contains(18)), isTrue);
    });

    test('a slow search response of the OLD query is dropped', () async {
      final service = FakeTmdbMovieService();
      service.conditionDelays['query:어벤'] = const Duration(milliseconds: 60);
      final viewModel = PagedMoviesViewModel(tmdbApi: service);

      final slow = viewModel.loadInitial(query: '어벤');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final fast = viewModel.loadInitial(query: '별빛');
      await Future.wait([slow, fast]);

      expect(viewModel.condition.query, '별빛');
      expect(viewModel.movies.every((m) => m.title.startsWith('별빛')), isTrue);
    });

    test('a next-page response that arrives after the condition changed is dropped', () async {
      final service = FakeTmdbMovieService();
      final viewModel = PagedMoviesViewModel(tmdbApi: service);
      await viewModel.loadInitial();
      service.pageDelays[2] = const Duration(milliseconds: 40);

      final more = viewModel.loadNextPage();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      service.pageDelays.clear();
      await viewModel.loadInitial(genreId: 878);
      await more;

      expect(viewModel.movies.every((m) => m.genreIds.contains(878)), isTrue);
      expect(viewModel.movies.map((m) => m.id).toSet(), hasLength(viewModel.movies.length));
      expect(viewModel.isLoadingMore, isFalse);
    });

    test('a blank search query falls back to Discover and never calls Search with an empty query', () async {
      final service = FakeTmdbMovieService();
      final viewModel = PagedMoviesViewModel(tmdbApi: service);

      await viewModel.loadInitial(query: '   ');

      expect(service.searchCalls, isEmpty);
      expect(service.discoverCalls, hasLength(1));
    });

    test('search and discover keep independent state in separate instances', () async {
      final service = FakeTmdbMovieService();
      final list = PagedMoviesViewModel(tmdbApi: service);
      final search = PagedMoviesViewModel(tmdbApi: service);

      await list.loadInitial();
      await search.loadInitial(query: '별빛');

      expect(list.movies.first.title, isNot(startsWith('별빛')));
      expect(search.movies.first.title, startsWith('별빛'));
    });
  });

  test('does not notify after dispose', () async {
    final service = FakeTmdbMovieService(delay: const Duration(milliseconds: 20));
    final viewModel = PagedMoviesViewModel(tmdbApi: service);

    final loading = viewModel.loadInitial();
    viewModel.dispose();

    await loading; // 예외 없이 끝나야 합니다.
  });
}

/// 요청한 page와 다른 page 번호를 내려주는 서버를 흉내 냅니다.
class _WrongPageService extends FakeTmdbMovieService {
  @override
  Future<TmdbMoviePageDto> discoverMovies({int page = 1, int? genreId}) async {
    return TmdbMoviePageDto(
      page: page + 1,
      results: [movieDto(1)],
      totalPages: 5,
      totalResults: 100,
    );
  }
}
