import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
import 'package:movielog/view_models/rating_write_exception.dart';
import 'package:movielog/widgets/loading_overlay.dart';
import 'package:movielog/widgets/rating_card.dart';
import 'package:movielog/widgets/rating_delete_dialog.dart';
import 'package:movielog/widgets/rating_dialog.dart';

import 'support/fakes.dart';

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 로그인한 세션에서 평점 3개를 등록해 둔 상태입니다(movieId 13은 TMDB에 없는 영화).
class _Setup {
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
  final members = FakeMemberApiService();
  final storage = MemoryTokenStorage();
  late final AuthViewModel auth = AuthViewModel(FakeAuthApiService(), members, storage);
  late final MyRatingsViewModel viewModel = MyRatingsViewModel(ratings, movies, auth);

  Future<void> start({bool seed = true}) async {
    await auth.login('movie@example.com', 'Umc1234!');
    if (!seed) return;
    for (final rating in ratings.ratings.reversed) {
      viewModel.addCreated(rating, movie: movies.movieDetails[rating.movieId]);
    }
    await pumpEventQueue();
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
  group('MyRatingsViewModel (session ratings)', () {
    test('addCreated puts the newest first and joins the movie from the cache without TMDB', () async {
      final s = _Setup();
      await s.start(seed: false);

      s.viewModel.addCreated(ratingDto(10, movieId: 550), movie: movieDto(550, title: '파이트 클럽'));
      s.viewModel.addCreated(ratingDto(11, movieId: 680), movie: movieDto(680, title: '펄프 픽션'));
      await pumpEventQueue();

      expect(s.viewModel.ratings.map((e) => e.rating.ratingId), [11, 10]);
      expect(s.viewModel.ratings.map((e) => e.movie?.title), ['펄프 픽션', '파이트 클럽']);
      expect(s.movies.detailCalls, isEmpty);
      expect(s.viewModel.message, isNull);
    });

    test('a movie that is not in the cache is fetched once; TMDB 404 keeps the rating as a placeholder', () async {
      final s = _Setup();
      await s.start();

      expect(s.movies.detailCalls.toSet(), {13}); // 550·680은 등록할 때 받은 DTO를 썼습니다.
      expect(s.viewModel.ratings.last.rating.movieId, 13);
      expect(s.viewModel.ratings.last.movie, isNull);
      expect(s.viewModel.message, missingMovieMessage);
    });

    test('a TMDB network failure keeps every rating and is not cached', () async {
      final s = _Setup();
      s.movies.failingDetailIds.add(13);
      await s.start();

      expect(s.viewModel.ratings, hasLength(3));
      expect(s.viewModel.ratings.last.movie, isNull);

      s.movies.failingDetailIds.clear();
      s.movies.movieDetails[13] = movieDto(13, title: '포레스트 검프');
      s.viewModel.addCreated(ratingDto(20, movieId: 13)); // 다음 등록 때 다시 시도합니다.
      await pumpEventQueue();
      expect(s.viewModel.ratings.first.movie?.title, '포레스트 검프');
    });

    test('update sends score and comment and replaces the card with the response, without a GET', () async {
      final s = _Setup();
      await s.start();

      await s.viewModel.updateRating(ratingId: 1, score: 3, comment: '수정 후기');

      expect(s.ratings.updates.single, (ratingId: 1, score: 3, comment: '수정 후기'));
      final card = s.viewModel.ratings.firstWhere((e) => e.rating.ratingId == 1);
      expect(card.rating.score, 3);
      expect(card.rating.comment, '수정 후기');
      expect(card.movie?.title, '파이트 클럽'); // 영화 정보는 그대로 붙어 있습니다.
    });

    test('clearing the comment sends null explicitly', () async {
      final s = _Setup();
      await s.start();

      await s.viewModel.updateRating(ratingId: 1, score: 5);

      expect(s.ratings.updates.single.comment, isNull);
      expect(s.viewModel.ratings.firstWhere((e) => e.rating.ratingId == 1).rating.comment, isNull);
    });

    test('delete removes the card and the last one leaves the list empty', () async {
      final s = _Setup();
      await s.start();

      for (final id in [1, 2, 3]) {
        await s.viewModel.deleteRating(id);
      }

      expect(s.ratings.deletedIds, [1, 2, 3]);
      expect(s.viewModel.isEmpty, isTrue);
    });

    test('a second write while one is running is ignored', () async {
      final s = _Setup();
      s.ratings.delay = const Duration(milliseconds: 20);
      await s.start();

      final first = s.viewModel.deleteRating(1);
      await s.viewModel.deleteRating(2);
      await first;

      expect(s.ratings.deletedIds, [1]);
    });
  });

  group('MyRatingsViewModel (errors)', () {
    test('COMMON400 is an inline error and the list is kept', () async {
      final s = _Setup();
      await s.start();
      s.ratings.updateFailure = commonFailure(400, 'COMMON400', '별점은 5점 이하여야 합니다.');

      final error = await _error(() => s.viewModel.updateRating(ratingId: 1, score: 5));

      expect(error, isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.inline));
      expect((error! as RatingWriteException).message, '별점은 5점 이하여야 합니다.');
      expect(s.viewModel.ratings, hasLength(3));
      expect(s.auth.status, AuthStatus.signedIn);
    });

    test('RATING403_1 is a notice and never signs out', () async {
      final s = _Setup();
      await s.start();
      s.ratings.updateFailure = commonFailure(403, 'RATING403_1', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');

      final error = await _error(() => s.viewModel.updateRating(ratingId: 1, score: 5));

      expect(error, isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.notice));
      expect((error! as RatingWriteException).code, 'RATING403_1');
      expect(s.auth.status, AuthStatus.signedIn);
      expect(s.storage.token, isNotNull);
      expect(s.viewModel.ratings, hasLength(3));
    });

    test('RATING404_1 is a notice and the missing rating disappears from the list', () async {
      final s = _Setup();
      await s.start();
      s.ratings.deleteFailure = commonFailure(404, 'RATING404_1', '해당 평점을 찾을 수 없습니다.');

      final error = await _error(() => s.viewModel.deleteRating(2));

      expect(error, isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.notice));
      expect(s.viewModel.ratings.map((e) => e.rating.ratingId), [1, 3]);
      expect(s.auth.status, AuthStatus.signedIn);
    });

    test('AUTH401_2/3/4 expire the session once and dismiss the dialog', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        final s = _Setup();
        await s.start();
        s.ratings.updateFailure = commonFailure(401, code, '로그인이 필요합니다.');

        final error = await _error(() => s.viewModel.updateRating(ratingId: 1, score: 5));

        expect(
          error,
          isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.dismissed),
          reason: code,
        );
        expect(s.auth.status, AuthStatus.signedOut, reason: code);
        expect(s.auth.sessionExpired, isTrue, reason: code);
        expect(s.storage.token, isNull, reason: code);
        expect(s.viewModel.ratings, isEmpty, reason: '만료된 세션의 평점은 남기지 않습니다.');
      }
    });

    test('a network failure is an inline error and does not sign out', () async {
      final s = _Setup();
      await s.start();
      s.ratings.deleteFailure = dioFailure('/v7/ratings/1');

      final error = await _error(() => s.viewModel.deleteRating(1));

      expect(error, isA<RatingWriteException>().having((e) => e.kind, 'kind', RatingWriteKind.inline));
      expect(s.auth.status, AuthStatus.signedIn);
      expect(s.viewModel.ratings, hasLength(3));
    });
  });

  group('MyRatingsViewModel (session changes)', () {
    test('logging out and logging in again starts with an empty list', () async {
      final s = _Setup();
      await s.start();
      expect(s.viewModel.ratings, hasLength(3));

      await s.auth.logout();
      expect(s.viewModel.ratings, isEmpty);

      await s.auth.login('other@example.com', 'Umc1234!');
      expect(s.viewModel.ratings, isEmpty);
    });

    test('an expired session also clears the previous ratings and selection', () async {
      final s = _Setup();
      await s.start();
      s.viewModel.enterSelectionMode();
      s.viewModel.toggleSelection(1);

      await s.auth.expireSession();

      expect(s.viewModel.ratings, isEmpty);
      expect(s.viewModel.isSelectionMode, isFalse);
      expect(s.viewModel.selectedRatingIds, isEmpty);
    });

    test('a write response that arrives after logout is not applied', () async {
      final s = _Setup();
      s.ratings.delay = const Duration(milliseconds: 20);
      await s.start();

      final updating = s.viewModel.updateRating(ratingId: 1, score: 2);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await s.auth.logout();
      await updating; // 이전 세션의 응답은 조용히 버려집니다.

      expect(s.viewModel.ratings, isEmpty);
    });

    test('does not notify after dispose', () async {
      final s = _Setup();
      await s.start();
      s.ratings.delay = const Duration(milliseconds: 20);

      final deleting = s.viewModel.deleteRating(1);
      s.viewModel.dispose();

      await deleting; // 예외 없이 끝나야 합니다.
    });
  });

  group('MyRatingsViewModel (multi select)', () {
    test('toggles selection only in selection mode and cancel clears it', () async {
      final s = _Setup();
      await s.start();

      s.viewModel.toggleSelection(1);
      expect(s.viewModel.selectedRatingIds, isEmpty);

      s.viewModel.enterSelectionMode();
      s.viewModel.toggleSelection(1);
      s.viewModel.toggleSelection(2);
      s.viewModel.toggleSelection(1);
      expect(s.viewModel.selectedRatingIds, {2});

      s.viewModel.cancelSelectionMode();
      expect(s.viewModel.isSelectionMode, isFalse);
      expect(s.viewModel.selectedRatingIds, isEmpty);
    });

    test('deletes every selected rating and leaves selection mode', () async {
      final s = _Setup();
      await s.start();
      s.viewModel.enterSelectionMode();
      s.viewModel
        ..toggleSelection(1)
        ..toggleSelection(3);

      final result = await s.viewModel.deleteSelectedRatings();

      expect(result.deleted, 2);
      expect(result.hasPartialFailure, isFalse);
      expect(s.ratings.deletedIds, [1, 3]);
      expect(s.viewModel.isSelectionMode, isFalse);
      expect(s.viewModel.ratings.map((e) => e.rating.ratingId), [2]);
    });

    test('a partial failure removes only the successes and keeps the failed ones selected', () async {
      final s = _Setup();
      s.ratings.networkFailingDeleteIds.add(2);
      await s.start();
      s.viewModel.enterSelectionMode();
      s.viewModel
        ..toggleSelection(1)
        ..toggleSelection(2);

      final result = await s.viewModel.deleteSelectedRatings();

      expect((result.deleted, result.failed), (1, 1));
      expect(result.hasPartialFailure, isTrue);
      expect(s.viewModel.isSelectionMode, isTrue);
      expect(s.viewModel.selectedRatingIds, {2});
      expect(s.viewModel.ratings.map((e) => e.rating.ratingId), [2, 3]);
    });

    test('a rating that no longer exists on the server (RATING404_1) is dropped from the list', () async {
      final s = _Setup();
      s.ratings.failingDeleteIds.add(2);
      await s.start();
      s.viewModel.enterSelectionMode();
      s.viewModel.toggleSelection(2);

      final result = await s.viewModel.deleteSelectedRatings();

      expect(result.failed, 1);
      expect(s.viewModel.ratings.map((e) => e.rating.ratingId), [1, 3]);
      expect(s.viewModel.selectedRatingIds, isEmpty);
    });

    test('a 401 in the middle stops the remaining requests and expires the session', () async {
      final s = _Setup();
      await s.start();
      s.viewModel.enterSelectionMode();
      s.viewModel
        ..toggleSelection(1)
        ..toggleSelection(2)
        ..toggleSelection(3);
      s.ratings.deleteFailure = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다.');

      final result = await s.viewModel.deleteSelectedRatings();

      expect(result.deleted, 0);
      expect(s.ratings.deletedIds, isEmpty); // 첫 요청에서 멈춥니다.
      expect(s.auth.status, AuthStatus.signedOut);
      expect(s.auth.sessionExpired, isTrue);
    });

    test('does nothing when nothing is selected and ignores a second call while running', () async {
      final s = _Setup();
      s.ratings.delay = const Duration(milliseconds: 20);
      await s.start();

      final none = await s.viewModel.deleteSelectedRatings();
      expect(none.deleted + none.failed, 0);

      s.viewModel.enterSelectionMode();
      s.viewModel.toggleSelection(1);
      final first = s.viewModel.deleteSelectedRatings();
      final second = await s.viewModel.deleteSelectedRatings();
      await first;

      expect(second.deleted + second.failed, 0);
      expect(s.ratings.deletedIds, [1]);
    });
  });

  group('MyRatingsScreen', () {
    Future<_Setup> pumpScreen(WidgetTester tester, {bool seed = true}) async {
      _useMobileViewport(tester);
      final s = _Setup();
      // 가짜 서비스의 Future.delayed는 테스트 시계로는 흐르지 않으므로 실제 비동기로 준비합니다.
      await tester.runAsync(() => s.start(seed: seed));
      await tester.pumpWidget(
        ChangeNotifierProvider<MyRatingsViewModel>.value(
          value: s.viewModel,
          child: MaterialApp(theme: AppTheme.light, home: const MyRatingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('shows cards with score, comment and the joined movie info', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(RatingCard), findsNWidgets(3));
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('별점 5 / 5'), findsOneWidget);
      expect(find.text('최고의 영화!'), findsOneWidget);
      expect(find.text('영화 #13'), findsOneWidget); // TMDB에 없는 영화는 placeholder
      expect(find.text('포스터 정보 없음'), findsOneWidget);
      expect(find.text('수정'), findsNWidgets(3));
      expect(find.text('삭제'), findsNWidgets(3));
    });

    testWidgets('an empty session says so and explains that only this login is shown', (tester) async {
      await pumpScreen(tester, seed: false);

      expect(find.textContaining('이번 로그인에서 등록한 평점이 없습니다.'), findsOneWidget);
      expect(find.byType(RatingCard), findsNothing);
      expect(find.text('다시 시도'), findsNothing);
    });

    testWidgets('edit opens a Dialog filled with the saved values and updates the card from the response', (
      tester,
    ) async {
      final s = await pumpScreen(tester);

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('평점을 수정해주세요'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '최고의 영화!');

      await tester.enterText(find.byType(TextField), '다시 봐도 최고');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(s.ratings.updates.single, (ratingId: 1, score: 5, comment: '다시 봐도 최고'));
      expect(find.text('다시 봐도 최고'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('a rejected edit (400) keeps the Dialog open with the input and the server message', (tester) async {
      final s = await pumpScreen(tester);
      s.ratings.updateFailure = commonFailure(400, 'COMMON400', '별점은 5점 이하여야 합니다.');

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '고친 후기');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('별점은 5점 이하여야 합니다.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '고친 후기');
    });

    testWidgets('403 closes the Dialog and shows the server message as a Snackbar, staying signed in', (tester) async {
      final s = await pumpScreen(tester);
      s.ratings.updateFailure = commonFailure(
        403,
        'RATING403_1',
        '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
      );

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(s.auth.status, AuthStatus.signedIn);
    });

    testWidgets('401 closes the Dialog without a rating message and expires the session', (tester) async {
      final s = await pumpScreen(tester);
      s.ratings.updateFailure = commonFailure(401, 'AUTH401_4', '토큰이 만료되었습니다. 다시 로그인해주세요.');

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(find.text('평점을 수정했습니다.'), findsNothing);
      expect(find.text('토큰이 만료되었습니다. 다시 로그인해주세요.'), findsNothing); // 안내는 로그인 화면이 맡습니다.
      expect(s.auth.status, AuthStatus.signedOut);
      expect(s.auth.sessionExpired, isTrue);
    });

    testWidgets('delete asks first; cancel sends no request', (tester) async {
      final s = await pumpScreen(tester);

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('취소')));
      await tester.pumpAndSettle();

      expect(s.ratings.deletedIds, isEmpty);
      expect(find.byType(RatingCard), findsNWidgets(3));
    });

    testWidgets('confirming a delete keeps the Dialog while deleting, then removes the card', (tester) async {
      final s = await pumpScreen(tester);
      s.ratings.delay = const Duration(milliseconds: 200);

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('삭제')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(RatingDeleteDialog), findsOneWidget); // 삭제하는 동안 Dialog 유지

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDeleteDialog), findsNothing);
      expect(s.ratings.deletedIds, [1]);
      expect(find.byType(RatingCard), findsNWidgets(2));
      expect(find.text('평점을 삭제했습니다.'), findsOneWidget);
    });

    testWidgets('multi select: check cards → delete with the overlay; a partial failure keeps the failed one selected', (
      tester,
    ) async {
      final s = await pumpScreen(tester);
      s.ratings.networkFailingDeleteIds.add(2);
      s.ratings.delay = const Duration(milliseconds: 200);

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.text('0개 선택됨'), findsOneWidget);
      expect(find.text('수정'), findsNothing);

      await tester.tap(find.text('파이트 클럽 · 별점 5'));
      await tester.tap(find.text('펄프 픽션 · 별점 4'));
      await tester.pump();
      expect(find.text('2개 선택됨'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '선택한 2개 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('삭제')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RatingDeleteDialog), findsNothing);
      expect(tester.widget<LoadingOverlay>(find.byType(LoadingOverlay)).isLoading, isTrue);

      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();

      expect(find.text('1개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'), findsOneWidget);
      expect(find.text('1개 선택됨'), findsOneWidget);
      expect(find.text('파이트 클럽 · 별점 5'), findsNothing);
      expect(find.text('펄프 픽션 · 별점 4'), findsOneWidget);
    });
  });

  test('card date formatting keeps the local calendar date', () {
    expect(formatRatingDate(DateTime.utc(2026, 10, 31, 3)).length, 10);
  });
}
