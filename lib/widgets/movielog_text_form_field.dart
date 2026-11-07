import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MovieLogTextFormField extends StatelessWidget {
  const MovieLogTextFormField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.trailing,
    this.serverErrorText,
    this.statusText,
    this.statusColor = AppColors.textMuted,
    this.showCheckWhenValid = true,
    this.reserveMessageSpace = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  /// 입력창 바깥 오른쪽에 놓는 위젯입니다(예: 중복 확인 버튼). 입력창과 8px 간격을 둡니다.
  final Widget? trailing;

  /// 서버가 내려준 결과(예: 중복)로 만든 에러 문구입니다. 형식 검사보다 먼저 보여줍니다.
  final String? serverErrorText;

  /// 에러가 아닌 안내 문구(예: 사용 가능, 확인 중)입니다. 입력창 아래에 표시합니다.
  final String? statusText;
  final Color statusColor;

  /// 입력이 형식 검사를 통과하면 체크 아이콘을 보일지 정합니다.
  /// 서버 확인이 필요한 필드는 확인이 끝났을 때만 true로 넘깁니다.
  final bool showCheckWhenValid;

  /// true이면 안내·에러 문구가 없을 때도 그 자리를 비워 둡니다. 문구가 나타나도 아래 레이아웃이 움직이지 않습니다.
  final bool reserveMessageSpace;

  static const _messageTopGap = 6.0;
  static const _messageHeight = 16.0;

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  String? _validate(String? value) => serverErrorText ?? validator(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildField()),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
        _buildMessage(),
      ],
    );
  }

  /// 입력창 아래 한 줄입니다. 서버 에러 > 형식 에러 > 안내 문구 순서로 보여줍니다.
  Widget _buildMessage() {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final error = _errorOf(controller.text);
        final text = error ?? statusText;
        final color = error != null ? AppColors.error : statusColor;

        if (text == null) {
          return reserveMessageSpace
              ? const SizedBox(height: _messageTopGap + _messageHeight)
              : const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: _messageTopGap),
          child: SizedBox(
            height: _messageHeight,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.errorText.copyWith(color: color),
            ),
          ),
        );
      },
    );
  }

  /// 입력이 있을 때만 에러로 봅니다. 서버가 준 에러가 형식 검사보다 먼저입니다.
  String? _errorOf(String value) {
    if (value.isEmpty) return null;
    return _validate(value);
  }

  Widget _buildField() {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasInput = controller.text.isNotEmpty;
        final hasError = hasInput && _validate(controller.text) != null;
        final showCheck = hasInput && !hasError && showCheckWhenValid;

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: _validate,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          cursorColor: AppColors.violet,
          style: AppTextStyles.inputText,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: hasError ? AppColors.errorFill : AppColors.surfaceLow,
            hintText: hint,
            hintStyle: AppTextStyles.inputHint,
            // 에러 문구는 입력창 아래 고정 칸(_buildMessage)에 그리므로 기본 에러 문구는 숨깁니다.
            errorStyle: const TextStyle(fontSize: 0, height: 0),
            // 14px 글자(19) + 위아래 12.5 = 입력창 높이 44
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12.5,
            ),
            suffixIcon: (hasError || showCheck)
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SvgPicture.asset(
                      hasError
                          ? 'assets/icons/error.svg'
                          : 'assets/icons/check_circle.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        hasError ? AppColors.error : AppColors.violet,
                        BlendMode.srcIn,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(),
            border: _border(hasError ? AppColors.error : AppColors.outline),
            enabledBorder: _border(hasError ? AppColors.error : AppColors.outline),
            focusedBorder: _border(
              hasError ? AppColors.error : AppColors.violet,
              width: 2,
            ),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, width: 2),
          ),
        );
      },
    );
  }
}
