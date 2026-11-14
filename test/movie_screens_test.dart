import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/screens/movie_detail_loader.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/genre_filter_chips.dart';
import 'package:movielog/widgets/movie_list_retry_dialog.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

GoRouter _testRouter(
  FakeTmdbMovieService service, {
  String initial = '/home',
  MemoryGenrePreference? preference,
}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => MovieHomeViewModel(context.read<TmdbMovieService>())..load(),
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/movies',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => MovieListViewModel(
            context.read<TmdbMovieService>(),
            genrePreference: preference ?? MemoryGenrePreference(),
          )..load(),
          child: const MovieListScreen(),
        ),
      ),
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) => MovieDetailLoader(
          movieId: int.parse(state.pathParameters['movieId']!),
          initialMovie: state.extra as TmdbMovieDto?,
        ),
      ),
    ],
  );
}

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  FakeTmdbMovieService service, {
  String initial = '/home',
  MemoryGenrePreference? preference,
}) async {
  _useMobileViewport(tester);
  final router = _testRouter(service, initial: initial, preference: preference);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TmdbMovieService>.value(value: service),
        Provider<RatingApiService>.value(value: FakeRatingApiService()),
        ChangeNotifierProvider<LearningMemberSession>.value(
          value: LearningMemberSession(memberId: 12),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  return router;
}

void main() {
  group('HomeScreen', () {
    testWidgets('shows Loading, then the hero and 5 ranked popular movies', (tester) async {
      final service = FakeTmdbMovieService(
        popular: [for (var i = 1; i <= 20; i++) movieDto(i)],
        delay: const Duration(milliseconds: 50),
      );
      await _pumpApp(tester, service);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('인기 영화'), findsOneWidget);
      expect(find.text('영화 1'), findsNWidgets(2));

      await tester.drag(find.text('영화 2'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('영화 5'), findsOneWidget);
      expect(find.text('영화 6'), findsNothing);
      expect(service.popularCalls, 1);
    });

    testWidgets('shows a friendly error and retries with a new request', (tester) async {
      final service = FakeTmdbMovieService(popular: [movieDto(1)])..failPopular = true;
      await _pumpApp(tester, service);
      await tester.pumpAndSettle();

      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);

      service.failPopular = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('인기 영화'), findsOneWidget);
      expect(service.popularCalls, 2);
    });

    testWidgets('shows a placeholder when poster_path is null', (tester) async {
      final service = FakeTmdbMovieService(
        popular: [movieDto(1, posterPath: null)],
      );
      await _pumpApp(tester, service);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.movie_outlined), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('card tap opens the detail with that TMDB id and back returns', (tester) async {
      final service = FakeTmdbMovieService(
        popular: [for (var i = 101; i <= 105; i++) movieDto(i)],
      );
      await _pumpApp(tester, service);
      await tester.pumpAndSettle();

      await tester.tap(find.text('영화 102'));
      await tester.pumpAndSettle();

      final detail = tester.widget<MovieDetailLoader>(find.byType(MovieDetailLoader));
      expect(detail.movieId, 102);
      expect(detail.initialMovie?.id, 102);
      expect(find.text('영화 102 줄거리'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailLoader), findsNothing);
      expect(find.text('인기 영화'), findsOneWidget);
    });
  });

  group('MovieListScreen', () {
    testWidgets('shows Loading, then genre chips and up to 30 movies', (tester) async {
      final service = FakeTmdbMovieService(delay: const Duration(milliseconds: 50));
      await _pumpApp(tester, service, initial: '/movies');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('전체'), findsOneWidget);
      expect(find.text('드라마'), findsOneWidget);
      expect(find.text('SF'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
    });

    testWidgets('tapping a genre re-requests page 1 with that genre id', (tester) async {
      final service = FakeTmdbMovieService();
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      service.discoverCalls.clear();

      await tester.tap(find.text('SF'));
      await tester.pumpAndSettle();

      expect(service.discoverCalls.first.page, 1);
      expect(service.discoverCalls.first.genreId, 878);

      service.discoverCalls.clear();
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();
      expect(service.discoverCalls.first.genreId, isNull);
    });

    testWidgets('genre chips are blocked while a request is running', (tester) async {
      final service = FakeTmdbMovieService(delay: const Duration(milliseconds: 100));
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      service.discoverCalls.clear();

      await tester.tap(find.text('SF'));
      await tester.pump();
      await tester.tap(find.text('드라마'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(service.discoverCalls.map((c) => c.genreId).toSet(), {878});
    });

    Finder dialogButton(String label) => find.descendant(
      of: find.byType(MovieListRetryDialog),
      matching: find.text(label),
    );

    testWidgets('Empty, then Error with the retry Dialog and retry', (tester) async {
      final service = FakeTmdbMovieService()..emptyDiscover = true;
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);

      service
        ..emptyDiscover = false
        ..failDiscover = true;
      await tester.tap(find.text('SF'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieListRetryDialog), findsOneWidget);
      expect(find.text('영화를 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);

      service
        ..failDiscover = false
        ..discoverCalls.clear();
      await tester.tap(dialogButton('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.byType(MovieListRetryDialog), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      expect(service.discoverCalls.first.genreId, 878);
      expect(service.discoverCalls.first.page, 1);
    });

    testWidgets('a failure keeps the last list behind the Dialog; cancel restores its genre', (
      tester,
    ) async {
      final service = FakeTmdbMovieService();
      final preference = MemoryGenrePreference();
      await _pumpApp(tester, service, initial: '/movies', preference: preference);
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);

      service.failDiscover = true;
      await tester.tap(find.text('SF'));
      await tester.pumpAndSettle();

      expect(find.byType(MovieListRetryDialog), findsOneWidget);
      // Dialog 뒤에는 최근에 성공한 목록이 그대로 남아 있습니다.
      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();

      expect(find.byType(MovieListRetryDialog), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      final chips = tester.widget<GenreFilterChips>(find.byType(GenreFilterChips));
      expect(chips.selectedGenreId, isNull);
      expect(preference.value, isNull);
    });

    testWidgets('the Dialog appears once per failure, not on every rebuild', (tester) async {
      final service = FakeTmdbMovieService()..failDiscover = true;
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      expect(find.byType(MovieListRetryDialog), findsOneWidget);

      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();

      // 한 번도 성공한 적이 없으면 Error 화면과 다시 시도 버튼이 남습니다.
      expect(find.byType(MovieListRetryDialog), findsNothing);
      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieListRetryDialog), findsOneWidget);
    });

    testWidgets('restores the saved genre chip on launch', (tester) async {
      final service = FakeTmdbMovieService();
      await _pumpApp(
        tester,
        service,
        initial: '/movies',
        preference: MemoryGenrePreference(878),
      );
      await tester.pumpAndSettle();

      expect(service.discoverCalls.first.genreId, 878);
    });
  });

  group('AppRouter wiring', () {
    testWidgets('the real router builds Home from the provided service', (tester) async {
      _useMobileViewport(tester);
      final service = FakeTmdbMovieService(popular: [movieDto(1, title: '실제 라우터')]);

      await tester.pumpWidget(
        Provider<TmdbMovieService>.value(
          value: service,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: AppRouter.router,
          ),
        ),
      );
      AppRouter.router.go('/home');
      await tester.pumpAndSettle();

      expect(find.text('실제 라우터'), findsWidgets);
      expect(find.text('홈'), findsWidgets);
    });
  });
}
