import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/favorites_screen.dart';
import 'package:movielog/screens/movie_search_screen.dart';
import 'package:movielog/screens/profile_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/paged_movies_view_model.dart';
import 'package:movielog/widgets/movie_list_tile.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

const _email = 'movie@example.com';

FakeTmdbMovieService _tmdb(Iterable<int> ids) {
  final tmdb = FakeTmdbMovieService();
  for (final id in ids) {
    tmdb.movieDetails[id] = movieDto(id, title: '영화 $id');
  }
  return tmdb;
}

void main() {
  group('FavoritesScreen', () {
    Future<
      ({
        FakeFavoriteApiService api,
        FakeTmdbMovieService tmdb,
        SessionGuard guard,
        List<TmdbMovieDto> opened,
      })
    >
    pump(
      WidgetTester tester, {
      required FakeFavoriteApiService api,
      required FakeTmdbMovieService tmdb,
      Future<void> Function(TmdbMovieDto movie)? onOpen,
    }) async {
      _useMobileViewport(tester);
      final guard = SessionGuard()..startSession(_email);
      final opened = <TmdbMovieDto>[];
      final router = GoRouter(
        initialLocation: '/fav',
        routes: [
          GoRoute(
            path: '/fav',
            builder: (context, state) => ChangeNotifierProvider<FavoritesViewModel>(
              create: (context) => FavoritesViewModel(
                favoriteApi: api,
                tmdbApi: tmdb,
                sessionGuard: guard,
                accountId: _email,
              ),
              child: FavoritesScreen(
                onOpenMovie: (movie) async {
                  opened.add(movie);
                  await (onOpen ?? (m) async => context.push('/detail/${m.id}'))(movie);
                },
              ),
            ),
          ),
          GoRoute(
            path: '/detail/:id',
            builder: (context, state) => Scaffold(
              appBar: AppBar(leading: const BackButton()),
              body: Center(child: Text('상세 ${state.pathParameters['id']}')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(theme: AppTheme.light, routerConfig: router));
      return (api: api, tmdb: tmdb, guard: guard, opened: opened);
    }

    testWidgets('shows Loading, then a card per favorite with the TMDB title and a back arrow, no bottom bar', (
      tester,
    ) async {
      final api = FakeFavoriteApiService(movieIds: [550, 680])..delay = const Duration(milliseconds: 50);
      await pump(tester, api: api, tmdb: _tmdb([550, 680]));

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('내 즐겨찾기'), findsOneWidget);
      expect(find.byType(MovieListTile), findsNWidgets(2));
      expect(find.text('영화 550'), findsOneWidget);
      expect(find.text('영화 680'), findsOneWidget);
      expect(find.text('즐겨찾기한 영화'), findsNWidgets(2));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byTooltip('뒤로가기'), findsOneWidget);
    });

    testWidgets('an empty list is its own screen, not an error', (tester) async {
      await pump(tester, api: FakeFavoriteApiService(), tmdb: _tmdb([]));
      await tester.pumpAndSettle();

      expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
      expect(find.text('영화 상세에서 북마크를 눌러보세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('a load failure shows its own message and the retry button works', (tester) async {
      final api = FakeFavoriteApiService(movieIds: [550])..listError = dioFailure('/v8/favorites');
      await pump(tester, api: api, tmdb: _tmdb([550]));
      await tester.pumpAndSettle();

      expect(find.text(favoritesLoadFailedMessage), findsOneWidget);
      expect(find.byType(MovieListTile), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.byType(MovieListTile), findsOneWidget);
    });

    testWidgets('one TMDB failure shows only that card as a placeholder; "정보 다시 불러오기" reloads just it', (
      tester,
    ) async {
      final api = FakeFavoriteApiService(movieIds: [550, 680]);
      final tmdb = _tmdb([550, 680])..failingDetailIds.add(680);
      await pump(tester, api: api, tmdb: tmdb);
      await tester.pumpAndSettle();

      expect(find.byType(MovieListTile), findsNWidgets(2));
      expect(find.text('영화 550'), findsOneWidget);
      expect(find.text('영화 #680'), findsOneWidget);
      expect(find.text('영화 정보를 불러오지 못했습니다.'), findsOneWidget);
      final listCalls = api.listCalls;

      tmdb.failingDetailIds.clear();
      await tester.tap(find.text('정보 다시 불러오기'));
      await tester.pumpAndSettle();

      expect(find.text('영화 680'), findsOneWidget);
      expect(find.text('정보 다시 불러오기'), findsNothing);
      expect(api.listCalls, listCalls); // 목록 전체를 다시 조회하지 않음
    });

    testWidgets('unfavoriting in the detail and going back removes the movie from the list', (tester) async {
      final api = FakeFavoriteApiService(movieIds: [550, 680]);
      await pump(
        tester,
        api: api,
        tmdb: _tmdb([550, 680]),
        onOpen: (movie) async {
          api.favorites.remove(movie.id); // 상세에서 해제함
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('영화 680'));
      await tester.pump(); // 돌아오자마자의 첫 frame
      await tester.pump();

      // 전체 화면 로딩으로 깜빡이지 않고 그 자리에서 갱신됩니다.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('영화 680'), findsNothing);
      expect(find.text('영화 550'), findsOneWidget);
    });

    testWidgets('opening a card goes to the detail and back returns to the refreshed list', (tester) async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final fakes = await pump(tester, api: api, tmdb: _tmdb([550]));
      await tester.pumpAndSettle();
      final before = api.listCalls;

      await tester.tap(find.text('영화 550'));
      await tester.pumpAndSettle();
      expect(find.text('상세 550'), findsOneWidget);
      expect(fakes.opened.single.id, 550);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('영화 550'), findsOneWidget);
      expect(api.listCalls, before + 1); // 돌아오면 다시 조회
    });

    testWidgets('after the account changes, the new view model never shows the old account\'s list', (tester) async {
      _useMobileViewport(tester);
      final api = FakeFavoriteApiService(movieIds: [550]);
      final tmdb = _tmdb([550]);
      final guard = SessionGuard()..startSession('a@example.com');
      final account = ValueNotifier<String>('a@example.com');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ValueListenableBuilder<String>(
            valueListenable: account,
            builder: (context, email, _) => ChangeNotifierProvider<FavoritesViewModel>(
              // 라우터와 같은 규칙: 계정(이메일)과 세션 번호가 바뀌면 새 ViewModel
              key: ValueKey('$email:${guard.generation}'),
              create: (_) => FavoritesViewModel(
                favoriteApi: email == 'a@example.com' ? api : FakeFavoriteApiService(),
                tmdbApi: tmdb,
                sessionGuard: guard,
                accountId: email,
              ),
              child: FavoritesScreen(onOpenMovie: (movie) async {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('영화 550'), findsOneWidget);

      guard
        ..invalidate()
        ..startSession('b@example.com');
      account.value = 'b@example.com';
      await tester.pump();

      expect(find.text('영화 550'), findsNothing); // 전환 직후에도 이전 목록이 남지 않음
      await tester.pumpAndSettle();
      expect(find.text('아직 즐겨찾기한 영화가 없습니다.'), findsOneWidget);
    });

    testWidgets('a favorites response that arrives after logout is never painted', (tester) async {
      final api = FakeFavoriteApiService(movieIds: [550])..delay = const Duration(milliseconds: 100);
      final fakes = await pump(tester, api: api, tmdb: _tmdb([550]));
      await tester.pump(const Duration(milliseconds: 20));

      fakes.guard.invalidate(); // 로그아웃
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(MovieListTile), findsNothing);
    });
  });

  group('MovieSearchScreen', () {
    Future<({FakeTmdbMovieService tmdb, List<TmdbMovieDto> opened})> pump(
      WidgetTester tester, {
      FakeTmdbMovieService? tmdb,
      Duration debounce = const Duration(milliseconds: 500),
    }) async {
      _useMobileViewport(tester);
      final service = tmdb ?? FakeTmdbMovieService(pageSize: 20);
      final opened = <TmdbMovieDto>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChangeNotifierProvider<PagedMoviesViewModel>(
            create: (_) => PagedMoviesViewModel(tmdbApi: service),
            child: MovieSearchScreen(
              debounce: debounce,
              onOpenMovie: (movie) async => opened.add(movie),
            ),
          ),
        ),
      );
      return (tmdb: service, opened: opened);
    }

    testWidgets('starts idle without any request and says to enter a query', (tester) async {
      final fakes = await pump(tester);

      expect(find.text('검색어를 입력해 주세요.'), findsOneWidget);
      expect(fakes.tmdb.searchCalls, isEmpty);
      expect(fakes.tmdb.discoverCalls, isEmpty);
    });

    testWidgets('submitting searches immediately from page 1 and shows result cards', (tester) async {
      final fakes = await pump(tester);

      await tester.enterText(find.byType(TextField), '별빛');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(fakes.tmdb.searchCalls.last, (page: 1, query: '별빛'));
      expect(find.byType(MovieListTile), findsWidgets);
      expect(find.text('별빛 1'), findsOneWidget);
    });

    testWidgets('a blank query is never sent; the field shows a message', (tester) async {
      final fakes = await pump(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('검색'));
      await tester.pump();

      expect(find.text('검색어를 입력해 주세요.'), findsNWidgets(2)); // 입력 안내 + 필드 오류
      expect(fakes.tmdb.searchCalls, isEmpty);
    });

    testWidgets('Challenge A: typing sends ONE request after the input pauses for 500ms (debounce)', (tester) async {
      final fakes = await pump(tester);

      await tester.enterText(find.byType(TextField), 'b');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ba');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'bat');
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakes.tmdb.searchCalls, isEmpty); // 아직 500ms가 지나지 않음

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(fakes.tmdb.searchCalls.map((c) => c.query), ['bat']); // 마지막 검색어만, 한 번
    });

    testWidgets('Challenge A: submitting right away cancels the pending debounce (no duplicate request)', (tester) async {
      final fakes = await pump(tester);

      await tester.enterText(find.byType(TextField), 'batman');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(fakes.tmdb.searchCalls.map((c) => c.query), ['batman']);
    });

    testWidgets('Challenge A: the pending timer is cancelled when the screen is left', (tester) async {
      final fakes = await pump(tester);

      await tester.enterText(find.byType(TextField), 'batman');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('다른 화면')))); // 화면 이탈
      await tester.pump(const Duration(seconds: 1));

      expect(fakes.tmdb.searchCalls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Challenge A: clearing the box or re-typing the same query does not search again', (tester) async {
      final fakes = await pump(tester);
      await tester.enterText(find.byType(TextField), 'batman');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(fakes.tmdb.searchCalls, hasLength(1));

      await tester.enterText(find.byType(TextField), 'batman');
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 700));

      expect(fakes.tmdb.searchCalls, hasLength(1));
    });

    testWidgets('a new query clears the old results and the slow old response never mixes in', (tester) async {
      final tmdb = FakeTmdbMovieService(pageSize: 20);
      tmdb.conditionDelays['query:느림'] = const Duration(milliseconds: 600);
      final fakes = await pump(tester, tmdb: tmdb, debounce: const Duration(milliseconds: 50));

      await tester.enterText(find.byType(TextField), '느림');
      await tester.pump(const Duration(milliseconds: 100)); // 느린 요청 시작
      await tester.enterText(find.byType(TextField), '빠름');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 800)); // 느린 응답이 이제 도착
      await tester.pumpAndSettle();

      expect(find.text('빠름 1'), findsOneWidget);
      expect(find.text('느림 1'), findsNothing);
      expect(fakes.tmdb.searchCalls.map((c) => c.query), ['느림', '빠름']);
    });

    testWidgets('empty result and error are different screens; retry searches again', (tester) async {
      final tmdb = FakeTmdbMovieService()..emptySearch = true;
      await pump(tester, tmdb: tmdb);

      await tester.enterText(find.byType(TextField), '없는영화');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('검색 결과가 없습니다.'), findsOneWidget);

      tmdb
        ..emptySearch = false
        ..failSearch = true;
      await tester.enterText(find.byType(TextField), '별빛');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text(movieSearchFailedMessage), findsOneWidget);
      expect(find.text('검색 결과가 없습니다.'), findsNothing);

      tmdb.failSearch = false;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieListTile), findsWidgets);
    });

    testWidgets('"검색 결과 더 보기" appends the next page; a failure retries the same page', (tester) async {
      final tmdb = FakeTmdbMovieService(pageSize: 4);
      final fakes = await pump(tester, tmdb: tmdb);
      await tester.enterText(find.byType(TextField), '별빛');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      tmdb.failingPages.add(2);
      await tester.ensureVisible(find.text('검색 결과 더 보기'));
      await tester.tap(find.text('검색 결과 더 보기'));
      await tester.pumpAndSettle();
      expect(find.text(loadMoreFailedMessage), findsOneWidget);

      tmdb.failingPages.clear();
      await tester.ensureVisible(find.text('다음 페이지 다시 시도'));
      await tester.tap(find.text('다음 페이지 다시 시도'));
      await tester.pumpAndSettle();

      expect(fakes.tmdb.searchCalls.map((c) => c.page), [1, 2, 2]);
      expect(find.text('별빛 5'), findsOneWidget);
    });

    testWidgets('tapping a result opens that movie by TMDB id', (tester) async {
      final fakes = await pump(tester);
      await tester.enterText(find.byType(TextField), '별빛');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('별빛 2'));
      await tester.pump();

      expect(fakes.opened.single.id, 1001);
    });

    testWidgets('has a back arrow and no bottom navigation bar', (tester) async {
      await pump(tester);

      expect(find.byTooltip('뒤로가기'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('memberGate', () {
    Future<Widget?> gate(
      WidgetTester tester,
      AuthViewModel auth,
      SessionGuard guard,
    ) async {
      Widget? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = memberGate(context, auth, guard, title: '내 즐겨찾기');
              return result ?? const Text('열림');
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('shows a spinner until the member is loaded, then opens', (tester) async {
      final auth = (await tester.runAsync(signedInAuthViewModel))!;
      final guard = SessionGuard();

      expect(await gate(tester, auth, guard), isNotNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.runAsync(auth.loadMember);
      // member는 있지만 세션이 아직 이 계정으로 시작되지 않았으면 계속 기다립니다.
      expect(await gate(tester, auth, guard), isNotNull);

      guard.startSession(auth.member!.email);
      expect(await gate(tester, auth, guard), isNull);
      expect(find.text('열림'), findsOneWidget);
    });

    testWidgets('when loading the member failed it offers "내 정보 다시 조회" instead of an endless spinner', (
      tester,
    ) async {
      final members = FakeMemberApiService()
        ..meError = dioFailure('/v8/members/me')
        ..failMeTimes = 1;
      final auth = (await tester.runAsync(() => signedInAuthViewModel(members: members)))!;
      await tester.runAsync(auth.loadMember);

      await gate(tester, auth, SessionGuard());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('내 정보 다시 조회'), findsOneWidget);

      await tester.tap(find.text('내 정보 다시 조회'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(members.fetchCount, 2);
    });
  });

  testWidgets('the my page has a 내 즐겨찾기 row under 내가 등록한 평점 that opens /my/favorites', (tester) async {
    _useMobileViewport(tester);
    final auth = (await tester.runAsync(signedInAuthViewModel))!;
    await tester.runAsync(auth.loadMember);
    final router = GoRouter(
      initialLocation: '/my',
      routes: [
        GoRoute(
          path: '/my',
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'favorites',
              builder: (context, state) => const Scaffold(body: Text('즐겨찾기 화면')),
            ),
            GoRoute(
              path: 'ratings',
              builder: (context, state) => const Scaffold(body: Text('평점 화면')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );

    final ratingsRow = tester.getTopLeft(find.text('내가 등록한 평점'));
    final favoritesRow = tester.getTopLeft(find.text('내 즐겨찾기'));
    expect(favoritesRow.dy, greaterThan(ratingsRow.dy));

    await tester.tap(find.text('내 즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기 화면'), findsOneWidget);
  });
}
