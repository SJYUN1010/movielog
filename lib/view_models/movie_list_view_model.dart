import 'dart:async';

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
      debugPrint('[영화 목록] genreId=${selectedGenreId ?? '전체'} → ${movies.length}개');
      status = movies.isEmpty
          ? MovieListLoadStatus.empty
          : MovieListLoadStatus.success;
    } catch (error, stackTrace) {
      if (requestId != _requestId) return;
      debugPrint('영화 목록 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
      status = MovieListLoadStatus.error;
    }
    _notify();
  }

  Future<void> retry() => load();

  /// 요청 중에는 장르를 바꿀 수 없습니다. null은 "전체"입니다.
  Future<void> selectGenre(int? genreId) async {
    if (isLoading || genreId == selectedGenreId) return;

    selectedGenreId = genreId;
    movies = const [];
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
