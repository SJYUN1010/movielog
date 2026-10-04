import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieListLoading extends StatelessWidget {
  const MovieListLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.violet),
          SizedBox(height: 16),
          Text('영화를 불러오는 중이에요...', style: AppTextStyles.bodyDescription),
        ],
      ),
    );
  }
}
