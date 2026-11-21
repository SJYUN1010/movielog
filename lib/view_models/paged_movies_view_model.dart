import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/dto/tmdb_movie_dto.dart';
import '../data/dto/tmdb_movie_page_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

const movieListLoadFailedMessage = '영화 목록을 불러오지 못했습니다.';
const movieSearchFailedMessage = '검색 결과를 불러오지 못했습니다.';
const loadMoreFailedMessage = '추가 영화 조회에 실패했습니다.';

/// "더 보기"로 한 page씩 영화를 가져오는 목록 상태입니다. 영화 목록(Discover)과 검색(Search)이 각각
/// 별도 인스턴스로 같은 클래스를 씁니다.
///
/// - 첫 page 성공 → 기존 목록을 교체합니다.
/// - 더 보기 → 기존 카드를 유지한 채 [isLoadingMore]만 켭니다.
/// - 성공 → 같은 movieId는 제외하고 이어 붙이고 [nextPage]를 올립니다.
/// - 실패 → 목록과 [nextPage]를 그대로 두고 같은 page를 다시 요청할 수 있게 합니다.
/// - 조건(장르·검색어)을 바꾸면 요청 generation을 올려서, 이전 조건의 늦은 응답이 새 목록에 섞이지 않게 합니다.
class PagedMoviesViewModel extends ChangeNotifier with SafeNotify {
  PagedMoviesViewModel({required this.tmdbApi});

  final TmdbMovieService tmdbApi;

  /// TMDB의 page는 1~500입니다. total_pages가 더 커도 501은 요청하지 않습니다.
  static const maxTmdbPage = 500;

  LoadPhase phase = LoadPhase.idle;
  final List<TmdbMovieDto> movies = [];
  int nextPage = 1;
  int totalPages = 1;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreError;

  int _requestGeneration = 0;
  ({int? genreId, String query}) _condition = (genreId: null, query: '');

  ({int? genreId, String query}) get condition => _condition;
  bool get hasMore => nextPage <= totalPages;

  /// 조건을 바꿔 첫 page부터 다시 불러옵니다. 목록·page·추가 로딩 상태·오류를 모두 초기화합니다.
  Future<void> loadInitial({int? genreId, String query = ''}) async {
    if (isDisposed) return;
    _condition = (genreId: genreId, query: query.trim());
    final generation = ++_requestGeneration;
    phase = LoadPhase.loading;
    errorMessage = null;
    loadMoreError = null;
    isLoadingMore = false;
    movies.clear();
    nextPage = 1;
    totalPages = 1;
    notifyIfAlive();
    try {
      final page = await _fetchPage(1, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _applyFirstPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      debugPrint('영화 첫 page 조회 실패: ${error.runtimeType}');
      phase = LoadPhase.error;
      errorMessage = _condition.query.isEmpty ? movieListLoadFailedMessage : movieSearchFailedMessage;
    } finally {
      if (generation == _requestGeneration && !isDisposed) notifyIfAlive();
    }
  }

  /// 실패해도 [nextPage]를 올리지 않아 같은 page를 다시 요청할 수 있습니다.
  Future<void> loadNextPage() async {
    if (isDisposed || isLoadingMore || !hasMore || phase != LoadPhase.ready) return;
    final generation = _requestGeneration;
    final pageToLoad = nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyIfAlive();
    try {
      final page = await _fetchPage(pageToLoad, _condition);
      if (generation != _requestGeneration || isDisposed) return;
      _appendPage(page);
    } catch (error) {
      if (generation != _requestGeneration || isDisposed) return;
      debugPrint('영화 다음 page($pageToLoad) 조회 실패: ${error.runtimeType}');
      loadMoreError = loadMoreFailedMessage;
    } finally {
      if (generation == _requestGeneration && !isDisposed) {
        isLoadingMore = false;
        notifyIfAlive();
      }
    }
  }

  Future<TmdbMoviePageDto> _fetchPage(int page, ({int? genreId, String query}) condition) async {
    final result = condition.query.isNotEmpty
        ? await tmdbApi.searchMovies(page: page, query: condition.query)
        : await tmdbApi.discoverMovies(page: page, genreId: condition.genreId);
    if (result.page != page || result.page < 1 || result.totalPages < 0) {
      throw const FormatException('TMDB page metadata is inconsistent.');
    }
    return result;
  }

  void _applyFirstPage(TmdbMoviePageDto page) {
    movies
      ..clear()
      ..addAll(_dedupe(page.results));
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
    phase = movies.isEmpty ? LoadPhase.empty : LoadPhase.ready;
  }

  void _appendPage(TmdbMoviePageDto page) {
    movies.addAll(_dedupe(page.results));
    totalPages = page.totalPages > maxTmdbPage ? maxTmdbPage : page.totalPages;
    nextPage = page.page + 1;
  }

  /// TMDB는 page가 바뀌어도 같은 영화가 다시 내려올 수 있어서 이미 가진 movieId는 제외합니다.
  List<TmdbMovieDto> _dedupe(List<TmdbMovieDto> incoming) {
    final seen = movies.map((movie) => movie.id).toSet();
    return incoming.where((movie) => seen.add(movie.id)).toList(growable: false);
  }
}
