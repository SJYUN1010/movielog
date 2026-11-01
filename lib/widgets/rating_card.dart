import 'package:flutter/material.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

/// 평점 한 건과 그 영화의 TMDB 제목·포스터를 보여주는 카드입니다.
class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.entry});

  final RatingWithMovie entry;

  static const posterWidth = 82.0;
  static const posterHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final movie = entry.movie;
    final comment = rating.comment;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.cardBorder, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TmdbPosterImage(
              posterPath: movie?.posterPath,
              width: posterWidth,
              height: posterHeight,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie?.title ?? '영화 #${rating.movieId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '별점 ${rating.score} / 5',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _scoreStyle,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 8),
                      Text(formatRatingDate(rating.createdAt), style: _dateStyle),
                    ],
                  ),
                  // comment가 null이면 빈 줄을 만들지 않고 표시하지 않습니다.
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(comment, style: _commentStyle),
                  ],
                  if (movie == null) ...[
                    const SizedBox(height: 12),
                    const Text('포스터 정보 없음', style: _commentStyle),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // W6-02 Figma: 제목 17 / Bold, 별점 14 / Bold, 후기 13 / Regular.
  static const _titleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 23 / 17,
    color: AppColors.black,
  );

  static const _scoreStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 19 / 14,
    color: AppColors.violet,
  );

  static const _commentStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    color: AppColors.commentText,
  );

  static final _dateStyle = AppTextStyles.ratingCaption.copyWith(color: AppColors.gray);
}

/// 등록일을 `2026.10.31` 형태로 보여줍니다. 서버가 UTC로 내려주므로 기기 시간대로 바꿉니다.
String formatRatingDate(DateTime createdAt) {
  final local = createdAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}
