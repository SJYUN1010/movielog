import 'package:flutter/material.dart';

import '../data/dto/tmdb_genre_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selectedGenreId,
    required this.onSelected,
    this.enabled = true,
  });

  final List<TmdbGenreDto> genres;
  final int? selectedGenreId;
  final ValueChanged<int?> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final options = <TmdbGenreDto?>[null, ...genres];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = options[index];
          final isSelected = genre?.id == selectedGenreId;

          return GestureDetector(
            onTap: enabled ? () => onSelected(genre?.id) : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.violet : AppColors.chipUnselected,
                  borderRadius: BorderRadius.circular(9999),
                ),
                alignment: Alignment.center,
                child: Text(
                  genre?.name ?? '전체',
                  style: AppTextStyles.chipLabel.copyWith(
                    color: isSelected ? AppColors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
