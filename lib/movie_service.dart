import 'movie.dart';

enum MovieLoadMode { success, empty, failure }

class MovieLoadException implements Exception {
  const MovieLoadException(this.message);

  final String message;

  @override
  String toString() => 'MovieLoadException: $message';
}

const _movieModeName = String.fromEnvironment('MOVIE_MODE');

MovieLoadMode movieLoadModeFromEnvironment() {
  return switch (_movieModeName) {
    'empty' => MovieLoadMode.empty,
    'failure' => MovieLoadMode.failure,
    _ => MovieLoadMode.success,
  };
}

const _movieDelayMs = int.fromEnvironment('MOVIE_DELAY_MS', defaultValue: 1000);

class FakeMovieService {
  const FakeMovieService({this.delay = const Duration(milliseconds: _movieDelayMs)});

  final Duration delay;

  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) async {
    await Future<void>.delayed(delay);

    return switch (mode) {
      MovieLoadMode.success => movies,
      MovieLoadMode.empty => const <Movie>[],
      MovieLoadMode.failure => throw const MovieLoadException(
        '영화를 불러오지 못했습니다.',
      ),
    };
  }
}
