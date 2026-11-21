import 'package:flutter/material.dart';

import '../theme/app_colors.dart';


/// 영화 상세 하단의 "평점 남기기" 바입니다. 즐겨찾기는 제목 옆 `FavoriteButton`으로 옮겨졌습니다.
class MovieActionBar extends StatelessWidget {
  const MovieActionBar({super.key, required this.onRatePressed});

  /// null이면 "평점 남기기" 버튼을 비활성화합니다.
  final VoidCallback? onRatePressed;

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
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRatePressed,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('평점 남기기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.buttonDisabled,
                disabledForegroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
