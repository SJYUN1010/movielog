import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 기본 · 통신 중 · 비활성 세 상태를 하나로 표현하는 공용 버튼입니다.
///
/// 상태는 화면(ViewModel)이 정해서 넘기고, 버튼은 표시만 합니다.
/// - [onPressed]가 null이면 비활성입니다.
/// - [isLoading]이 true이면 [onPressed]와 관계없이 비활성이며 중앙에 인디케이터만 그립니다.
/// - [width]가 null이면 내용 기반, `double.infinity`면 부모가 허용하는 최대 너비, 숫자면 고정 너비입니다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.labelStyle,
  });

  static const height = 44.0;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final TextStyle? labelStyle;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: AppColors.white,
          // 통신 중에는 회색, 조건 미충족일 때는 연한 보라로 구분합니다.
          disabledBackgroundColor: isLoading
              ? AppColors.gray
              : AppColors.buttonDisabled,
          disabledForegroundColor: AppColors.white,
          elevation: 0,
          // 13px Bold "중복 확인"(글자 51)이 Figma의 버튼 너비 102가 되도록 좌우 25.5씩 둡니다.
          padding: const EdgeInsets.symmetric(horizontal: 25.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              labelStyle ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 19 / 14,
                letterSpacing: 0,
              ),
        ),
        // 통신 중에는 label과 인디케이터를 동시에 그리지 않고 하나만 그립니다.
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
