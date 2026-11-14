import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// [child] 위에 어두운 ModalBarrier와 중앙 흰색 인디케이터만 올리는 로딩 오버레이입니다.
/// 흰색 카드나 로딩 문구는 띄우지 않고, 완료 전에는 아래 화면을 누를 수 없습니다.
/// (W7-05 Figma: 다중 삭제 중 Stack 인디케이터)
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) const Positioned.fill(child: ModalBarrier(dismissible: false, color: Colors.black45)),
        if (isLoading)
          const Center(
            child: SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.white),
            ),
          ),
      ],
    );
  }
}
