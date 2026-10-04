import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/genre_preference.dart';
import 'package:movielog/movie.dart';
import 'package:movielog/movie_list_screen.dart';
import 'package:movielog/movie_service.dart';
import 'package:movielog/theme/app_theme.dart';

class MemoryGenrePreference implements GenrePreference {
  MemoryGenrePreference([this.value = GenrePreference.defaultGenre]);

  String value;

  @override
  Future<String> read() async => value;

  @override
  Future<void> save(String genre) async => value = genre;

  @override
  Future<void> clear() async => value = GenrePreference.defaultGenre;
}

class CountingMovieService extends FakeMovieService {
  CountingMovieService({super.delay});

  int calls = 0;

  @override
  Future<List<Movie>> fetchMovies({
    MovieLoadMode mode = MovieLoadMode.success,
  }) {
    calls += 1;
    return super.fetchMovies(mode: mode);
  }
}

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpList(
  WidgetTester tester, {
  FakeMovieService service = const FakeMovieService(),
  MemoryGenrePreference? preference,
  MovieLoadMode mode = MovieLoadMode.success,
}) async {
  _useMobileViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MovieListScreen(
        service: service,
        genrePreference: preference ?? MemoryGenrePreference(),
        initialMode: mode,
      ),
    ),
  );
}

void main() {
  group('FakeMovieService', () {
    const service = FakeMovieService(delay: Duration.zero);

    test('success returns the mock movies', () async {
      expect(await service.fetchMovies(), movies);
    });

    test('empty returns an empty list', () async {
      expect(await service.fetchMovies(mode: MovieLoadMode.empty), isEmpty);
    });

    test('failure throws MovieLoadException', () async {
      expect(
        service.fetchMovies(mode: MovieLoadMode.failure),
        throwsA(isA<MovieLoadException>()),
      );
    });
  });

  group('MovieListScreen', () {
    testWidgets('shows Loading for at least 800ms, then the Success grid', (
      tester,
    ) async {
      await _pumpList(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('별빛 아래 우리'), findsNothing);

      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('별빛 아래 우리'), findsOneWidget);
    });

    testWidgets('shows the Empty message when the service returns no movies', (
      tester,
    ) async {
      await _pumpList(
        tester,
        service: const FakeMovieService(delay: Duration.zero),
        mode: MovieLoadMode.empty,
      );
      await tester.pumpAndSettle();

      expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('shows a friendly Error and recovers with a new Future on retry', (
      tester,
    ) async {
      final service = CountingMovieService(delay: Duration.zero);
      await _pumpList(tester, service: service, mode: MovieLoadMode.failure);
      await tester.pumpAndSettle();

      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.textContaining('MovieLoadException'), findsNothing);
      expect(find.text('조건에 맞는 영화가 없습니다.'), findsNothing);
      expect(service.calls, 1);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('별빛 아래 우리'), findsOneWidget);
      expect(service.calls, 2);
    });

    testWidgets('does not create a new Future when the screen rebuilds', (
      tester,
    ) async {
      final service = CountingMovieService(delay: Duration.zero);
      await _pumpList(tester, service: service);
      await tester.pumpAndSettle();
      expect(service.calls, 1);

      await tester.tap(find.text('SF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('드라마'));
      await tester.pumpAndSettle();

      expect(service.calls, 1);
    });

    testWidgets('filters the grid and saves the selected genre', (tester) async {
      final preference = MemoryGenrePreference();
      await _pumpList(
        tester,
        service: const FakeMovieService(delay: Duration.zero),
        preference: preference,
      );
      await tester.pumpAndSettle();

      expect(find.text('별빛 아래 우리'), findsOneWidget);
      expect(find.text('우주의 끝에서'), findsOneWidget);

      await tester.tap(find.text('SF'));
      await tester.pumpAndSettle();

      expect(find.text('우주의 끝에서'), findsOneWidget);
      expect(find.text('별빛 아래 우리'), findsNothing);
      expect(preference.value, 'SF');
    });

    testWidgets('restores the saved genre on the next launch', (tester) async {
      await _pumpList(
        tester,
        service: const FakeMovieService(delay: Duration.zero),
        preference: MemoryGenrePreference('SF'),
      );
      await tester.pumpAndSettle();

      expect(find.text('우주의 끝에서'), findsOneWidget);
      expect(find.text('별빛 아래 우리'), findsNothing);
    });

    testWidgets('falls back to 전체 when the saved genre no longer exists', (
      tester,
    ) async {
      await _pumpList(
        tester,
        service: const FakeMovieService(delay: Duration.zero),
        preference: MemoryGenrePreference('사라진 장르'),
      );
      await tester.pumpAndSettle();

      expect(find.text('별빛 아래 우리'), findsOneWidget);
      expect(find.text('우주의 끝에서'), findsOneWidget);
    });
  });
}
