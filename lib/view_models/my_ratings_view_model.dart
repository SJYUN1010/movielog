import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

const missingMovieMessage = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
const ratingsLoadFailedMessage = '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
const refreshAfterWriteFailedMessage = '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

/// 다중 삭제 결과입니다.
class DeleteSelectedResult {
  const DeleteSelectedResult({required this.deleted, required this.failed});

  final int deleted;
  final int failed;

  bool get hasPartialFailure => failed > 0;
}

/// 마이페이지의 "내가 등록한 평점" 화면 ViewModel입니다. 조회·수정·삭제를 맡습니다.
/// 조회 대상 [memberId]는 회원가입 결과로 받은 학습용 식별자입니다(인증이 아닙니다).
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  /// 같은 movieId는 한 번만 조회합니다. 값이 null이면 TMDB에 없는 영화(404)입니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;
  bool _isWriting = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  /// 저장은 성공했는데 목록 재조회(GET)만 실패했을 때의 안내입니다.
  /// 이 경우 다시 시도해야 하는 것은 저장이 아니라 조회뿐입니다.
  String? refreshWarning;

  // 다중 선택·삭제(Challenge)
  bool isSelectionMode = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  bool get isLoading => status == MyRatingsLoadStatus.loading;

  /// 화면 이탈을 막아야 하는 요청이 진행 중인지 나타냅니다.
  bool get isBusy => isDeletingSelected || _isWriting;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    _notify();

    try {
      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      await _loadMissingMovies(rawRatings.map((rating) => rating.movieId));
      if (_isStale(version)) return;

      var missingMovies = 0;
      final entries = <RatingWithMovie>[];
      for (final rating in rawRatings) {
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      ratings = entries;
      // 서버에서 사라진 평점이 선택 상태에 남지 않게 정리합니다.
      selectedRatingIds.removeWhere(
        (id) => !entries.any((entry) => entry.rating.ratingId == id),
      );
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      refreshWarning = null;
      if (entries.isEmpty) isSelectionMode = false;
      if (missingMovies > 0) message = missingMovieMessage;
    } on DioException catch (error) {
      if (_isStale(version)) return;
      debugPrint('평점 조회 실패: ${error.requestOptions.uri} (${error.message})');
      status = MyRatingsLoadStatus.error;
      message = writeErrorMessage(error, fallback: ratingsLoadFailedMessage);
    } catch (error) {
      if (_isStale(version)) return;
      debugPrint('평점 응답 처리 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = ratingsLoadFailedMessage;
    }
    _notify();
  }

  /// 조회만 다시 시도합니다. 쓰기 요청은 다시 보내지 않습니다.
  Future<void> retry() => load();

  /// 평점을 수정합니다. comment는 항상 보내므로 null이면 후기를 지우겠다는 뜻입니다.
  /// 쓰기 실패는 호출부(Dialog)가 처리하도록 다시 던지고, 저장 뒤 재조회 실패는 던지지 않습니다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) {
    return _write(
      () => _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        score: score,
        comment: comment,
      ),
    );
  }

  Future<void> deleteRating(int ratingId) {
    return _write(
      () => _service.deleteRating(memberId: memberId, ratingId: ratingId),
    );
  }

  Future<void> _write(Future<void> Function() request) async {
    if (_isWriting) return; // 연속 탭 방지
    _isWriting = true;
    _notify();
    try {
      await request();
    } on DioException catch (error) {
      _isWriting = false;
      _notify();
      // 403·404는 화면의 목록이 서버와 어긋났다는 뜻이라 다시 조회해 맞춥니다.
      if (shouldRefreshAfterRatingError(error) && !_disposed) await load();
      rethrow;
    } catch (_) {
      _isWriting = false;
      _notify();
      rethrow;
    }
    _isWriting = false;
    _notify();
    if (_disposed) return;
    await _refreshAfterWrite(); // GET 실패는 저장 실패로 다시 던지지 않습니다.
  }

  Future<void> _refreshAfterWrite() async {
    await load();
    if (_disposed) return;
    if (status == MyRatingsLoadStatus.error) {
      refreshWarning = refreshAfterWriteFailedMessage;
      _notify();
    }
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
  Future<DeleteSelectedResult> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) {
      return const DeleteSelectedResult(deleted: 0, failed: 0);
    }
    isDeletingSelected = true;
    _notify();

    var deleted = 0;
    var failed = 0;
    try {
      // 순회 중에 Set을 직접 지우면 오류가 나므로 복사본을 돕니다.
      for (final ratingId in selectedRatingIds.toList()) {
        if (_disposed) break;
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
          deleted++;
        } catch (error) {
          failed++;
          debugPrint('평점 삭제 실패(ratingId=$ratingId): ${error.runtimeType}');
        }
      }
    } finally {
      isDeletingSelected = false; // 예상하지 못한 오류에도 로딩을 해제합니다.
      _notify();
    }

    if (_disposed) return DeleteSelectedResult(deleted: deleted, failed: failed);
    await _refreshAfterWrite();
    if (failed == 0) {
      isSelectionMode = false;
      selectedRatingIds.clear();
    }
    _notify();
    return DeleteSelectedResult(deleted: deleted, failed: failed);
  }

  /// 캐시에 없는 영화만 병렬로 조회합니다. 영화 조회 실패가 평점 목록을 지우지 않습니다.
  Future<void> _loadMissingMovies(Iterable<int> movieIds) async {
    final missing = movieIds.toSet().where((id) => !_movieCache.containsKey(id));
    await Future.wait([
      for (final id in missing)
        () async {
          try {
            _movieCache[id] = await _movieService.findMovieById(id);
          } on DioException {
            // 일시적인 네트워크 실패는 캐시하지 않습니다. 다음 로딩에서 다시 시도합니다.
          }
        }(),
    ]);
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
