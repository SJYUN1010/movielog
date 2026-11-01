import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/models/rating_with_movie.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';

/// 6주차 조회 대상은 로그인한 본인이 아니라 학습용 memberId 1의 공개 데이터입니다.
/// Empty(3)나 404(4)를 확인할 때만 `--dart-define=SAMPLE_MEMBER_ID=3`처럼 바꿉니다.
const int sampleMemberId = int.fromEnvironment('SAMPLE_MEMBER_ID', defaultValue: 1);

const missingMovieMessage = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
const ratingsLoadFailedMessage = '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;

  /// 같은 movieId는 한 번만 조회합니다. 값이 null이면 TMDB에 없는 영화(404)입니다.
  final Map<int, TmdbMovieDto?> _movieCache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  bool get isLoading => status == MyRatingsLoadStatus.loading;

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
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      if (missingMovies > 0) message = missingMovieMessage;
    } on DioException catch (error) {
      if (_isStale(version)) return;
      debugPrint('평점 조회 실패: ${error.requestOptions.uri} (${error.message})');
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    } catch (error) {
      if (_isStale(version)) return;
      debugPrint('평점 응답 처리 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = ratingsLoadFailedMessage;
    }
    _notify();
  }

  Future<void> retry() => load();

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
