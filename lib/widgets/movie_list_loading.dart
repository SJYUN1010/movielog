import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key, this.message = '영화를 불러오는 중이에요...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.violet),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.bodyDescription),
        ],
      ),
    );
  }
}
