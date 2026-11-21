import 'package:flutter/material.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import 'tmdb_poster_image.dart';

/// 내 즐겨찾기·검색 결과에 쓰는 가로 영화 카드입니다(W9 Figma: 테두리 카드, 왼쪽 포스터, 제목·부가 정보).
///
/// 영화 정보를 가져오지 못한 카드(`movie == null`)는 포스터 자리에 placeholder, 제목에 `영화 #{movieId}`,
/// 그리고 그 카드만 다시 조회하는 버튼([onRetryInfo])을 보여줍니다.
class MovieListTile extends StatelessWidget {
  const MovieListTile({
    super.key,
    required this.movieId,
    this.movie,
    this.label,
    this.onTap,
    this.onRetryInfo,
  });

  final int movieId;
  final TmdbMovieDto? movie;

  /// 제목 아래 보라색 강조 문구입니다(예: "즐겨찾기한 영화").
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onRetryInfo;

  static const _titleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 24 / 17,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _metaStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.commentText,
  );

  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.violet,
  );

  String _meta(TmdbMovieDto movie) {
    final year = movie.releaseYear?.toString();
    final rating = movie.voteCount > 0 ? '★ ${movie.fiveStarRating.toStringAsFixed(1)}' : null;
    final text = [year, rating].whereType<String>().join(' · ');
    return text.isEmpty ? '개봉 정보 없음' : text;
  }

  @override
  Widget build(BuildContext context) {
    final movie = this.movie;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: movie == null ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 78,
                height: 116,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: movie == null
                      ? const ColoredBox(color: AppColors.editFill)
                      : TmdbPosterImage(posterPath: movie.posterPath),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie?.title ?? '영화 #$movieId',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        movie == null ? '영화 정보를 불러오지 못했습니다.' : _meta(movie),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _metaStyle,
                      ),
                      if (label != null) ...[
                        const SizedBox(height: 8),
                        Text(label!, style: _labelStyle),
                      ],
                      if (movie == null && onRetryInfo != null) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: onRetryInfo,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('정보 다시 불러오기', style: _labelStyle),
                          ),
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
