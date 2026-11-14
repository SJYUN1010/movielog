import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import 'auth_view_model.dart';
import 'my_ratings_view_model.dart';
import 'rating_write_exception.dart';
import 'sign_up_view_model.dart' show SubmitStatus;

export 'sign_up_view_model.dart' show SubmitStatus;

/// 영화 상세 화면의 영화 DTO와 평점 등록 상태를 관리합니다.
/// 평점 등록은 로그인한 토큰으로 보냅니다. 요청에 memberId를 넣지 않습니다.
/// 조회·수정·삭제는 마이페이지의 "내가 등록한 평점" 화면에서만 합니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this._auth, this._myRatings, this.movie);

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final MyRatingsViewModel _myRatings;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 이 화면에서 마지막으로 등록에 성공한 별점입니다. 서버 목록을 대신하지 않는 표시용 값입니다.
  int? lastCreatedScore;

  bool _disposed = false;

  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  /// 등록에 성공하면 응답으로 받은 Rating을 "내가 등록한 평점"에 추가합니다.
  /// 실패하면 [RatingWriteException]을 던집니다(Dialog가 종류에 맞게 보여줍니다).
  Future<void> createRating({required int score, String? comment}) async {
    // 저장 중에는 다시 보내지 않습니다(연속 탭 방지).
    if (submitStatus == SubmitStatus.submitting) return;

    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      final created = await _ratingService.createRating(
        CreateRatingRequest(
          movieId: movie.id, // 영화 배열 index가 아니라 TMDB id입니다.
          score: score,
          comment: comment,
        ),
      );
      if (version != _auth.sessionVersion) {
        // 응답이 오는 사이 로그아웃·계정 전환이 있었으면 이전 세션의 결과를 반영하지 않습니다.
        _finish(SubmitStatus.idle);
        throw const RatingWriteException('', RatingWriteKind.dismissed);
      }
      _myRatings.addCreated(created, movie: movie);
      lastCreatedScore = created.score;
      _finish(SubmitStatus.success);
    } on DioException catch (error) {
      final failure = classifyRatingWriteError(error);
      if (version != _auth.sessionVersion) {
        _finish(SubmitStatus.idle);
        throw const RatingWriteException('', RatingWriteKind.dismissed);
      }
      if (failure.kind == RatingWriteKind.dismissed) {
        await _auth.expireSession(fromVersion: version);
      }
      _finish(SubmitStatus.error, message: failure.message);
      throw failure;
    } on RatingWriteException {
      rethrow;
    } catch (error) {
      debugPrint('평점 등록 결과 처리 실패: ${error.runtimeType}');
      const message = '평점 등록 결과를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      _finish(SubmitStatus.error, message: message);
      throw const RatingWriteException(message, RatingWriteKind.inline);
    }
  }

  void _finish(SubmitStatus status, {String? message}) {
    submitStatus = status;
    submitMessage = message;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
