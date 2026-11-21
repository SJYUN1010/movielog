import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

import 'support/fakes.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, [this.body]);

  final int status;
  final Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        if (body != null) Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))..httpClientAdapter = adapter;

Map<String, dynamic> _ok(int status, Object? result, {String message = 'ok'}) => {
  'isSuccess': true,
  'code': 'COMMON$status',
  'message': message,
  'result': result,
};

const _email = 'a@example.com';

SessionGuard _session([String email = _email]) => SessionGuard()..startSession(email);

void main() {
  group('SessionGuard', () {
    test('a response is current only for the same generation and account', () {
      final guard = SessionGuard();
      final generation = guard.startSession('a@x.com');

      expect(guard.isCurrent(generation, 'a@x.com'), isTrue);
      expect(guard.isCurrent(generation, 'b@x.com'), isFalse);
      expect(guard.isCurrent(generation - 1, 'a@x.com'), isFalse);
    });

    test('invalidate and a new session both make older responses stale', () {
      final guard = SessionGuard();
      final first = guard.startSession('a@x.com');

      final second = guard.startSession('a@x.com'); // 같은 계정이어도 새 세션
      expect(guard.isCurrent(first, 'a@x.com'), isFalse);
      expect(guard.isCurrent(second, 'a@x.com'), isTrue);

      guard.invalidate();
      expect(guard.isCurrent(second, 'a@x.com'), isFalse);
      expect(guard.accountId, isNull);
    });
  });

  group('AuthSessionBridge', () {
    final auth = FakeAuthApiService();

    test('starts a session only after GET me gives an email, and ends it on logout', () async {
      final members = FakeMemberApiService();
      final viewModel = AuthViewModel(auth, members, MemoryTokenStorage());
      final bridge = AuthSessionBridge(
        authSignals: viewModel,
        sessionVersion: () => viewModel.sessionVersion,
        verifiedEmail: () => viewModel.status == AuthStatus.signedIn ? viewModel.member?.email : null,
      );
      addTearDown(bridge.dispose);

      await viewModel.login('movie@example.com', 'Umc1234!');
      expect(bridge.guard.accountId, isNull); // 토큰만 있고 내 정보가 아직 없으면 세션이 아닙니다.

      await viewModel.loadMember();
      expect(bridge.guard.accountId, 'movie@example.com');
      final generation = bridge.guard.generation;

      viewModel.updateMember(memberInfo(nickname: '바뀐닉네임')); // 닉네임 수정은 세션을 다시 시작하지 않습니다.
      expect(bridge.guard.generation, generation);

      await viewModel.logout();
      expect(bridge.guard.accountId, isNull);
      expect(bridge.guard.isCurrent(generation, 'movie@example.com'), isFalse);
    });

    test('logging in again with the same email is a new session', () async {
      final viewModel = AuthViewModel(auth, FakeMemberApiService(), MemoryTokenStorage());
      final bridge = AuthSessionBridge(
        authSignals: viewModel,
        sessionVersion: () => viewModel.sessionVersion,
        verifiedEmail: () => viewModel.status == AuthStatus.signedIn ? viewModel.member?.email : null,
      );
      addTearDown(bridge.dispose);
      await viewModel.login('movie@example.com', 'Umc1234!');
      await viewModel.loadMember();
      final first = bridge.guard.generation;

      await viewModel.logout();
      await viewModel.login('movie@example.com', 'Umc1234!');
      await viewModel.loadMember();

      expect(bridge.guard.accountId, 'movie@example.com');
      expect(bridge.guard.generation, greaterThan(first));
      expect(bridge.guard.isCurrent(first, 'movie@example.com'), isFalse);
    });

    test('switching to another account changes accountId', () async {
      final members = FakeMemberApiService();
      final viewModel = AuthViewModel(auth, members, MemoryTokenStorage());
      final bridge = AuthSessionBridge(
        authSignals: viewModel,
        sessionVersion: () => viewModel.sessionVersion,
        verifiedEmail: () => viewModel.status == AuthStatus.signedIn ? viewModel.member?.email : null,
      );
      addTearDown(bridge.dispose);
      await viewModel.login('a@example.com', 'Umc1234!');
      await viewModel.loadMember();
      expect(bridge.guard.accountId, 'movie@example.com');

      await viewModel.logout();
      members.member = memberInfo(email: 'b@example.com', nickname: '다른사람');
      await viewModel.login('b@example.com', 'Umc1234!');
      await viewModel.loadMember();

      expect(bridge.guard.accountId, 'b@example.com');
    });

    test('dispose stops listening and invalidates', () async {
      final viewModel = AuthViewModel(auth, FakeMemberApiService(), MemoryTokenStorage());
      final bridge = AuthSessionBridge(
        authSignals: viewModel,
        sessionVersion: () => viewModel.sessionVersion,
        verifiedEmail: () => viewModel.member?.email,
      );

      bridge.dispose();
      await viewModel.login('movie@example.com', 'Umc1234!');
      await viewModel.loadMember();

      expect(bridge.guard.accountId, isNull);
    });
  });

  group('mapBounded', () {
    test('keeps the input order and never runs more than the limit at once', () async {
      var active = 0;
      var maxActive = 0;

      final result = await mapBounded(List.generate(12, (i) => i), 5, (value) async {
        active++;
        maxActive = maxActive > active ? maxActive : active;
        await Future<void>.delayed(Duration(milliseconds: 5 + (value % 3) * 4));
        active--;
        return value * 2;
      });

      expect(result, List.generate(12, (i) => i * 2));
      expect(maxActive, 5);
    });

    test('empty input returns an empty list and a non-positive limit is rejected', () async {
      expect(await mapBounded(<int>[], 5, (v) async => v), isEmpty);
      await expectLater(mapBounded([1], 0, (v) async => v), throwsArgumentError);
    });

    test('works when there are fewer items than the limit', () async {
      expect(await mapBounded([1, 2], 5, (v) async => v + 1), [2, 3]);
    });
  });

  group('FavoriteApiService (v8)', () {
    test('addFavorite posts only movieId (no memberId) and parses the 201 result', () async {
      final adapter = _StubAdapter(201, _ok(201, {'favoriteId': 3, 'movieId': 550, 'createdAt': '2026-09-06T12:14:03.000Z'}));

      final favorite = await FavoriteApiService(_dio(adapter)).addFavorite(movieId: 550);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/v8/favorites');
      expect(request.data, {'movieId': 550});
      expect(favorite.favoriteId, 3);
      expect(favorite.movieId, 550);
    });

    test('fetchMyFavorites reads a result array; an empty array is an empty list', () async {
      final filled = _StubAdapter(200, _ok(200, [
        {'favoriteId': 3, 'movieId': 550, 'createdAt': '2026-09-06T12:14:03.000Z'},
        {'favoriteId': 4, 'movieId': 13, 'createdAt': '2026-09-07T12:14:03.000Z'},
      ]));
      final list = await FavoriteApiService(_dio(filled)).fetchMyFavorites();
      expect(filled.requests.single.uri.path, '/v8/favorites');
      expect(list.map((f) => f.movieId), [550, 13]);

      expect(await FavoriteApiService(_dio(_StubAdapter(200, _ok(200, <dynamic>[])))).fetchMyFavorites(), isEmpty);
    });

    test('checkFavorite uses the movieId in the path and passes it to the dto (the result has none)', () async {
      final adapter = _StubAdapter(200, _ok(200, {'isFavorite': true}));

      final check = await FavoriteApiService(_dio(adapter)).checkFavorite(movieId: 550);

      expect(adapter.requests.single.uri.path, '/v8/favorites/550');
      expect(check.movieId, 550);
      expect(check.isFavorite, isTrue);
    });

    test('a non-boolean isFavorite is a format error, not a silent false', () async {
      final adapter = _StubAdapter(200, _ok(200, {'isFavorite': 'yes'}));

      await expectLater(
        FavoriteApiService(_dio(adapter)).checkFavorite(movieId: 1),
        throwsA(isA<FormatException>()),
      );
    });

    test('deleteFavorite treats 200 with result null as success without parsing, using movieId in the path', () async {
      final adapter = _StubAdapter(200, _ok(200, null, message: '즐겨찾기를 해제했습니다.'));

      await FavoriteApiService(_dio(adapter)).deleteFavorite(movieId: 550);

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.uri.path, '/v8/favorites/550');
    });

    test('409 and 404 keep FAVORITE409_1 / FAVORITE404_1 so callers can sync with the server', () async {
      for (final entry in {
        409: ('FAVORITE409_1', '이미 이 영화를 즐겨찾기하셨습니다.'),
        404: ('FAVORITE404_1', '즐겨찾기한 영화를 찾을 수 없습니다.'),
      }.entries) {
        final adapter = _StubAdapter(entry.key, {
          'isSuccess': false,
          'code': entry.value.$1,
          'message': entry.value.$2,
          'result': null,
        });
        Object? caught;
        try {
          await FavoriteApiService(_dio(adapter)).deleteFavorite(movieId: 550);
        } catch (error) {
          caught = error;
        }
        final error = caught! as DioException;
        expect(error.response?.statusCode, entry.key);
        expect(apiErrorCode(error), entry.value.$1);
      }
    });

    test('saveMovieRecord posts movieId, integer score, optional comment and a required addToFavorites', () async {
      final adapter = _StubAdapter(201, _ok(201, {
        'rating': {
          'ratingId': 9,
          'movieId': 550,
          'score': 4,
          'comment': '좋았어요',
          'createdAt': '2026-11-20T03:00:00.000Z',
          'updatedAt': '2026-11-20T03:00:00.000Z',
        },
        'favorite': {'favoriteId': 5, 'movieId': 550, 'createdAt': '2026-11-20T03:00:00.000Z'},
      }));

      final result = await FavoriteApiService(_dio(adapter)).saveMovieRecord(
        const MovieRecordRequest(movieId: 550, score: 4, comment: ' 좋았어요 ', addToFavorites: true),
      );

      final request = adapter.requests.single;
      expect(request.uri.path, '/v8/movie-records');
      expect(request.data, {'movieId': 550, 'score': 4, 'comment': '좋았어요', 'addToFavorites': true});
      expect(result.rating.ratingId, 9);
      expect(result.favorite?.favoriteId, 5);
    });

    test('with addToFavorites false the favorite is null and a blank comment is omitted', () async {
      final adapter = _StubAdapter(201, _ok(201, {
        'rating': {
          'ratingId': 9,
          'movieId': 550,
          'score': 4,
          'comment': null,
          'createdAt': '2026-11-20T03:00:00.000Z',
          'updatedAt': '2026-11-20T03:00:00.000Z',
        },
        'favorite': null,
      }));

      final result = await FavoriteApiService(_dio(adapter)).saveMovieRecord(
        const MovieRecordRequest(movieId: 550, score: 4, comment: '   ', addToFavorites: false),
      );

      expect(adapter.requests.single.data, {'movieId': 550, 'score': 4, 'addToFavorites': false});
      expect(result.favorite, isNull);
    });
  });

  group('FavoriteDetailViewModel', () {
    FavoriteDetailViewModel create(
      FakeFavoriteApiService api, {
      SessionGuard? guard,
      void Function()? onExpired,
      int movieId = 550,
    }) {
      final session = guard ?? _session();
      return FavoriteDetailViewModel(
        movieId: movieId,
        favoriteApi: api,
        sessionGuard: session,
        accountId: _email,
        onSessionExpired: onExpired,
      );
    }

    test('load reads the server value; the button is unusable before it is known', () async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api);
      await viewModel.toggle(); // 아직 모름 → 아무 요청도 보내지 않음
      expect(api.addCalls, isEmpty);
      expect(api.deleteCalls, isEmpty);

      await viewModel.load();

      expect(viewModel.hasLoadedStatus, isTrue);
      expect(viewModel.isFavorite, isTrue);
      expect(api.checkCalls, [550]);
    });

    test('add and delete change the icon state only after the server confirms (no optimistic update)', () async {
      final api = FakeFavoriteApiService()..delay = const Duration(milliseconds: 20);
      final viewModel = create(api);
      await viewModel.load();
      final states = <bool>[];
      viewModel.addListener(() => states.add(viewModel.isFavorite));

      final adding = viewModel.toggle();
      expect(viewModel.isSaving, isTrue);
      expect(viewModel.isFavorite, isFalse); // 응답 전에는 그대로
      await adding;
      expect(viewModel.isFavorite, isTrue);
      expect(api.favorites.containsKey(550), isTrue);

      await viewModel.toggle();
      expect(viewModel.isFavorite, isFalse);
      expect(api.deleteCalls, [550]);
      expect(states.first, isFalse);
    });

    test('a second tap while saving is ignored', () async {
      final api = FakeFavoriteApiService()..delay = const Duration(milliseconds: 20);
      final viewModel = create(api);
      await viewModel.load();

      final first = viewModel.toggle();
      await viewModel.toggle();
      await first;

      expect(api.addCalls, [550]);
    });

    test('a failed add keeps the previous icon, sets a message and is NOT retried automatically', () async {
      final api = FakeFavoriteApiService();
      final viewModel = create(api);
      await viewModel.load();
      api.addError = dioFailure('/v8/favorites'); // timeout처럼 응답을 못 받은 실패

      await viewModel.toggle();

      expect(viewModel.isFavorite, isFalse);
      expect(viewModel.errorMessage, '즐겨찾기 등록에 실패했습니다.');
      expect(api.addCalls, hasLength(1)); // 같은 POST를 자동으로 다시 보내지 않습니다.
      expect(viewModel.isSaving, isFalse);
    });

    test('a failed delete keeps the bookmark filled', () async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api);
      await viewModel.load();
      api.deleteError = dioFailure('/v8/favorites/550', statusCode: 500, data: {'message': 'x'});

      await viewModel.toggle();

      expect(viewModel.isFavorite, isTrue);
      expect(viewModel.errorMessage, '즐겨찾기 해제에 실패했습니다.');
    });

    test('FAVORITE409_1 syncs with the server instead of showing a failure', () async {
      final api = FakeFavoriteApiService();
      final viewModel = create(api);
      await viewModel.load();
      api.favorites[550] = favoriteDto(1, 550); // 다른 기기에서 이미 등록됨

      await viewModel.toggle();

      expect(viewModel.isFavorite, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(api.checkCalls, [550, 550]); // load + 409 뒤 서버 값 재조회
    });

    test('FAVORITE404_1 on delete syncs with the server (already removed)', () async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api);
      await viewModel.load();
      api.favorites.clear();

      await viewModel.toggle();

      expect(viewModel.isFavorite, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('if the re-check after 409 also fails, the previous state and a message remain', () async {
      final api = FakeFavoriteApiService();
      final viewModel = create(api);
      await viewModel.load();
      api.favorites[550] = favoriteDto(1, 550);
      api.checkError = dioFailure('/v8/favorites/550');

      await viewModel.toggle();

      expect(viewModel.isFavorite, isFalse);
      expect(viewModel.errorMessage, '서버 상태를 다시 확인하지 못했습니다.');
    });

    test('the first status check failing leaves a retryable state', () async {
      final api = FakeFavoriteApiService(movieIds: [550])..checkError = dioFailure('/v8/favorites/550');
      final viewModel = create(api);

      await viewModel.load();

      expect(viewModel.hasLoadedStatus, isFalse);
      expect(viewModel.errorMessage, '즐겨찾기 여부를 확인하지 못했습니다.');

      await viewModel.load(); // 새로고침 버튼
      expect(viewModel.hasLoadedStatus, isTrue);
      expect(viewModel.isFavorite, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('AUTH401_2/3/4 expire the session once and show no failure message', () async {
      for (final code in ['AUTH401_2', 'AUTH401_3', 'AUTH401_4']) {
        var expired = 0;
        final api = FakeFavoriteApiService();
        final viewModel = create(api, onExpired: () => expired++);
        await viewModel.load();
        api.addError = commonFailure(401, code, '로그인이 필요합니다.');

        await viewModel.toggle();

        expect(expired, 1, reason: code);
        expect(viewModel.errorMessage, isNull, reason: code);
        expect(viewModel.isFavorite, isFalse, reason: code);
      }
    });

    test('a 401 while loading the status also expires the session', () async {
      var expired = 0;
      final api = FakeFavoriteApiService()..checkError = commonFailure(401, 'AUTH401_4', '만료');
      final viewModel = create(api, onExpired: () => expired++);

      await viewModel.load();

      expect(expired, 1);
    });

    test('403 and network failures never sign out', () async {
      var expired = 0;
      final api = FakeFavoriteApiService();
      final viewModel = create(api, onExpired: () => expired++);
      await viewModel.load();

      api.addError = commonFailure(403, 'COMMON403', '권한이 없습니다.');
      await viewModel.toggle();
      api.addError = dioFailure('/v8/favorites');
      await viewModel.toggle();

      expect(expired, 0);
    });

    test('a response that arrives after the session changed is ignored', () async {
      final guard = _session();
      final api = FakeFavoriteApiService()..delay = const Duration(milliseconds: 20);
      final viewModel = create(api, guard: guard);
      api.delay = Duration.zero;
      await viewModel.load();
      api.delay = const Duration(milliseconds: 20);

      final toggling = viewModel.toggle();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      guard
        ..invalidate()
        ..startSession('b@example.com'); // 계정 전환
      await toggling;

      expect(viewModel.isFavorite, isFalse); // 이전 계정의 결과가 반영되지 않음
      expect(viewModel.isSaving, isTrue); // 이전 세션 요청은 현재 상태를 건드리지 않음
    });

    test('does nothing at all once its session is stale', () async {
      final guard = _session();
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api, guard: guard);
      guard.invalidate();

      await viewModel.load();
      await viewModel.toggle();

      expect(api.checkCalls, isEmpty);
      expect(api.addCalls, isEmpty);
    });

    test('does not notify after dispose', () async {
      final api = FakeFavoriteApiService()..delay = const Duration(milliseconds: 20);
      final viewModel = create(api);

      final loading = viewModel.load();
      viewModel.dispose();

      await loading; // 예외 없이 끝나야 합니다.
    });
  });

  group('FavoritesViewModel', () {
    FavoritesViewModel create(
      FakeFavoriteApiService api,
      FakeTmdbMovieService tmdb, {
      SessionGuard? guard,
      void Function()? onExpired,
    }) {
      return FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: tmdb,
        sessionGuard: guard ?? _session(),
        accountId: _email,
        onSessionExpired: onExpired,
      );
    }

    FakeTmdbMovieService tmdbWith(Iterable<int> ids) {
      final tmdb = FakeTmdbMovieService();
      for (final id in ids) {
        tmdb.movieDetails[id] = movieDto(id, title: '영화 $id');
      }
      return tmdb;
    }

    test('lists favorites joined with TMDB info by movieId, newest first', () async {
      final api = FakeFavoriteApiService(movieIds: [550, 680, 13]);
      final viewModel = create(api, tmdbWith([550, 680, 13]));

      await viewModel.refresh();

      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.items.map((i) => i.favorite.movieId), [13, 680, 550]);
      expect(viewModel.items.map((i) => i.movie?.title), ['영화 13', '영화 680', '영화 550']);
    });

    test('goes Loading then Ready, and an empty list is Empty (not Error)', () async {
      final api = FakeFavoriteApiService();
      final viewModel = create(api, FakeTmdbMovieService());
      final phases = <LoadPhase>[];
      viewModel.addListener(() => phases.add(viewModel.phase));

      await viewModel.refresh();

      expect(phases.first, LoadPhase.loading);
      expect(viewModel.phase, LoadPhase.empty);
      expect(viewModel.items, isEmpty);
    });

    test('a failed list request is Error with its own message, and refresh recovers', () async {
      final api = FakeFavoriteApiService(movieIds: [550])..listError = dioFailure('/v8/favorites');
      final viewModel = create(api, tmdbWith([550]));

      await viewModel.refresh();
      expect(viewModel.phase, LoadPhase.error);
      expect(viewModel.errorMessage, favoritesLoadFailedMessage);

      await viewModel.refresh();
      expect(viewModel.phase, LoadPhase.ready);
    });

    test('one TMDB failure only marks that card; the other cards and the list stay', () async {
      final api = FakeFavoriteApiService(movieIds: [550, 680, 13]);
      final tmdb = tmdbWith([550, 680, 13])..failingDetailIds.add(680);
      final viewModel = create(api, tmdb);

      await viewModel.refresh();

      expect(viewModel.phase, LoadPhase.ready);
      final failed = viewModel.items.singleWhere((i) => i.favorite.movieId == 680);
      expect(failed.movie, isNull);
      expect(failed.errorMessage, favoriteMovieLoadFailedMessage);
      expect(viewModel.items.where((i) => i.movie != null), hasLength(2));
    });

    test('retryMovie reloads only that card without asking for the favorites list again', () async {
      final api = FakeFavoriteApiService(movieIds: [550, 680]);
      final tmdb = tmdbWith([550, 680])..failingDetailIds.add(680);
      final viewModel = create(api, tmdb);
      await viewModel.refresh();
      final listCalls = api.listCalls;
      tmdb
        ..failingDetailIds.clear()
        ..detailCalls.clear();

      await viewModel.retryMovie(680);

      expect(api.listCalls, listCalls);
      expect(tmdb.detailCalls, [680]);
      expect(viewModel.items.every((i) => i.movie != null), isTrue);
    });

    test('a failing retryMovie leaves the placeholder so it can be tried again', () async {
      final api = FakeFavoriteApiService(movieIds: [680]);
      final tmdb = tmdbWith([680])..failingDetailIds.add(680);
      final viewModel = create(api, tmdb);
      await viewModel.refresh();

      await viewModel.retryMovie(680);

      expect(viewModel.items.single.movie, isNull);
    });

    test('TMDB info is fetched with at most 5 requests at a time', () async {
      final ids = List.generate(12, (i) => i + 1);
      final api = FakeFavoriteApiService(movieIds: ids);
      final tmdb = _CountingTmdb()..addAll(ids);
      final viewModel = create(api, tmdb);

      await viewModel.refresh();

      expect(viewModel.items, hasLength(12));
      expect(tmdb.maxActive, 5);
    });

    test('silent refresh after unfavoriting removes the movie without a loading screen', () async {
      final api = FakeFavoriteApiService(movieIds: [550, 680]);
      final tmdb = tmdbWith([550, 680]);
      final viewModel = create(api, tmdb);
      await viewModel.refresh();
      final phases = <LoadPhase>[];
      viewModel.addListener(() => phases.add(viewModel.phase));
      api.favorites.remove(550); // 상세에서 해제함
      tmdb.detailCalls.clear();

      await viewModel.refresh(silent: true);

      expect(phases, everyElement(LoadPhase.ready)); // 로딩 화면으로 바뀌지 않음
      expect(viewModel.items.map((i) => i.favorite.movieId), [680]);
      expect(tmdb.detailCalls, isEmpty); // 이미 받은 영화 정보는 다시 조회하지 않음
    });

    test('unfavoriting the last movie ends in Empty', () async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api, tmdbWith([550]));
      await viewModel.refresh();
      api.favorites.clear();

      await viewModel.refresh(silent: true);

      expect(viewModel.phase, LoadPhase.empty);
    });

    test('a failed silent refresh keeps the shown list instead of replacing it with an error', () async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api, tmdbWith([550]));
      await viewModel.refresh();
      api.listError = dioFailure('/v8/favorites');

      await viewModel.refresh(silent: true);

      expect(viewModel.phase, LoadPhase.ready);
      expect(viewModel.items, hasLength(1));
    });

    test('AUTH401_4 expires the session once', () async {
      var expired = 0;
      final api = FakeFavoriteApiService()..listError = commonFailure(401, 'AUTH401_4', '만료');
      final viewModel = create(api, FakeTmdbMovieService(), onExpired: () => expired++);

      await viewModel.refresh();

      expect(expired, 1);
      expect(viewModel.phase, isNot(LoadPhase.error));
    });

    test('403 and network failures do not sign out', () async {
      var expired = 0;
      final api = FakeFavoriteApiService()..listError = commonFailure(403, 'COMMON403', '권한 없음');
      final viewModel = create(api, FakeTmdbMovieService(), onExpired: () => expired++);

      await viewModel.refresh();

      expect(expired, 0);
      expect(viewModel.phase, LoadPhase.error);
    });

    test('a list response that arrives after logout or an account switch is never shown', () async {
      final guard = _session();
      final api = FakeFavoriteApiService(movieIds: [550])..delay = const Duration(milliseconds: 30);
      final viewModel = create(api, tmdbWith([550]), guard: guard);

      final refreshing = viewModel.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      guard
        ..invalidate()
        ..startSession('b@example.com');
      await refreshing;

      expect(viewModel.items, isEmpty); // 이전 계정의 즐겨찾기가 남지 않음
      expect(viewModel.phase, LoadPhase.loading);
    });

    test('an older refresh that finishes after a newer one cannot overwrite it', () async {
      final api = FakeFavoriteApiService(movieIds: [550]);
      final tmdb = tmdbWith([550, 680]);
      final viewModel = create(api, tmdb);
      api.delay = const Duration(milliseconds: 40);

      final older = viewModel.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      api.favorites[680] = favoriteDto(9, 680);
      api.delay = Duration.zero;
      final newer = viewModel.refresh();
      await Future.wait([older, newer]);

      expect(viewModel.items.map((i) => i.favorite.movieId).toSet(), {550, 680});
    });

    test('a stale view model does nothing when its session is already gone', () async {
      final guard = _session();
      final api = FakeFavoriteApiService(movieIds: [550]);
      final viewModel = create(api, tmdbWith([550]), guard: guard);
      guard.invalidate();

      await viewModel.refresh();

      expect(api.listCalls, 0);
    });

    test('does not notify after dispose', () async {
      final api = FakeFavoriteApiService(movieIds: [550])..delay = const Duration(milliseconds: 20);
      final viewModel = create(api, tmdbWith([550]));

      final refreshing = viewModel.refresh();
      viewModel.dispose();

      await refreshing; // 예외 없이 끝나야 합니다.
    });
  });
}

class _CountingTmdb extends FakeTmdbMovieService {
  int active = 0;
  int maxActive = 0;

  void addAll(Iterable<int> ids) {
    for (final id in ids) {
      movieDetails[id] = movieDto(id);
    }
  }

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    active--;
    return movieDetails[movieId]!;
  }
}
