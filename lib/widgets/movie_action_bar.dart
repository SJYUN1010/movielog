import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MovieActionBar extends StatelessWidget {
  const MovieActionBar({
    super.key,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onRatePressed,
  });

  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onRatePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    color: AppColors.violet,
                  ),
                  label: const Text('즐겨찾기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.violet,
                    side: const BorderSide(color: AppColors.violet),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRatePressed,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('평점 남기기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
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
