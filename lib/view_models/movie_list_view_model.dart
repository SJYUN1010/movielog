import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/safe_notify.dart';
import '../data/dto/tmdb_genre_dto.dart';
import '../data/dto/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../genre_preference.dart';
import 'load_phase.dart';
import 'paged_movies_view_model.dart';

/// 영화 목록 화면의 장르 필터와 선택을 맡고, 영화 page 조회는 [paged]에 맡깁니다.
///
/// 5주차에는 Discover API를 여러 번 불러 최대 30개를 한 번에 모았지만, 9주차부터는 첫 page만 보여주고
/// "더 보기"를 누를 때마다 한 page씩 가져옵니다. 장르를 바꾸면 목록을 비우고 첫 page부터 다시 불러오며,
/// 이전 장르의 늦은 응답은 [PagedMoviesViewModel]의 요청 generation이 무시합니다.
class MovieListViewModel extends ChangeNotifier with SafeNotify {
  MovieListViewModel(this._service, {this.genrePreference, PagedMoviesViewModel? paged})
    : paged = paged ?? PagedMoviesViewModel(tmdbApi: _service) {
    this.paged.addListener(notifyIfAlive);
  }

  final TmdbMovieService _service;
  final GenrePreference? genrePreference;
  final PagedMoviesViewModel paged;

  List<TmdbGenreDto> genres = const [];
  int? selectedGenreId;

  bool _genresLoading = false;
  bool _genresFailed = false;
  bool _savedGenreRestored = false;

  /// 장르 목록 조회가 끝나기 전에는 loading, 실패하면 error이고, 그 뒤에는 영화 page 상태를 그대로 따릅니다.
  LoadPhase get phase {
    if (_genresFailed) return LoadPhase.error;
    if (_genresLoading) return LoadPhase.loading;
    return paged.phase;
  }

  String genreNameOf(int id) {
    for (final genre in genres) {
      if (genre.id == id) return genre.name;
    }
    return '';
  }

  String subtitleOf(TmdbMovieDto movie) {
    final genre = movie.genreIds.isEmpty ? '' : genreNameOf(movie.genreIds.first);
    final year = movie.releaseYear?.toString() ?? '';
    return [genre, year].where((text) => text.isNotEmpty).join(' · ');
  }

  /// 장르 목록과 저장된 장르를 준비한 뒤 첫 page를 불러옵니다.
  Future<void> load() async {
    if (isDisposed) return;
    _genresLoading = true;
    _genresFailed = false;
    notifyIfAlive();

    try {
      if (genres.isEmpty) genres = await _service.fetchGenres();
      if (isDisposed) return;
      if (!_savedGenreRestored) {
        _savedGenreRestored = true;
        final savedId = await genrePreference?.read();
        selectedGenreId = genres.any((genre) => genre.id == savedId) ? savedId : null;
      }
    } catch (error) {
      if (isDisposed) return;
      debugPrint('장르 목록 조회 실패: ${error.runtimeType}');
      _genresLoading = false;
      _genresFailed = true;
      notifyIfAlive();
      return;
    }

    _genresLoading = false;
    notifyIfAlive();
    await paged.loadInitial(genreId: selectedGenreId);
  }

  /// 마지막으로 선택한 장르 조건 그대로 첫 page부터 다시 불러옵니다.
  Future<void> retry() async {
    if (genres.isEmpty) return load();
    await paged.loadInitial(genreId: selectedGenreId);
  }

  /// null은 "전체"입니다. 요청 중에도 바꿀 수 있고, 이전 장르의 늦은 응답은 버려집니다.
  Future<void> selectGenre(int? genreId) async {
    if (genreId == selectedGenreId) return;
    selectedGenreId = genreId;
    notifyIfAlive();
    unawaited(_saveGenre(genreId));
    await paged.loadInitial(genreId: genreId);
  }

  Future<void> _saveGenre(int? genreId) async {
    try {
      await genrePreference?.save(genreId);
    } catch (error) {
      debugPrint('장르 저장 실패: $error');
    }
  }

  @override
  void dispose() {
    paged.removeListener(notifyIfAlive);
    paged.dispose();
    super.dispose();
  }
}
