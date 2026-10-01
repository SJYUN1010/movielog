import 'package:flutter/material.dart';

import '../movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PopularMovieCard extends StatelessWidget {
  const PopularMovieCard({super.key, required this.entry});

  final PopularEntry entry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            height: 200,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    entry.posterAsset,
                    width: 140,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.violet,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.rank}',
                      style: AppTextStyles.ratingBadge.copyWith(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionHeading,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 14, color: AppColors.violet),
              const SizedBox(width: 2),
              Text(entry.rating.toStringAsFixed(1), style: AppTextStyles.ratingCaption),
            ],
          ),
        ],
      ),
    );
  }
}
