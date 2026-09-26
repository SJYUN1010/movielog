import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/movies/${movie.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(movie.posterAsset, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _RatingBadge(rating: movie.rating),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionHeading,
          ),
          const SizedBox(height: 2),
          Text(
            '${movie.genreLabel} · ${movie.year}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.ratingCaption,
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.violetDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.ratingBadgeText),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1), style: AppTextStyles.ratingBadge),
        ],
      ),
    );
  }
}
