import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_genre_dto.dart';
import '../data/dto/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../genre_preference.dart';

enum MovieListLoadStatus { idle, loading, success, empty, error }

class MovieListViewModel extends ChangeNotifier {
  MovieListViewModel(this._service, {this.genrePreference});

  static const movieLimit = 30;

  final TmdbMovieService _service;
  final GenrePreference? genrePreference;

  List<TmdbGenreDto> genres = const [];
  List<TmdbMovieDto> movies = const [];
  int? selectedGenreId;
  MovieListLoadStatus status = MovieListLoadStatus.idle;

  int _requestId = 0;
  bool _savedGenreRestored = false;
  bool _disposed = false;

  /// 가장 최근에 성공한(Success 또는 Empty) 목록과 그때의 장르입니다. 실패해도 유지합니다.
  List<TmdbMovieDto> _lastMovies = const [];
  int? _lastGenreId;
  bool _hasLoaded = false;

  /// 실패할 때마다 올립니다. 화면이 같은 실패에 재시도 Dialog를 한 번만 띄우는 기준입니다.
  int errorCount = 0;

  bool get isLoading => status == MovieListLoadStatus.loading;

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

  Future<void> load() async {
    final requestId = ++_requestId;
    status = MovieListLoadStatus.loading;
    _notify();

    try {
      if (genres.isEmpty) {
        genres = await _service.fetchGenres();
      }
      if (!_savedGenreRestored) {
        _savedGenreRestored = true;
        final savedId = await genrePreference?.read();
        selectedGenreId = genres.any((genre) => genre.id == savedId) ? savedId : null;
      }

      final result = await _fetchUpToLimit(genreId: selectedGenreId);
      if (requestId != _requestId) return;

      movies = result;
      _lastMovies = result;
      _lastGenreId = selectedGenreId;
      _hasLoaded = true;
      debugPrint('[영화 목록] genreId=${selectedGenreId ?? '전체'} → ${movies.length}개');
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } catch (error, stackTrace) {
      if (requestId != _requestId) return;
      _logFailure(error, stackTrace);
      status = MovieListLoadStatus.error;
      errorCount++;
    }
    _notify();
  }

  /// 마지막으로 선택한 장르 조건 그대로 page 1부터 다시 불러옵니다.
  Future<void> retry() => load();

  /// 재시도 Dialog에서 취소하면 최근 성공한 목록과 그 장르로 되돌립니다.
  /// 아직 한 번도 성공한 적이 없으면 Error 상태를 유지합니다.
  void cancelRetry() {
    if (status != MovieListLoadStatus.error || !_hasLoaded) return;

    selectedGenreId = _lastGenreId;
    movies = _lastMovies;
    status = movies.isEmpty
        ? MovieListLoadStatus.empty
        : MovieListLoadStatus.success;
    unawaited(_saveGenre(selectedGenreId));
    _notify();
  }

  /// 요청 중에는 장르를 바꿀 수 없습니다. null은 "전체"입니다.
  Future<void> selectGenre(int? genreId) async {
    if (isLoading || genreId == selectedGenreId) return;

    // 실패하면 최근 성공한 목록으로 되돌릴 수 있도록 movies는 지우지 않습니다.
    selectedGenreId = genreId;
    unawaited(_saveGenre(genreId));
    await load();
  }

  Future<void> _saveGenre(int? genreId) async {
    try {
      await genrePreference?.save(genreId);
    } catch (error) {
      debugPrint('장르 저장 실패: $error');
    }
  }

  Future<List<TmdbMovieDto>> _fetchUpToLimit({int? genreId}) async {
    final byId = <int, TmdbMovieDto>{};
    var pageNumber = 1;
    var hasNextPage = true;

    while (byId.length < movieLimit && hasNextPage) {
      final page = await _service.discoverMovies(
        page: pageNumber,
        genreId: genreId,
      );
      for (final movie in page.results) {
        byId.putIfAbsent(movie.id, () => movie);
      }
      hasNextPage = pageNumber < page.totalPages && page.results.isNotEmpty;
      pageNumber++;
    }
    return byId.values.take(movieLimit).toList();
  }

  /// 실패한 요청의 URL과 오류 메시지를 남깁니다. 토큰은 Interceptor가 이미 마스킹합니다.
  void _logFailure(Object error, StackTrace stackTrace) {
    if (error is DioException) {
      debugPrint(
        '영화 목록 로드 실패: ${error.requestOptions.uri} '
        '(${error.response?.statusCode ?? error.type.name}) ${error.message}',
      );
    } else {
      debugPrint('영화 목록 로드 실패: $error');
    }
    debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
