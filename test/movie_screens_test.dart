import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/screens/movie_search_screen.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/email_preference.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/home_screen.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/screens/movie_detail_loader.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/screens/movie_list_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/movie_home_view_model.dart';
import 'package:movielog/view_models/movie_list_view_model.dart';
import 'package:movielog/widgets/genre_filter_chips.dart';
import 'package:movielog/widgets/movie_card.dart';

import 'support/fakes.dart';

/// 영화 목록의 세로 스크롤입니다(장르 chip의 가로 스크롤과 구분합니다).
Finder _listScrollable() =>
    find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;

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
        path: '/movies/search',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => PagedMoviesViewModel(tmdbApi: context.read<TmdbMovieService>()),
          child: MovieSearchScreen(
            onOpenMovie: (movie) async => context.push('/movies/${movie.id}', extra: movie),
          ),
        ),
      ),
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          final movieId = int.parse(state.pathParameters['movieId']!);
          return ChangeNotifierProvider<FavoriteDetailViewModel>(
            create: (context) => FavoriteDetailViewModel(
              movieId: movieId,
              favoriteApi: context.read<FavoriteApiService>(),
              sessionGuard: _guard,
              accountId: 'movie@example.com',
            ),
            child: MovieDetailLoader(movieId: movieId, initialMovie: state.extra as TmdbMovieDto?),
          );
        },
      ),
    ],
  );
}

final SessionGuard _guard = SessionGuard()..startSession('movie@example.com');

Future<GoRouter> _pumpApp(
  WidgetTester tester,
  FakeTmdbMovieService service, {
  String initial = '/home',
  MemoryGenrePreference? preference,
}) async {
  _useMobileViewport(tester);
  final router = _testRouter(service, initial: initial, preference: preference);
  final auth = (await tester.runAsync(signedInAuthViewModel))!;
  final ratings = FakeRatingApiService();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TmdbMovieService>.value(value: service),
        Provider<RatingApiService>.value(value: ratings),
        Provider<FavoriteApiService>.value(value: FakeFavoriteApiService()),
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider<MyRatingsViewModel>.value(
          value: MyRatingsViewModel(ratings, service, auth),
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

  group('MovieListScreen (page based)', () {
    testWidgets('shows Loading, then genre chips, only the first page and a 더 보기 button', (tester) async {
      final service = FakeTmdbMovieService(pageSize: 20, delay: const Duration(milliseconds: 50));
      await _pumpApp(tester, service, initial: '/movies');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('전체'), findsOneWidget);
      expect(find.text('드라마'), findsOneWidget);
      expect(find.text('SF'), findsOneWidget);
      expect(find.byType(GridView), findsNothing); // CustomScrollView + SliverGrid
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(service.discoverCalls.map((c) => c.page), [1]); // 30개 수집이 아니라 첫 page만
      await tester.scrollUntilVisible(find.text('더 보기'), 400, scrollable: _listScrollable());
      expect(find.text('더 보기'), findsOneWidget);
    });

    testWidgets('더 보기 appends the next page below the shown cards and keeps them while loading', (tester) async {
      final service = FakeTmdbMovieService(pageSize: 20);
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      service.pageDelays[2] = const Duration(milliseconds: 300);

      await tester.scrollUntilVisible(find.text('더 보기'), 400, scrollable: _listScrollable());
      await tester.ensureVisible(find.text('더 보기'));
      await tester.pump();
      await tester.tap(find.text('더 보기'));
      await tester.pump(const Duration(milliseconds: 50));

      // 추가 로딩 중: 버튼은 로딩 상태(라벨 대신 인디케이터)이고 기존 카드는 그대로입니다.
      expect(find.text('더 보기'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(MovieCard), findsWidgets); // 스크롤 위치의 기존 카드가 그대로 보임

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(service.discoverCalls.map((c) => c.page), [1, 2]);
    });

    testWidgets('a failed next page shows the retry button and asks for the SAME page again', (tester) async {
      final service = FakeTmdbMovieService(pageSize: 20);
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      service.failingPages.add(2);

      await tester.scrollUntilVisible(find.text('더 보기'), 400, scrollable: _listScrollable());
      await tester.ensureVisible(find.text('더 보기'));
      await tester.pump();
      await tester.tap(find.text('더 보기'));
      await tester.pumpAndSettle();

      expect(find.text(loadMoreFailedMessage), findsOneWidget);
      expect(find.text('다음 페이지 다시 시도'), findsOneWidget);
      expect(find.byType(MovieCard), findsWidgets); // 기존 목록 유지

      service
        ..failingPages.clear()
        ..discoverCalls.clear();
      await tester.tap(find.text('다음 페이지 다시 시도'));
      await tester.pumpAndSettle();

      expect(service.discoverCalls.single.page, 2);
      expect(find.text(loadMoreFailedMessage), findsNothing);
    });

    testWidgets('the last page hides 더 보기 and says every movie was checked', (tester) async {
      final service = FakeTmdbMovieService(pageSize: 20, totalPages: 1);
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('모든 영화를 확인했습니다.'), 400, scrollable: _listScrollable());

      expect(find.text('모든 영화를 확인했습니다.'), findsOneWidget);
      expect(find.text('더 보기'), findsNothing);
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

    testWidgets('chips stay usable while loading, and the older genre response never wins', (tester) async {
      final service = FakeTmdbMovieService();
      service.conditionDelays['genre:878'] = const Duration(milliseconds: 300);
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      service.discoverCalls.clear();

      await tester.tap(find.text('SF')); // 느린 요청
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('드라마')); // 요청 중에도 바꿀 수 있음
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(service.discoverCalls.map((c) => c.genreId), [878, 18]);
      final chips = tester.widget<GenreFilterChips>(find.byType(GenreFilterChips));
      expect(chips.selectedGenreId, 18);
    });

    testWidgets('Empty, then Error with a retry button (no retry Dialog any more)', (tester) async {
      final service = FakeTmdbMovieService()..emptyDiscover = true;
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 영화가 없습니다.'), findsOneWidget);

      service
        ..emptyDiscover = false
        ..failDiscover = true;
      await tester.tap(find.text('SF'));
      await tester.pumpAndSettle();
      expect(find.text(movieListLoadFailedMessage), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);

      service
        ..failDiscover = false
        ..discoverCalls.clear();
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(service.discoverCalls.first.genreId, 878);
      expect(service.discoverCalls.first.page, 1);
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

    testWidgets('the search icon opens the search screen', (tester) async {
      final service = FakeTmdbMovieService();
      await _pumpApp(tester, service, initial: '/movies');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('영화 검색'));
      await tester.pumpAndSettle();

      expect(find.text('영화 검색'), findsWidgets);
      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);
    });
  });

  group('AppRouter wiring', () {
    testWidgets('the real router builds Home from the provided service', (tester) async {
      _useMobileViewport(tester);
      final service = FakeTmdbMovieService(popular: [movieDto(1, title: '실제 라우터')]);
      final auth = (await tester.runAsync(signedInAuthViewModel))!;
      final router = AppRouter.createRouter(auth);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: service),
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // 로그인된 상태라 시작 화면(/start)에서 홈으로 보내집니다. 내 정보는 MainScreen이 한 번 불러옵니다.
      expect(find.text('실제 라우터'), findsWidgets);
      expect(find.text('홈'), findsWidgets);
      expect(auth.member?.nickname, '무비러버');
    });

    testWidgets('a signed out user is sent to the login screen from a protected path', (tester) async {
      _useMobileViewport(tester);
      final service = FakeTmdbMovieService();
      final auth = AuthViewModel(FakeAuthApiService(), FakeMemberApiService(), MemoryTokenStorage());
      await tester.runAsync(auth.restoreSession); // 토큰 없음 → signedOut
      final router = AppRouter.createRouter(auth);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: service),
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            Provider<EmailPreference>.value(value: MemoryEmailPreference()),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      router.go('/my');
      await tester.pumpAndSettle();

      expect(find.text('MovieLog에 로그인'), findsOneWidget);
      expect(find.text('내 프로필'), findsNothing);
    });

    testWidgets('a 401 while the rating Dialog is saving ends on the login screen without a blank screen', (
      tester,
    ) async {
      // 회귀 테스트: 만료로 Router가 먼저 페이지를 교체한 뒤 Dialog가 pop을 다시 부르면
      // 남은 마지막 페이지가 닫혀 "no pages left to show" 오류와 빈 화면이 생겼습니다.
      _useMobileViewport(tester);
      final service = FakeTmdbMovieService()..movieDetails[550] = movieDto(550, title: '파이트 클럽');
      final ratings = FakeRatingApiService(delay: const Duration(milliseconds: 40))
        ..createFailure = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다. 다시 로그인해주세요.');
      final storage = MemoryTokenStorage();
      final auth = (await tester.runAsync(() => signedInAuthViewModel(storage: storage)))!;
      final bridge = AuthSessionBridge(
        authSignals: auth,
        sessionVersion: () => auth.sessionVersion,
        verifiedEmail: () => auth.status == AuthStatus.signedIn ? auth.member?.email : null,
      );
      addTearDown(bridge.dispose);
      await tester.runAsync(auth.loadMember); // 상세 Route는 내 정보가 준비된 뒤에 열립니다.
      final router = AppRouter.createRouter(auth);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: service),
            Provider<RatingApiService>.value(value: ratings),
            // 이미 즐겨찾기한 영화라 평점 Dialog는 평점 API(POST /v8/ratings)만 씁니다.
            Provider<FavoriteApiService>.value(value: FakeFavoriteApiService(movieIds: [550])),
            Provider<SessionGuard>.value(value: bridge.guard),
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<MyRatingsViewModel>.value(
              value: MyRatingsViewModel(ratings, service, auth),
            ),
            Provider<EmailPreference>.value(value: MemoryEmailPreference()),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/movies/550');
      await tester.pumpAndSettle();

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border).at(3));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pump(const Duration(milliseconds: 60)); // 응답(401)이 도착합니다.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(auth.status, AuthStatus.signedOut);
      expect(storage.token, isNull);
      expect(find.text('MovieLog에 로그인'), findsOneWidget);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
      expect(find.text('평점을 등록했습니다'), findsNothing);
    });
  });
}
