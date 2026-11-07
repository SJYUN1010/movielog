import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/router/app_router.dart';
import 'package:movielog/screens/my_ratings_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/my_ratings_view_model.dart';
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

/// 화면 안의 모든 PopScope입니다(제네릭 타입과 관계없이 찾습니다).
List<PopScope> _popScopes(WidgetTester tester) =>
    tester.widgetList(find.byWidgetPredicate((widget) => widget is PopScope)).cast<PopScope>().toList();

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
  group('MyRatingsViewModel (read)', () {
    test('queries the given member and ends in Success with movies joined', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      final statuses = <MyRatingsLoadStatus>[];
      viewModel.addListener(() => statuses.add(viewModel.status));

      await viewModel.load();

      expect(fakes.ratings.requestedMemberIds, [12]);
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

    test('a 404 shows the server message and a network failure the fallback', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 999999);

      fakes.ratings.failure = commonFailure(404, 'COMMON404', '존재하지 않는 유저입니다.');
      await viewModel.load();
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.message, '존재하지 않는 유저입니다.');

      fakes.ratings.failure = dioFailure('/x');
      await viewModel.load();
      expect(viewModel.message, ratingsLoadFailedMessage);
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

  group('MyRatingsViewModel (update / delete)', () {
    test('update always sends score and comment, then reloads the list', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 3, comment: '고쳤어요');

      expect(fakes.ratings.updates.single, (
        memberId: 12,
        ratingId: 1,
        score: 3,
        comment: '고쳤어요',
      ));
      expect(fakes.ratings.fetchCount, 2);
      expect(viewModel.ratings.first.rating.score, 3);
      expect(viewModel.ratings.first.rating.comment, '고쳤어요');
    });

    test('clearing the comment sends null explicitly, so the old comment is removed on purpose', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      await viewModel.updateRating(ratingId: 1, score: 5, comment: null);

      expect(fakes.ratings.updates.single.comment, isNull);
      expect(viewModel.ratings.first.rating.comment, isNull);
    });

    test('deleting the last rating ends in Empty', () async {
      final fakes = _fakes()..ratings.ratings = [ratingDto(1, movieId: 550)];
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      await viewModel.deleteRating(1);

      expect(fakes.ratings.deletedIds, [1]);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });

    test('a write failure is rethrown and the list is kept', () async {
      final fakes = _fakes()
        ..ratings.updateFailure = commonFailure(400, 'COMMON400', '별점은 5점 이하여야 합니다.');
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      await expectLater(
        viewModel.updateRating(ratingId: 1, score: 5, comment: 'x'),
        throwsA(isA<DioException>()),
      );

      // 400은 값만 고치면 되므로 다시 조회하지 않습니다.
      expect(fakes.ratings.fetchCount, 1);
      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.ratings, hasLength(3));
    });

    test('403 and 404 reload the list so it matches the server again', () async {
      final fakes = _fakes()
        ..ratings.deleteFailure = commonFailure(
          403,
          'COMMON403',
          '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.',
        );
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      await expectLater(viewModel.deleteRating(1), throwsA(isA<DioException>()));
      expect(fakes.ratings.fetchCount, 2);

      fakes.ratings.deleteFailure = commonFailure(404, 'COMMON404', '존재하지 않는 평점입니다.');
      await expectLater(viewModel.deleteRating(1), throwsA(isA<DioException>()));
      expect(fakes.ratings.fetchCount, 3);
    });

    test('a save that succeeds but whose GET fails is not reported as a write failure', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();
      fakes.ratings.failNextFetches = 1;

      await viewModel.deleteRating(1); // 예외 없이 끝납니다.

      expect(fakes.ratings.deletedIds, [1]);
      expect(viewModel.status, MyRatingsLoadStatus.error);
      expect(viewModel.refreshWarning, refreshAfterWriteFailedMessage);

      // 조회만 다시 시도합니다. 삭제는 다시 보내지 않습니다.
      await viewModel.retry();
      expect(viewModel.status, MyRatingsLoadStatus.success);
      expect(viewModel.refreshWarning, isNull);
      expect(fakes.ratings.deletedIds, [1]);
      expect(viewModel.ratings.any((e) => e.rating.ratingId == 1), isFalse);
    });

    test('a second write while one is running is ignored', () async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 20);
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      final first = viewModel.deleteRating(1);
      final second = viewModel.deleteRating(1);
      await Future.wait([first, second]);

      expect(fakes.ratings.deletedIds, [1]);
    });
  });

  group('MyRatingsViewModel (multi select)', () {
    test('toggles selection only in selection mode and cancel clears it', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();

      viewModel.toggleSelection(1);
      expect(viewModel.selectedRatingIds, isEmpty);

      viewModel.enterSelectionMode();
      viewModel.toggleSelection(1);
      viewModel.toggleSelection(2);
      viewModel.toggleSelection(2);
      expect(viewModel.selectedRatingIds, {1});

      viewModel.cancelSelectionMode();
      expect(viewModel.isSelectionMode, isFalse);
      expect(viewModel.selectedRatingIds, isEmpty);
    });

    test('deletes every selected rating and leaves selection mode', () async {
      final fakes = _fakes();
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();
      viewModel
        ..enterSelectionMode()
        ..toggleSelection(1)
        ..toggleSelection(2);

      final result = await viewModel.deleteSelectedRatings();

      expect(result.deleted, 2);
      expect(result.failed, 0);
      expect(fakes.ratings.deletedIds, [1, 2]);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [3]);
      expect(viewModel.isSelectionMode, isFalse);
      expect(viewModel.isDeletingSelected, isFalse);
    });

    test('a partial failure removes only the successes and keeps the failed ones selected', () async {
      final fakes = _fakes()..ratings.failingDeleteIds.add(2);
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();
      viewModel
        ..enterSelectionMode()
        ..toggleSelection(1)
        ..toggleSelection(2)
        ..toggleSelection(3);

      final result = await viewModel.deleteSelectedRatings();

      expect(result.deleted, 2);
      expect(result.failed, 1);
      expect(result.hasPartialFailure, isTrue);
      expect(viewModel.ratings.map((e) => e.rating.ratingId), [2]);
      expect(viewModel.selectedRatingIds, {2}); // 실패한 항목은 선택이 유지됩니다.
      expect(viewModel.isSelectionMode, isTrue);

      // 다시 시도할 수 있습니다.
      fakes.ratings.failingDeleteIds.clear();
      final retry = await viewModel.deleteSelectedRatings();
      expect(retry.deleted, 1);
      expect(viewModel.ratings, isEmpty);
      expect(viewModel.status, MyRatingsLoadStatus.empty);
    });

    test('does nothing when nothing is selected and ignores a second call while running', () async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 20);
      final viewModel = MyRatingsViewModel(fakes.ratings, fakes.movies, 12);
      await viewModel.load();
      viewModel.enterSelectionMode();

      final none = await viewModel.deleteSelectedRatings();
      expect(none.deleted + none.failed, 0);

      viewModel.toggleSelection(1);
      final first = viewModel.deleteSelectedRatings();
      expect(viewModel.isDeletingSelected, isTrue);
      expect(viewModel.isBusy, isTrue);
      final second = await viewModel.deleteSelectedRatings();
      expect(second.deleted + second.failed, 0);
      await first;

      expect(fakes.ratings.deletedIds, [1]);
    });
  });

  group('MyRatingsScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required FakeRatingApiService ratings,
      required FakeTmdbMovieService movies,
      int memberId = 12,
    }) async {
      _useMobileViewport(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MyRatingsViewModel(ratings, movies, memberId)..load(),
          child: MaterialApp(theme: AppTheme.light, home: const MyRatingsScreen()),
        ),
      );
    }

    testWidgets('Loading then Success cards with score, comment and movie info', (tester) async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 50);
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);

      expect(find.text('평점을 불러오는 중이에요...'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(find.text('별점 5 / 5'), findsOneWidget);
      expect(find.text('최고의 영화!'), findsOneWidget);
      expect(find.text('영화 #13'), findsOneWidget);
      expect(find.text('포스터 정보 없음'), findsOneWidget);
      expect(find.text(missingMovieMessage), findsOneWidget);
      // 카드마다 수정·삭제 버튼이 있습니다.
      expect(find.text('수정'), findsNWidgets(3));
      expect(find.text('삭제'), findsNWidgets(3));
    });

    testWidgets('Empty shows its own message and no retry button', (tester) async {
      final fakes = _fakes()..ratings.ratings = [];
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      expect(find.text('등록된 평점이 없습니다.'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);
      expect(find.text('편집'), findsNothing);
    });

    testWidgets('Error shows a friendly message, never a raw exception, and retries', (tester) async {
      final fakes = _fakes()..ratings.failure = dioFailure('/x');
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      expect(find.text(ratingsLoadFailedMessage), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);

      fakes.ratings.failure = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(find.text('파이트 클럽'), findsOneWidget);
    });

    testWidgets('edit opens a Dialog filled with the saved score and comment, then reloads', (
      tester,
    ) async {
      final fakes = _fakes();
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('평점을 수정해주세요'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '최고의 영화!');

      await tester.enterText(find.byType(TextField), '다시 봐도 최고');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsNothing);
      expect(fakes.ratings.updates.single.comment, '다시 봐도 최고');
      expect(fakes.ratings.updates.single.score, 5);
      expect(fakes.ratings.fetchCount, 2);
      expect(find.text('다시 봐도 최고'), findsOneWidget);
      expect(find.text('평점을 수정했습니다.'), findsOneWidget);
    });

    testWidgets('a comment that is null starts an empty TextField', (tester) async {
      final fakes = _fakes()..ratings.ratings = [ratingDto(1, movieId: 550, comment: null)];
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      await tester.tap(find.text('수정'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('an edit that the server rejects keeps the Dialog open with the input and the server message', (
      tester,
    ) async {
      final fakes = _fakes()
        ..ratings.updateFailure = commonFailure(403, 'COMMON403', '본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.');
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      await tester.tap(find.text('수정').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '바꾼 후기');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDialog), findsOneWidget);
      expect(find.text('본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '바꾼 후기');
      // 403은 목록을 서버와 다시 맞춥니다.
      expect(fakes.ratings.fetchCount, 2);
      // 버튼이 로딩 상태로 남지 않고 다시 누를 수 있습니다.
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '확인')).onPressed,
        isNotNull,
      );
    });

    testWidgets('delete asks first; cancel sends no request', (tester) async {
      final fakes = _fakes();
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제한 평점은 복구할 수 없습니다.'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('취소')));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDeleteDialog), findsNothing);
      expect(fakes.ratings.deletedIds, isEmpty);
      expect(fakes.ratings.fetchCount, 1);
    });

    testWidgets('confirming a delete keeps the Dialog while deleting, then reloads and shows Empty for the last item', (
      tester,
    ) async {
      final fakes = _fakes()..ratings.ratings = [ratingDto(1, movieId: 550)];
      fakes.ratings.delay = const Duration(milliseconds: 100);
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('삭제')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // 삭제하는 동안 Dialog가 유지되고 버튼은 로딩 상태입니다.
      expect(find.byType(RatingDeleteDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byType(RatingDeleteDialog), findsNothing);
      expect(fakes.ratings.deletedIds, [1]);
      expect(find.text('등록된 평점이 없습니다.'), findsOneWidget);
    });

    testWidgets('a delete that succeeds but whose reload fails shows a GET-only retry', (tester) async {
      final fakes = _fakes();
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pumpAndSettle();
      fakes.ratings.failNextFetches = 1;

      await tester.tap(find.text('삭제').first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('삭제')));
      await tester.pumpAndSettle();

      expect(find.text(refreshAfterWriteFailedMessage), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(fakes.ratings.deletedIds, [1]); // 삭제는 한 번만 보냈습니다.
      expect(find.text(refreshAfterWriteFailedMessage), findsNothing);
      expect(find.text('파이트 클럽'), findsNothing);
      expect(find.text('펄프 픽션'), findsOneWidget);
    });

    testWidgets('multi select: edit → check cards → delete with overlay, partial failure keeps the failed selected', (
      tester,
    ) async {
      final fakes = _fakes()..ratings.failingDeleteIds.add(2);
      fakes.ratings.delay = const Duration(milliseconds: 200);
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.text('0개 선택됨'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      expect(find.text('수정'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '선택한 0개 삭제')).onPressed,
        isNull,
      );

      await tester.tap(find.text('파이트 클럽 · 별점 5'));
      await tester.tap(find.text('펄프 픽션 · 별점 4'));
      await tester.pump();
      expect(find.text('2개 선택됨'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, '선택한 2개 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('평점을 삭제할까요?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('삭제')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 확인 Dialog는 삭제를 기다리지 않고 닫히고, 화면 위 오버레이가 로딩을 맡습니다.
      expect(find.byType(RatingDeleteDialog), findsNothing);
      expect(tester.widget<LoadingOverlay>(find.byType(LoadingOverlay)).isLoading, isTrue);
      expect(find.byType(ModalBarrier), findsWidgets);

      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();

      expect(find.text('1개 항목을 삭제하지 못했습니다. 선택된 항목을 다시 확인해 주세요.'), findsOneWidget);
      expect(find.text('1개 선택됨'), findsOneWidget);
      expect(find.text('펄프 픽션 · 별점 4'), findsOneWidget);
      expect(find.text('파이트 클럽 · 별점 5'), findsNothing);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.text('편집'), findsOneWidget);
      expect(find.text('수정'), findsWidgets);
    });

    testWidgets('while deleting the selection the screen cannot be left', (tester) async {
      final fakes = _fakes();
      fakes.ratings.delay = const Duration(milliseconds: 100);
      await pumpScreen(tester, ratings: fakes.ratings, movies: fakes.movies);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('파이트 클럽 · 별점 5'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, '선택한 1개 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(RatingDeleteDialog), matching: find.text('삭제')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(_popScopes(tester).any((scope) => !scope.canPop), isTrue);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(_popScopes(tester).every((scope) => scope.canPop), isTrue);
    });
  });

  group('MyPage → 내가 등록한 평점 routing', () {
    Future<void> pumpRouter(
      WidgetTester tester,
      FakeRatingApiService ratings,
      FakeTmdbMovieService movies, {
      LearningMemberSession? session,
    }) async {
      _useMobileViewport(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TmdbMovieService>.value(value: movies),
            Provider<RatingApiService>.value(value: ratings),
            Provider<SignUpService>.value(value: FakeSignUpService()),
            ChangeNotifierProvider<LearningMemberSession>.value(
              value: session ?? LearningMemberSession(memberId: 12),
            ),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: AppRouter.router),
        ),
      );
    }

    testWidgets('opens a child screen without the bottom bar, uses the session member, and returns on back', (
      tester,
    ) async {
      final fakes = _fakes();
      await pumpRouter(tester, fakes.ratings, fakes.movies);
      AppRouter.router.go('/my');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();

      expect(find.byType(MyRatingsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('파이트 클럽'), findsOneWidget);
      expect(fakes.ratings.requestedMemberIds, [12]);

      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.byType(MyRatingsScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('without a signed-up member it asks for sign up instead of querying', (tester) async {
      final fakes = _fakes();
      await pumpRouter(tester, fakes.ratings, fakes.movies, session: LearningMemberSession());
      AppRouter.router.go('/my');
      await tester.pumpAndSettle();

      await tester.tap(find.text('내가 등록한 평점'));
      await tester.pumpAndSettle();

      expect(find.text('학습용 회원가입이 필요합니다.'), findsOneWidget);
      expect(find.text('회원가입하러 가기'), findsOneWidget);
      expect(fakes.ratings.requestedMemberIds, isEmpty);
    });
  });

  test('card date formatting keeps the local calendar date', () {
    expect(formatRatingDate(DateTime.utc(2026, 10, 31, 3)).length, 10);
  });
}
