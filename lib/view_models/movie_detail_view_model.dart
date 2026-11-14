import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/models/rating_request.dart';
import '../data/services/rating_api_service.dart';
import 'sign_up_view_model.dart' show SubmitStatus;

export 'sign_up_view_model.dart' show SubmitStatus;

const signUpRequiredMessage = '먼저 회원가입을 완료해 주세요.';

/// 영화 상세 화면의 영화 DTO와 평점 등록 상태를 관리합니다.
/// 조회·수정·삭제는 마이페이지의 "내가 등록한 평점" 화면에서만 합니다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);

  final RatingApiService _ratingService;

  /// 학습용 현재 회원입니다. 로그인 인증이 아니라 가입 결과로 받은 식별자일 뿐입니다.
  final int? memberId;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;

  /// 이 화면에서 마지막으로 등록에 성공한 별점입니다. 서버 목록을 대신하지 않는 표시용 값입니다.
  int? lastCreatedScore;

  bool _disposed = false;

  bool get canRate => memberId != null;
  bool get isSubmitting => submitStatus == SubmitStatus.submitting;

  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = signUpRequiredMessage;
      notifyListeners();
      return;
    }
    // 저장 중에는 다시 보내지 않습니다(연속 탭 방지).
    if (submitStatus == SubmitStatus.submitting) return;

    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    notifyListeners();

    try {
      await _ratingService.createRating(
        memberId: id,
        request: CreateRatingRequest(
          movieId: movie.id, // 영화 배열 index가 아니라 TMDB id입니다.
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return;
      lastCreatedScore = score;
      submitStatus = SubmitStatus.success;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      submitMessage = writeErrorMessage(error);
    } catch (error) {
      if (_disposed) return;
      debugPrint('평점 등록 결과 처리 실패: ${error.runtimeType}');
      submitStatus = SubmitStatus.error;
      submitMessage = '평점 등록 결과를 확인하지 못했습니다. 마이페이지에서 목록을 확인해 주세요.';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
