import 'package:flutter/material.dart';

import '../data/models/rating_with_movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'tmdb_poster_image.dart';

/// 평점 한 건과 그 영화의 TMDB 제목·포스터를 보여주는 카드입니다.
///
/// [onEdit]과 [onDelete]가 있으면 오른쪽에 수정·삭제 버튼을 그립니다.
/// 이 화면의 평점은 모두 현재 학습용 회원이 작성한 것이라 본인 평점에만 버튼이 나타납니다.
class RatingCard extends StatelessWidget {
  const RatingCard({super.key, required this.entry, this.onEdit, this.onDelete});

  final RatingWithMovie entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                      if (onEdit == null && onDelete == null) ...[
                        const Spacer(),
                        const SizedBox(width: 8),
                        Text(formatRatingDate(rating.createdAt), style: _dateStyle),
                      ],
                    ],
                  ),
                  // comment가 null이면 빈 줄을 만들지 않고 표시하지 않습니다.
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis, style: _commentStyle),
                  ],
                  if (movie == null) ...[
                    const SizedBox(height: 12),
                    const Text('포스터 정보 없음', style: _commentStyle),
                  ],
                ],
              ),
            ),
          ),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Column(
                children: [
                  if (onEdit != null)
                    _CardActionButton(
                      label: '수정',
                      background: AppColors.editFill,
                      foreground: AppColors.violet,
                      onPressed: onEdit!,
                    ),
                  if (onEdit != null && onDelete != null) const SizedBox(height: 8),
                  if (onDelete != null)
                    _CardActionButton(
                      label: '삭제',
                      background: AppColors.deleteFill,
                      foreground: AppColors.error,
                      onPressed: onDelete!,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // W6-02 / W7-REQ Figma: 제목 17 / Bold, 별점 14 / Bold, 후기 13 / Regular.
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

/// 수정·삭제 버튼입니다. W7-REQ Figma: 63×35, 글자 13 / Bold.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 63,
      height: 35,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 18 / 13,
            letterSpacing: 0,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// 다중 선택 모드의 카드입니다. 수정·삭제 버튼 대신 체크박스를 보여줍니다.
/// W7-CH Figma: 350×128, 제목 17 / Bold(`영화 A · 별점 5`), 후기 13 / Regular.
class RatingSelectCard extends StatelessWidget {
  const RatingSelectCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  final RatingWithMovie entry;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final rating = entry.rating;
    final title = entry.movie?.title ?? '영화 #${rating.movieId}';
    final comment = rating.comment;

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: SizedBox(
          height: 128,
          child: Row(
            children: [
              const SizedBox(width: 16),
              _SelectBox(selected: selected),
              const SizedBox(width: 21),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 26, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$title · 별점 ${rating.score}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RatingCard._titleStyle,
                      ),
                      if (comment != null && comment.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          comment,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RatingCard._commentStyle,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: selected ? AppColors.violet : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: selected ? null : Border.all(color: AppColors.gray, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check, size: 18, color: AppColors.white)
          : null,
    );
  }
}

/// 등록일을 `2026.10.31` 형태로 보여줍니다. 서버가 UTC로 내려주므로 기기 시간대로 바꿉니다.
String formatRatingDate(DateTime createdAt) {
  final local = createdAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}
