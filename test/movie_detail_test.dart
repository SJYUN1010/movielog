import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/screens/movie_detail_loader.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 목록에서 선택한 영화의 TMDB id를 평점 요청의 movieId로 그대로 쓰는지 확인할 때 씁니다.
final _movie = movieDto(550, title: '파이트 클럽');

void main() {
  group('MovieDetailViewModel', () {
    test('sends the TMDB id as movieId with the score and comment', () async {
      final ratings = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(ratings, 12, _movie);
      final statuses = <SubmitStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.submitStatus));

      await viewModel.createRating(score: 4, comment: '좋아요');

      expect(statuses, [SubmitStatus.submitting, SubmitStatus.success]);
      expect(ratings.createdRequests.single.movieId, 550);
      expect(ratings.createdRequests.single.score, 4);
      expect(ratings.createdRequests.single.comment, '좋아요');
      expect(viewModel.lastCreatedScore, 4);
    });

    test('without a signed-up member it asks for sign up and sends nothing', () async {
      final ratings = FakeRatingApiService();
      final viewModel = MovieDetailViewModel(ratings, null, _movie);

      expect(viewModel.canRate, isFalse);
      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, signUpRequiredMessage);
      expect(ratings.createdRequests, isEmpty);
    });

    test('shows the server message for 400, 404 and 409', () async {
      final cases = {
        400: ('COMMON400', '별점은 5점 이하여야 합니다.'),
        404: ('COMMON404', '존재하지 않는 유저입니다.'),
        409: ('COMMON409', '이미 이 영화에 평점을 남기셨습니다.'),
      };
      for (final entry in cases.entries) {
        final ratings = FakeRatingApiService()
          ..createFailure = commonFailure(entry.key, entry.value.$1, entry.value.$2);
        final viewModel = MovieDetailViewModel(ratings, 12, _movie);

        await viewModel.createRating(score: 5);

        expect(viewModel.submitStatus, SubmitStatus.error);
        expect(viewModel.submitMessage, entry.value.$2);
        expect(viewModel.lastCreatedScore, isNull);
      }
    });

    test('a network failure gets the generic message', () async {
      final ratings = FakeRatingApiService()..createFailure = dioFailure('/x');
      final viewModel = MovieDetailViewModel(ratings, 12, _movie);

      await viewModel.createRating(score: 5);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.submitMessage, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
    });

    test('a second call while saving is ignored', () async {
      final ratings = FakeRatingApiService(delay: const Duration(milliseconds: 20));
      final viewModel = MovieDetailViewModel(ratings, 12, _movie);

      final first = viewModel.createRating(score: 5);
      expect(viewModel.isSubmitting, isTrue);
      final second = viewModel.createRating(score: 5);
      await Future.wait([first, second]);

      expect(ratings.createdRequests, hasLength(1));
    });

    test('a result that arrives after dispose is ignored', () async {
      final ratings = FakeRatingApiService(delay: const Duration(milliseconds: 20));
      final viewModel = MovieDetailViewModel(ratings, 12, _movie);

      final pending = viewModel.createRating(score: 5);
      viewModel.dispose();

      await expectLater(pending, completes);
    });
  });

  group('MovieDetail screens', () {
    Future<
      ({FakeRatingApiService ratings, FakeTmdbMovieService movies, LearningMemberSession session})
    >
    pumpDetail(
      WidgetTester tester, {
      int? memberId = 12,
      bool withExtra = true,
      FakeRatingApiService? ratings,
      FakeTmdbMovieService? movies,
    }) async {
      _useMobileViewport(tester);
      final ratingService = ratings ?? FakeRatingApiService();
      final movieService = movies ?? FakeTmdbMovieService();
      final session = LearningMemberSession(memberId: memberId);
      final router = GoRouter(
        initialLocation: '/movies/550',
        routes: [
          GoRoute(
            path: '/movies/:movieId',
            builder: (context, state) => MovieDetailLoader(
              movieId: int.parse(state.pathParameters['movieId']!),
              initialMovie: withExtra ? _movie : null,
            ),
          ),
          GoRoute(path: '/signup', builder: (context, state) => const Scaffold(body: Text('가입 화면'))),
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: movieService),
            Provider<RatingApiService>.value(value: ratingService),
            ChangeNotifierProvider<LearningMemberSession>.value(value: session),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return (ratings: ratingService, movies: movieService, session: session);
    }

    testWidgets('uses the movie from extra without asking TMDB again', (tester) async {
      final fakes = await pumpDetail(tester);

      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(fakes.movies.detailCalls, isEmpty);
    });

    testWidgets('without extra (direct access) it loads the movie from TMDB by id', (tester) async {
      final movies = FakeTmdbMovieService()..movieDetails[550] = _movie;
      final fakes = await pumpDetail(tester, withExtra: false, movies: movies);

      expect(fakes.movies.detailCalls, [550]);
      expect(find.text('파이트 클럽'), findsOneWidget);
    });

    testWidgets('a movie TMDB does not have shows a not-found message', (tester) async {
      await pumpDetail(tester, withExtra: false);

      expect(find.text('영화를 찾을 수 없어요.'), findsOneWidget);
    });

    testWidgets('a TMDB network failure offers a retry', (tester) async {
      final movies = FakeTmdbMovieService()
        ..movieDetails[550] = _movie
        ..failingDetailIds.add(550);
      await pumpDetail(tester, withExtra: false, movies: movies);
      expect(find.text('영화를 불러오지 못했습니다.'), findsOneWidget);

      movies.failingDetailIds.clear();
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('파이트 클럽'), findsOneWidget);
    });

    testWidgets('without a member the rate button is disabled and sign up is suggested', (tester) async {
      await pumpDetail(tester, memberId: null);

      final rateButton = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('평점 남기기'), matching: find.byType(ElevatedButton)),
      );
      expect(rateButton.onPressed, isNull);
      expect(find.text('평점을 남기려면 학습용 회원가입이 필요합니다.'), findsOneWidget);

      await tester.ensureVisible(find.text('회원가입하기'));
      await tester.tap(find.text('회원가입하기'));
      await tester.pumpAndSettle();
      expect(find.text('가입 화면'), findsOneWidget);
    });

    testWidgets('registering a rating shows the success Snackbar and sends the TMDB id', (tester) async {
      final fakes = await pumpDetail(tester);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_border).at(3));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '인상적인 반전');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(fakes.ratings.createdRequests.single.movieId, 550);
      expect(fakes.ratings.createdRequests.single.score, 4);
      expect(fakes.ratings.createdRequests.single.comment, '인상적인 반전');
      expect(
        find.text('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.'),
        findsOneWidget,
      );
      expect(find.text('내 평점 4'), findsOneWidget);
    });

    testWidgets('a 409 keeps the Dialog open with the input and the server message, no success Snackbar', (
      tester,
    ) async {
      final ratings = FakeRatingApiService()
        ..createFailure = commonFailure(409, 'COMMON409', '이미 이 영화에 평점을 남기셨습니다.');
      await pumpDetail(tester, ratings: ratings);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border).at(1));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '지켜져야 하는 후기');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '지켜져야 하는 후기');
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);

      // 취소하면 요청 없이 닫히고 성공 Snackbar도 없습니다.
      await tester.tap(find.widgetWithText(ElevatedButton, '취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);
    });

    testWidgets('the favorite toggle still works locally', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.text('즐겨찾기'));
      await tester.pump();

      expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
    });

    testWidgets('does not show a stale Snackbar after the screen is left while saving', (tester) async {
      final completer = Completer<void>();
      final ratings = _SlowRatings(completer.future);
      await pumpDetail(tester, ratings: ratings);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border).at(2));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pump();

      // 저장 중에는 뒤로가기가 막혀 Dialog가 그대로 남습니다.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RatingDialog), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
    });
  });
}

/// 응답을 [gate]가 끝날 때까지 붙잡아 두는 평점 서비스입니다.
class _SlowRatings extends FakeRatingApiService {
  _SlowRatings(this.gate);

  final Future<void> gate;

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    await gate;
    return super.createRating(memberId: memberId, request: request);
  }
}
