import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/screens/movie_detail_loader.dart';
import 'package:movielog/screens/movie_detail_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/movie_detail_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/rating_write_exception.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 목록에서 선택한 영화의 TMDB id를 평점 요청의 movieId로 그대로 쓰는지 확인할 때 씁니다.
final _movie = movieDto(550, title: '파이트 클럽');

class _Setup {
  _Setup({FakeRatingApiService? ratings}) : ratings = ratings ?? FakeRatingApiService();

  final FakeRatingApiService ratings;
  final movies = FakeTmdbMovieService();
  late final AuthViewModel auth;
  late final MyRatingsViewModel myRatings;

  Future<MovieDetailViewModel> create() async {
    auth = await signedInAuthViewModel();
    myRatings = MyRatingsViewModel(ratings, movies, auth);
    return MovieDetailViewModel(ratings, auth, myRatings, _movie);
  }
}

Future<Object?> _error(Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    return error;
  }
  return null;
}

void main() {
  group('MovieDetailViewModel', () {
    test('sends the TMDB id as movieId without any memberId and adds the response to the session list', () async {
      final s = _Setup();
      final viewModel = await s.create();
      final statuses = <SubmitStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.submitStatus));

      await viewModel.createRating(score: 4, comment: '좋아요');

      expect(statuses, [SubmitStatus.submitting, SubmitStatus.success]);
      final request = s.ratings.createdRequests.single;
      expect(request.movieId, 550);
      expect(request.score, 4);
      expect(request.comment, '좋아요');
      expect(request.toJson().containsKey('memberId'), isFalse);
      expect(viewModel.lastCreatedScore, 4);
      // 등록 응답으로 받은 Rating이 "내가 등록한 평점"에 영화 정보와 함께 들어갑니다.
      expect(s.myRatings.ratings.single.rating.movieId, 550);
      expect(s.myRatings.ratings.single.movie?.title, '파이트 클럽');
    });

    test('400 is inline; 409, 403, 404 are notices carrying the server message', () async {
      final cases = {
        400: ('COMMON400', '별점은 5점 이하여야 합니다.', RatingWriteKind.inline),
        404: ('MEMBER404_1', '해당 회원을 찾을 수 없습니다.', RatingWriteKind.notice),
        409: ('RATING409_1', '이미 이 영화에 평점을 남기셨습니다.', RatingWriteKind.notice),
      };
      for (final entry in cases.entries) {
        final s = _Setup(
          ratings: FakeRatingApiService()
            ..createFailure = commonFailure(entry.key, entry.value.$1, entry.value.$2),
        );
        final viewModel = await s.create();

        final error = await _error(() => viewModel.createRating(score: 5));

        expect(error, isA<RatingWriteException>().having((e) => e.kind, 'kind', entry.value.$3));
        expect((error! as RatingWriteException).message, entry.value.$2);
        expect(viewModel.submitStatus, SubmitStatus.error);
        expect(viewModel.lastCreatedScore, isNull);
        expect(s.myRatings.ratings, isEmpty);
        expect(s.auth.status, AuthStatus.signedIn); // 400/404/409로 로그아웃하지 않습니다.
      }
    });

    test('AUTH401_2/3/4 expire the session and dismiss the dialog', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        final s = _Setup(
          ratings: FakeRatingApiService()..createFailure = commonFailure(401, code, '로그인이 필요합니다.'),
        );
        final viewModel = await s.create();

        final error = await _error(() => viewModel.createRating(score: 5));

        expect(
          error,
          isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.dismissed),
          reason: code,
        );
        expect(s.auth.status, AuthStatus.signedOut, reason: code);
        expect(s.auth.sessionExpired, isTrue, reason: code);
      }
    });

    test('a network failure gets the generic inline message and keeps the session', () async {
      final s = _Setup(ratings: FakeRatingApiService()..createFailure = dioFailure('/x'));
      final viewModel = await s.create();

      final error = await _error(() => viewModel.createRating(score: 5));

      expect((error! as RatingWriteException).message, '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.');
      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(s.auth.status, AuthStatus.signedIn);
    });

    test('a second call while saving is ignored', () async {
      final s = _Setup(ratings: FakeRatingApiService(delay: const Duration(milliseconds: 20)));
      final viewModel = await s.create();

      final first = viewModel.createRating(score: 5);
      expect(viewModel.isSubmitting, isTrue);
      final second = viewModel.createRating(score: 5);
      await Future.wait([first, second]);

      expect(s.ratings.createdRequests, hasLength(1));
    });

    test('a response that arrives after logout is not added to the next session', () async {
      final s = _Setup(ratings: FakeRatingApiService(delay: const Duration(milliseconds: 20)));
      final viewModel = await s.create();

      final pending = viewModel.createRating(score: 5);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await s.auth.logout();
      final error = await _error(() => pending);

      expect(error, isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.dismissed));
      expect(s.myRatings.ratings, isEmpty);
      expect(viewModel.lastCreatedScore, isNull);
    });

    test('a result that arrives after dispose is ignored', () async {
      final s = _Setup(ratings: FakeRatingApiService(delay: const Duration(milliseconds: 20)));
      final viewModel = await s.create();

      final pending = viewModel.createRating(score: 5);
      viewModel.dispose();

      await expectLater(pending, completes);
    });
  });

  group('MovieDetail screens', () {
    Future<({FakeRatingApiService ratings, FakeTmdbMovieService movies, AuthViewModel auth, MyRatingsViewModel myRatings})>
    pumpDetail(
      WidgetTester tester, {
      bool withExtra = true,
      FakeRatingApiService? ratings,
      FakeTmdbMovieService? movies,
    }) async {
      _useMobileViewport(tester);
      final ratingService = ratings ?? FakeRatingApiService();
      final movieService = movies ?? FakeTmdbMovieService();
      final auth = (await tester.runAsync(signedInAuthViewModel))!;
      final myRatings = MyRatingsViewModel(ratingService, movieService, auth);
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
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: movieService),
            Provider<RatingApiService>.value(value: ratingService),
            ChangeNotifierProvider<AuthViewModel>.value(value: auth),
            ChangeNotifierProvider<MyRatingsViewModel>.value(value: myRatings),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return (ratings: ratingService, movies: movieService, auth: auth, myRatings: myRatings);
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

    testWidgets('the rate button is enabled for a signed in user (no sign up notice)', (tester) async {
      await pumpDetail(tester);

      final rateButton = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('평점 남기기'), matching: find.byType(ElevatedButton)),
      );
      expect(rateButton.onPressed, isNotNull);
      expect(find.textContaining('회원가입'), findsNothing);
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
      expect(fakes.myRatings.ratings.single.rating.score, 4);
    });

    testWidgets('a 409 closes the Dialog and shows the server message as a Snackbar, staying signed in', (
      tester,
    ) async {
      final ratings = FakeRatingApiService()
        ..createFailure = commonFailure(409, 'RATING409_1', '이미 이 영화에 평점을 남기셨습니다.');
      final fakes = await pumpDetail(tester, ratings: ratings);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border).at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('이미 이 영화에 평점을 남기셨습니다.'), findsOneWidget);
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);
      expect(fakes.auth.status, AuthStatus.signedIn);
    });

    testWidgets('a 400 keeps the Dialog open with the input and the server message', (tester) async {
      final ratings = FakeRatingApiService()
        ..createFailure = commonFailure(400, 'COMMON400', '후기는 500자 이하로 입력해주세요.');
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
      expect(find.text('후기는 500자 이하로 입력해주세요.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '지켜져야 하는 후기');

      // 취소하면 요청 없이 닫히고 성공 Snackbar도 없습니다.
      await tester.tap(find.widgetWithText(ElevatedButton, '취소'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);
    });

    testWidgets('a 401 closes the Dialog and expires the session without a rating message', (tester) async {
      final ratings = FakeRatingApiService()
        ..createFailure = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다. 다시 로그인해주세요.');
      final fakes = await pumpDetail(tester, ratings: ratings);

      await tester.tap(find.text('평점 남기기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_border).at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.textContaining('평점을 등록했습니다'), findsNothing);
      expect(fakes.auth.status, AuthStatus.signedOut);
      expect(fakes.auth.sessionExpired, isTrue);
    });

    testWidgets('the favorite toggle still works locally', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.text('즐겨찾기'));
      await tester.pump();

      expect(find.text('즐겨찾기에 추가했습니다.'), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsOneWidget);
    });

    testWidgets('does not close the Dialog or go back while saving', (tester) async {
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
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    await gate;
    return super.createRating(request);
  }
}
