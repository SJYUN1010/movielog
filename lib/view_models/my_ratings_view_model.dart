import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/models/rating_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'rating_write_exception.dart';

const missingMovieMessage = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';

/// 다중 삭제 결과입니다.
class DeleteSelectedResult {
  const DeleteSelectedResult({required this.deleted, required this.failed});

  final int deleted;
  final int failed;

  bool get hasPartialFailure => failed > 0;
}

/// "내가 등록한 평점" 화면의 ViewModel입니다. 앱 전체에서 하나만 두고 로그인 세션 동안 유지합니다.
///
/// v7에는 토큰 기반 "내 평점 전체 GET"이 없고 로그인·내 정보 응답에도 memberId가 없습니다.
/// 그래서 이 ViewModel은 **이번 로그인 세션에서 등록 response로 받은 Rating**만 들고 있으며,
/// 앱을 다시 켜면 기존 평점 전체를 복원하지 않습니다(계약 확인 전까지 완료 기능이 아닙니다).
/// 로그아웃·만료·다른 계정으로 로그인하면 이전 세션의 평점은 비웁니다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this._auth) {
    _seenSessionVersion = _auth.sessionVersion;
    _auth.addListener(_onAuthChanged);
  }

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final AuthViewModel _auth;

  /// 같은 movieId는 한 번만 조회합니다. 값이 null이면 TMDB에 없는 영화(404)입니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  late int _seenSessionVersion;
  bool _disposed = false;
  bool _isWriting = false;

  List<RatingWithMovie> ratings = const [];
  String? message;

  // 다중 선택·삭제(Challenge)
  bool isSelectionMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  bool get isEmpty => ratings.isEmpty;

  /// 화면 이탈을 막아야 하는 요청이 진행 중인지 나타냅니다.
  bool get isBusy => isDeletingSelected || _isWriting;

  void _onAuthChanged() {
    final version = _auth.sessionVersion;
    if (version == _seenSessionVersion) return;
    _seenSessionVersion = version;
    // 로그인·로그아웃·만료로 세션이 바뀌면 이전 세션의 평점과 선택 상태를 남기지 않습니다.
    ratings = const [];
    message = null;
    isSelectionMode = false;
    selectedRatingIds.clear();
    _notify();
  }

  /// 영화 상세에서 등록에 성공한 Rating을 목록 맨 앞에 추가합니다.
  /// [movie]를 함께 받으면 TMDB를 다시 조회하지 않고 제목·포스터를 바로 붙입니다.
  void addCreated(RatingDto rating, {TmdbMovieDto? movie}) {
    if (movie != null) _movieCache[movie.id] = movie;
    ratings = [
      RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
      ...ratings.where((entry) => entry.rating.ratingId != rating.ratingId),
    ];
    message = null;
    _notify();
    _fillMissingMovies(); // 캐시에 없는 영화만 조회합니다.
  }

  /// 평점을 수정합니다. comment는 항상 보내므로 null이면 후기를 지우겠다는 뜻입니다.
  /// 실패하면 [RatingWriteException]을 던져 호출부(Dialog)가 처리하게 합니다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) {
    return _write(() async {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        score: score,
        comment: comment,
      );
      _replace(updated); // 응답으로 받은 Rating으로 카드를 갱신합니다. 다시 조회하지 않습니다.
    }, ratingId: ratingId);
  }

  Future<void> deleteRating(int ratingId) {
    return _write(() async {
      await _service.deleteRating(ratingId);
      _remove(ratingId);
    }, ratingId: ratingId);
  }

  Future<void> _write(Future<void> Function() request, {required int ratingId}) async {
    if (_isWriting) return; // 연속 탭 방지
    final version = _auth.sessionVersion;
    _isWriting = true;
    _notify();
    try {
      await request();
      if (version != _auth.sessionVersion) return; // 이미 정리된 세션이면 결과를 반영하지 않습니다.
    } on DioException catch (error) {
      final failure = classifyRatingWriteError(error);
      if (version != _auth.sessionVersion) {
        throw const RatingWriteException('', RatingWriteKind.dismissed);
      }
      if (failure.code == 'RATING404_1') _remove(ratingId); // 서버에 없는 평점은 목록에서도 정리합니다.
      if (failure.kind == RatingWriteKind.dismissed) {
        await _auth.expireSession(fromVersion: version);
      }
      throw failure;
    } finally {
      _isWriting = false;
      _notify();
    }
  }

  void _replace(RatingDto updated) {
    ratings = [
      for (final entry in ratings)
        if (entry.rating.ratingId == updated.ratingId)
          RatingWithMovie(rating: updated, movie: _movieCache[updated.movieId] ?? entry.movie)
        else
          entry,
    ];
    _notify();
  }

  void _remove(int ratingId) {
    ratings = [
      for (final entry in ratings)
        if (entry.rating.ratingId != ratingId) entry,
    ];
    selectedRatingIds.remove(ratingId);
    if (ratings.isEmpty) isSelectionMode = false;
    _notify();
  }

  // ----- 다중 선택(Challenge) -----

  void enterSelectionMode() {
    if (isBusy || isSelectionMode || ratings.isEmpty) return;
    isSelectionMode = true;
    selectedRatingIds.clear();
    _notify();
  }

  void cancelSelectionMode() {
    if (isDeletingSelected) return;
    isSelectionMode = false;
    selectedRatingIds.clear();
    _notify();
  }

  void toggleSelection(int ratingId) {
    if (!isSelectionMode || isDeletingSelected) return;
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    _notify();
  }

  /// 선택한 평점을 순서대로 삭제합니다. 일부만 실패하면 성공한 항목만 선택에서 빠지고,
  /// 실패한 항목은 선택 상태를 유지해 다시 시도할 수 있게 합니다.
  /// 401이면 남은 요청을 멈추고 세션을 정리합니다(로그인 화면은 Router가 보여줍니다).
  Future<DeleteSelectedResult> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) {
      return const DeleteSelectedResult(deleted: 0, failed: 0);
    }
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    _notify();

    var deleted = 0;
    var failed = 0;
    try {
      // 순회 중에 Set을 직접 지우면 오류가 나므로 복사본을 돕니다.
      for (final ratingId in selectedRatingIds.toList()) {
        if (_disposed || version != _auth.sessionVersion) break;
        try {
          await _service.deleteRating(ratingId);
          if (version != _auth.sessionVersion) break;
          _remove(ratingId);
          deleted++;
        } on DioException catch (error) {
          final failure = classifyRatingWriteError(error);
          if (version != _auth.sessionVersion) break;
          if (failure.kind == RatingWriteKind.dismissed) {
            await _auth.expireSession(fromVersion: version);
            break;
          }
          if (failure.code == 'RATING404_1') _remove(ratingId);
          failed++;
          debugPrint('평점 삭제 실패(ratingId=$ratingId, code=${failure.code})');
        } catch (error) {
          failed++;
          debugPrint('평점 삭제 실패(ratingId=$ratingId): ${error.runtimeType}');
        }
      }
    } finally {
      isDeletingSelected = false; // 예상하지 못한 오류에도 로딩을 해제합니다.
      if (failed == 0 && version == _auth.sessionVersion) {
        isSelectionMode = false;
        selectedRatingIds.clear();
      }
      _notify();
    }
    return DeleteSelectedResult(deleted: deleted, failed: failed);
  }

  /// 캐시에 없는 영화만 병렬로 조회합니다. 영화 조회 실패가 평점 목록을 지우지 않습니다.
  /// TMDB 목록에 없는 id여도 평점은 남기고 제목 자리에 `영화 #{id}`를 표시합니다.
  Future<void> _fillMissingMovies() async {
    final version = _auth.sessionVersion;
    final missing = ratings
        .map((entry) => entry.rating.movieId)
        .toSet()
        .where((id) => !_movieCache.containsKey(id));
    if (missing.isEmpty) return;

    await Future.wait([
      for (final id in missing)
        () async {
          try {
            _movieCache[id] = await _movieService.findMovieById(id);
          } on DioException {
            // 일시적인 네트워크 실패는 캐시하지 않습니다. 다음 등록 때 다시 시도합니다.
          }
        }(),
    ]);
    if (_disposed || version != _auth.sessionVersion) return;

    var missingMovies = 0;
    ratings = [
      for (final entry in ratings)
        RatingWithMovie(rating: entry.rating, movie: _movieCache[entry.rating.movieId] ?? entry.movie),
    ];
    for (final entry in ratings) {
      if (entry.movie == null) missingMovies++;
    }
    message = missingMovies > 0 ? missingMovieMessage : null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
