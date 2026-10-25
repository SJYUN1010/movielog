import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';

enum MovieHomeLoadStatus { idle, loading, success, empty, error }

class MovieHomeViewModel extends ChangeNotifier {
  MovieHomeViewModel(this._service);

  static const popularLimit = 5;

  final TmdbMovieService _service;

  List<TmdbMovieDto> popularMovies = const [];
  MovieHomeLoadStatus status = MovieHomeLoadStatus.idle;
  bool _disposed = false;

  Future<void> load() async {
    status = MovieHomeLoadStatus.loading;
    _notify();

    try {
      final page = await _service.fetchPopular();
      popularMovies = page.results.take(popularLimit).toList();
      status = popularMovies.isEmpty
          ? MovieHomeLoadStatus.empty
          : MovieHomeLoadStatus.success;
    } catch (error, stackTrace) {
      debugPrint('인기 영화 로드 실패: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);
      popularMovies = const [];
      status = MovieHomeLoadStatus.error;
    }
    _notify();
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
