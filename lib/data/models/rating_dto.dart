/// v7 평점 응답 객체(`RatingResponse`)입니다. 등록·수정의 result와 유저별 평점 조회 배열의 항목에 씁니다.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  factory RatingDto.fromJson(Map<String, dynamic> json) {
    final updated = json['updatedAt'];
    return RatingDto(
      ratingId: (json['ratingId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: updated is String ? DateTime.parse(updated) : null,
    );
  }

  final int ratingId;

  /// TMDB 영화 id입니다. 영화 목록의 index가 아닙니다.
  final int movieId;
  final int score;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
}
