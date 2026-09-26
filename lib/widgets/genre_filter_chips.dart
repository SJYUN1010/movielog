import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class GenreFilterChips extends StatelessWidget {
  const GenreFilterChips({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  static const all = '전체';

  final List<String> genres;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = [all, ...genres];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = options[index];
          final isSelected = genre == selected;

          return GestureDetector(
            onTap: () => onSelected(genre),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.violet : AppColors.chipUnselected,
                borderRadius: BorderRadius.circular(9999),
              ),
              alignment: Alignment.center,
              child: Text(
                genre,
                style: AppTextStyles.chipLabel.copyWith(
                  color: isSelected ? AppColors.white : AppColors.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
