import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 기본 · 통신 중 · 비활성 세 상태를 하나로 표현하는 공용 버튼입니다.
///
/// 상태는 화면(ViewModel)이 정해서 넘기고, 버튼은 표시만 합니다.
/// - [onPressed]가 null이면 비활성입니다.
/// - [isLoading]이 true이면 [onPressed]와 관계없이 비활성이며 중앙에 인디케이터만 그립니다.
/// - [width]가 null이면 내용 기반, `double.infinity`면 부모 최대 너비, 숫자면 고정 너비입니다.
/// - [backgroundColor]·[foregroundColor]를 넘기면 보조(예: 취소) 버튼처럼 색만 바꿔 쓸 수 있습니다.
class MovieLogButton extends StatelessWidget {
  const MovieLogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.labelStyle,
    this.buttonHeight = height,
    this.borderRadius = 12,
    this.backgroundColor,
    this.foregroundColor,
  });

  static const height = 44.0;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final TextStyle? labelStyle;
  final double buttonHeight;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  bool get _disabled => isLoading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final background = backgroundColor ?? AppColors.violet;
    final foreground = foregroundColor ?? AppColors.white;

    return SizedBox(
      width: width,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: _disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          // 통신 중에는 회색, 조건 미충족일 때는 연한 보라로 구분합니다.
          // 색을 직접 지정한 보조 버튼은 비활성이어도 같은 색을 유지합니다.
          disabledBackgroundColor:
              backgroundColor ?? (isLoading ? AppColors.gray : AppColors.buttonDisabled),
          disabledForegroundColor: foreground,
          elevation: 0,
          // 13px Bold "중복 확인"(글자 51)이 Figma의 버튼 너비 102가 되도록 좌우 25.5씩 둡니다.
          padding: const EdgeInsets.symmetric(horizontal: 25.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
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
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Text(label),
      ),
    );
  }
}
