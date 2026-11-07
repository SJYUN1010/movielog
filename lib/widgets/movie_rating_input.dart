import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../theme/app_colors.dart';

/// 서버 연동용 별점 입력입니다. v6의 score는 1~5 정수이므로 반 점 입력을 막고
/// 별 한 개 단위로만 선택하게 합니다.
///
/// `rating`과 `onChanged`는 여전히 double입니다. RatingBar는 항상 double로 값을 돌려주므로
/// 선택된 값은 1.0, 2.0처럼 정수를 나타내는 double이고, 요청 전에 validateServerScore로 한 번 더 검사합니다.
class MovieRatingInput extends StatelessWidget {
  const MovieRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.enabled = true,
  });

  final double rating;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// W7-01 Figma: 별 5개가 폭 176(별 31 + 좌우 2씩)을 차지합니다.
  static const starSize = 31.0;

  @override
  Widget build(BuildContext context) {
    return RatingBar(
      initialRating: rating,
      minRating: 1,
      allowHalfRating: false,
      ignoreGestures: !enabled,
      itemCount: 5,
      itemSize: starSize,
      glow: false,
      itemPadding: const EdgeInsets.symmetric(horizontal: 2),
      ratingWidget: RatingWidget(
        full: const Icon(Icons.star, color: AppColors.violet),
        half: const Icon(Icons.star_half, color: AppColors.violet),
        empty: const Icon(Icons.star_border, color: AppColors.violet),
      ),
      onRatingUpdate: onChanged,
    );
  }
}
