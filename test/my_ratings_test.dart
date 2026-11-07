import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/services/member_check_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/widgets/rating_card.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

({FakeRatingApiService ratings, FakeTmdbMovieService movies}) _fakes() {
  final movies = FakeTmdbMovieService()
    ..movieDetails[550] = movieDto(550, title: '파이트 클럽')
    ..movieDetails[680] = movieDto(680, title: '펄프 픽션');
  final ratings = FakeRatingApiService(
    ratings: [
      ratingDto(1, movieId: 550, score: 5, comment: '최고의 영화!'),
      ratingDto(2, movieId: 680, score: 4, comment: '다시 봐도 좋다'),
      ratingDto(3, movieId: 13, score: 3, comment: null),
    ],
  );
  return (ratings: ratings, movies: movies);
}

void main() {
  group('MyRatingsViewModel', () {
    test('queries the fixed sample member and ends in Success with movies joined', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, sampleMemberId);
      final statuses = <MyRatingsLoadStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.status));

      await viewModel.load();

      expect(sampleMemberId, 1);
      expect(fakes.ratings.requestedMemberIds, [1]);
      expect(statuses, [MyRatingsLoadStatus.loading, MyRatingsLoadStatus.success]);
      expect(viewModel.ratings.map((e) => e.movie?.title), ['파이트 클럽', '펄프 픽션', null]);
      expect(viewModel.ratings.last.rating.movieId, 13);
      expect(viewModel.message, missingMovieMessage);
    });

    test('an empty array is Empty, never Error', () async {
      final fakes = _fakes()..ratings.ratings = [];
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 3);

      await viewModel.load();

      expect(viewModel.status, MyRatingsLoadStatus.empty);
      expect(viewModel.message, isNull);
    });

    test('404 and 400 are Error with their own messages', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 999999);

      fakes.ratings.failure = dioFailure('/v5/members/999999/ratings', statusCode: 404);
      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.message, '존재하지 않는 회원입니다.');

      fakes.ratings.failure = dioFailure('/v5/members/abc/ratings', statusCode: 400);
      await viewModel.load();
      expect(viewModel.message, contains('형식'));
    });

    test('a network failure is Error and retry recovers', () async {
      final fakes = _fakes()..ratings.failure = dioFailure('/x');
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 1);

      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.message, ratingsLoadFailedMessage);

      fakes.ratings.failure = null;
      await viewModel.retry();
      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.message, anyOf(isNull, missingMovieMessage));
    });

    test('a TMDB 404 keeps the rating and shows a placeholder entry', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 1);

      await viewModel.load();

      expect(viewModel.ratings, hasLength(3));
      expect(viewModel.ratings[2].movie, isNull);
      expect(viewModel.status, MyRatingsLoadStatus.success);
    });

    test('a TMDB network failure keeps every rating and is not cached', () async {
      final fakes = _fakes();
      fakes.movies.failingDetailIds.add(550);
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 1);

      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings, hasLength(3));
      expect(viewModel.ratings.first.movie, isNull);

      fakes.movies.failingDetailIds.clear();
      await viewModel.load();
      expect(viewModel.ratings.first.movie?.title, '파이트 클럽');
    });

    test('the same movieId is fetched once and cached across loads', () async {
      final fakes = _fakes();
      fakes.ratings.ratings = [
        ratingDto(1, movieId: 550),
        ratingDto(2, movieId: 550, score: 2),
        ratingDto(3, movieId: 680),
      ];
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 1);

      await viewModel.load();
      expect(fakes.movies.detailCalls.toSet(), {550, 680});
      expect(fakes.movies.detailCalls, hasLength(2));

      await viewModel.load();
      expect(fakes.movies.detailCalls, hasLength(2));
    });

    test('a response that arrives after a newer request is ignored', () async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 30);
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 1);

      final first = viewModel.load();
      fakes.ratings.ratings = [ratingDto(9, movieId: 550)];
      final second = viewModel.load();
      await Future.wait([first, second]);

      expect(viewModel.ratings, hasLength(1));
      expect(viewModel.ratings.single.rating.ratingId, 9);
    });

    test('does not notify after dispose', () async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 20);
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 1);

      final pending = viewModel.load();
      viewModel.dispose();

      await expectLater(pending, completes);
    });
  });

  group('MyRatingsScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required FakeRatingApiService ratings,
      required FakeTmdbMovieService movies,
      int memberId = 1,
    }) async {
      _useMobileViewport(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MyRatingsViewModel(ratings, movies, memberId)..load(),
          child: MaterialApp(theme: AppTheme.light, home: const MyRatingsScreen()),
        ),
      );
    }

    testWidgets('Loading then Success cards with score, comment, date and movie info', (
      tester,
    ) async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 50);
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);

      expect(find.text('평점을 불러오는 중이에요...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('내가 등록한 평점'), findsOneWidget);
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('별점 5 / 5'), findsOneWidget);
      expect(find.text('최고의 영화!'), findsOneWidget);
      expect(find.text(formatRatingDate(DateTime.utc(2026, 10, 31, 3))), findsWidgets);
      // TMDB에서 못 찾은 영화(13)는 제목 대신 id를, 포스터 대신 안내 문구를 보여줍니다.
      expect(find.text('영화 #13'), findsOneWidget);
      expect(find.text('포스터 정보 없음'), findsOneWidget);
      expect(find.text(missingMovieMessage), findsOneWidget);
    });

    testWidgets('a null comment is not rendered', (tester) async {
      final fakes = _fakes();
      fakes.ratings.ratings = [ratingDto(1, movieId: 550, comment: null)];
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      expect(find.text('null'), findsNothing);
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('포스터 정보 없음'), findsNothing);
    });

    testWidgets('Empty shows its own message and no retry button', (tester) async {
      final fakes = _fakes()..ratings.ratings = [];
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies, memberId: 3);
      await tester.pumpAndSettle();

      expect(find.text('등록된 평점이 없습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('Error shows a friendly message, never a raw exception, and retries', (
      tester,
    ) async {
      final fakes = _fakes()..ratings.failure = dioFailure('/x');
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      expect(find.text(ratingsLoadFailedMessage), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);

      fakes.ratings.failure = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(fakes.ratings.requestedMemberIds, [1, 1]);
    });

    testWidgets('404 shows the not-found member message', (tester) async {
      final fakes = _fakes()
        ..ratings.failure = dioFailure('/x', statusCode: 404);
      await pumpScreen(
        tester,
        ratings: fakes.ratings,
        movies: fakes.movies,
        memberId: 999999,
      );
      await tester.pumpAndSettle();

      expect(find.text('존재하지 않는 회원입니다.'), findsOneWidget);
    });
  });

  group('MyPage → 내가 등록한 평점 routing', () {
    testWidgets('opens a child screen without the bottom bar and returns on back', (
      tester,
    ) async {
      _useMobileViewport(tester);
      final fakes = _fakes();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: fakes.movies),
            Provider<RatingApiService>.value(value: fakes.ratings),
            Provider<MemberCheckService>.value(value: FakeMemberCheckService()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: AppRouter.router,
          ),
        ),
      );
      AppRouter.router.go('/my');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('내가 등록한 평점'), findsOneWidget);

      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();

      expect(find.byType(MyRatingsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(fakes.ratings.requestedMemberIds, [1]);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.byType(MyRatingsScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  test('DioException import keeps the fake helpers honest', () {
    expect(dioFailure('/x', statusCode: 404).response?.statusCode, 404);
    expect(dioFailure('/x').type, DioExceptionType.connectionError);
  });
}
