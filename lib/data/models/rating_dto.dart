/// `GET /v5/members/{memberId}/ratings` 응답 배열의 항목입니다.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.movieId,
    required this.score,
    required this.comment,
    required this.createdAt,
  });

  factory RatingDto.fromJson(Map<String, dynamic> json) {
    return RatingDto(
      ratingId: (json['ratingId'] as num).toInt(),
      movieId: (json['movieId'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final int ratingId;
  final int movieId;
  final int score;
  final String? comment;
  final DateTime createdAt;
}
