/// 서버 평점은 1~5 사이의 정수입니다. 반 점 입력을 조용히 toInt()로 바꾸지 않고,
/// 위젯이 정수 단위로 막아 준 뒤에도 남겨 두는 안전장치로 검사합니다.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

/// `POST /v6/members/{memberId}/ratings` 요청 body입니다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  /// 영화 배열의 index나 임의 번호가 아니라 TMDB 영화 id(`TmdbMovieDto.id`)입니다.
  final int movieId;
  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {
    'movieId': movieId,
    'score': score,
    // 등록 comment는 선택 항목이라 빈 문자열 대신 생략합니다.
    if (comment != null && comment!.trim().isNotEmpty) 'comment': comment!.trim(),
  };
}
