import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double rating;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return RatingBar(
      initialRating: rating,
      minRating: 0.5,
      allowHalfRating: true,
      updateOnDrag: true,
      glow: false,
      itemSize: 44,
      itemPadding: const EdgeInsets.symmetric(horizontal: 4),
      ratingWidget: RatingWidget(
        full: const Icon(Icons.star_rounded, color: AppColors.violet),
        half: const Icon(Icons.star_half_rounded, color: AppColors.violet),
        empty: const Icon(Icons.star_rounded, color: AppColors.lightViolet),
      ),
      onRatingUpdate: onChanged,
    );
  }
}
