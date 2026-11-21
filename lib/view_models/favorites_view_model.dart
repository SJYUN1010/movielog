import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'load_phase.dart';

const favoritesLoadFailedMessage = '즐겨찾기를 불러오지 못했습니다.';
const favoriteMovieLoadFailedMessage = '영화 정보를 불러오지 못했습니다.';

/// "내 즐겨찾기" 화면의 상태입니다.
///
/// 즐겨찾기 응답에는 제목·포스터가 없어서, movieId로 TMDB 영화 정보를 보충해 합칩니다(한 번에 최대 5개).
/// - 목록 조회 전체 실패(error)와 영화 한 건의 정보만 못 가져온 경우(그 카드만 placeholder)를 구분합니다.
/// - 세션(계정)이 바뀌었거나 화면이 사라진 뒤, 더 새로운 조회가 시작된 뒤 도착한 응답은 반영하지 않습니다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    this.enrichmentConcurrency = 5,
    this.onSessionExpired,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final int enrichmentConcurrency;
  final VoidCallback? onSessionExpired;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  bool _isStale(int sessionGeneration, int refreshGeneration) =>
      !sessionGuard.isCurrent(sessionGeneration, accountId) ||
      refreshGeneration != _refreshGeneration ||
      isDisposed;

  /// 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 [enrichmentConcurrency]개씩 보충합니다.
  ///
  /// [silent]가 true이고 이미 목록이 있으면 로딩 화면으로 바꾸지 않고 그 자리에서 갱신합니다
  /// (상세에서 해제하고 돌아왔을 때 화면이 깜빡이지 않게 합니다).
  Future<void> refresh({bool silent = false}) async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) return;
    final refreshGeneration = ++_refreshGeneration;

    if (!(silent && phase == LoadPhase.ready)) {
      phase = LoadPhase.loading;
      errorMessage = null;
      notifyIfAlive();
    }
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (_isStale(sessionGeneration, refreshGeneration)) return;

      // 이미 영화 정보를 받은 카드는 다시 조회하지 않습니다.
      final known = {for (final item in items) if (item.movie != null) item.favorite.movieId: item.movie!};
      final enriched = await mapBounded(favorites, enrichmentConcurrency, (favorite) async {
        final cached = known[favorite.movieId];
        if (cached != null) return FavoriteListItem(favorite: favorite, movie: cached);
        try {
          final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
          return FavoriteListItem(favorite: favorite, movie: movie);
        } catch (_) {
          // 한 건 실패로 목록 전체가 비지 않게, 그 카드만 실패 상태로 둡니다.
          return FavoriteListItem(favorite: favorite, errorMessage: favoriteMovieLoadFailedMessage);
        }
      });
      if (_isStale(sessionGeneration, refreshGeneration)) return;

      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      if (isSessionExpiredError(error)) {
        onSessionExpired?.call(); // 안내와 이동은 로그인 화면과 Router가 맡습니다.
        return;
      }
      _fail();
    } catch (_) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      _fail();
    } finally {
      if (!_isStale(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  void _fail() {
    // 이미 목록이 있으면 그대로 두고, 처음부터 실패한 경우에만 오류 화면으로 바꿉니다.
    if (items.isEmpty) {
      phase = LoadPhase.error;
      errorMessage = favoritesLoadFailedMessage;
    }
  }

  /// 영화 정보를 못 가져온 카드 한 장만 다시 조회합니다. 다른 카드와 목록은 그대로 둡니다.
  Future<void> retryMovie(int movieId) async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) return;
    final refreshGeneration = _refreshGeneration;
    final index = items.indexWhere((item) => item.favorite.movieId == movieId);
    if (index < 0 || items[index].movie != null) return;

    try {
      final movie = await tmdbApi.fetchMovieDetail(movieId);
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      items = [
        for (final item in items)
          item.favorite.movieId == movieId ? FavoriteListItem(favorite: item.favorite, movie: movie) : item,
      ];
    } catch (_) {
      if (_isStale(sessionGeneration, refreshGeneration)) return;
      // 실패해도 카드는 그대로 두고 다시 시도할 수 있게 합니다.
    }
    notifyIfAlive();
  }
}
