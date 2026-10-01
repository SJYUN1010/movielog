import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../movie.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class HeroMovieCard extends StatelessWidget {
  const HeroMovieCard({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(movie.posterAsset, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.4, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 9.5, 12, 6.5),
                    decoration: BoxDecoration(
                      color: AppColors.violetDark.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Text('추천 신작', style: AppTextStyles.badgeLabel),
                  ),
                  const SizedBox(height: 12),
                  Text(movie.title, style: AppTextStyles.heroTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.genreLabel} · ${movie.runtimeMinutes}분',
                    style: AppTextStyles.heroSubtitle,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/movies/${movie.id}'),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('상세보기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.violet,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      textStyle: AppTextStyles.buttonLabel.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
