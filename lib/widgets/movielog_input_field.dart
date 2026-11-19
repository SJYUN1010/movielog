import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 로그인·프로필 수정 화면의 입력창입니다(W8 Figma). 회원가입 입력창과 달리 라벨이 작고 입력창은 높이 50입니다.
///
/// 오류는 입력창 아래 한 줄([errorText])로 보여주고, 오류가 있으면 테두리도 붉게 바뀝니다.
/// [readOnlyStyle]은 이메일처럼 수정할 수 없는 값을 회색 배경으로 표시합니다.
class MovieLogInputField extends StatelessWidget {
  const MovieLogInputField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.enabled = true,
    this.readOnlyStyle = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.showCounter = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool readOnlyStyle;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;

  /// true이면 입력창 아래 오른쪽에 `현재 / 최대` 글자 수를 보여줍니다.
  final bool showCounter;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  static const fieldHeight = 50.0;

  // W8 Figma: 라벨 12 / Regular, 입력 14 / Regular, 오류·글자 수 11 / Regular.
  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.commentText,
  );

  static const _inputStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 19 / 14,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _smallStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 15 / 11,
    letterSpacing: 0,
  );

  static const _errorBorderColor = Color(0xFFD8918B);

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final borderColor = hasError ? _errorBorderColor : AppColors.cardBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        SizedBox(
          height: fieldHeight,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled && !readOnlyStyle,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLength: maxLength,
            autofillHints: autofillHints,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: AppColors.violet,
            style: readOnlyStyle
                ? _inputStyle.copyWith(color: AppColors.commentText)
                : _inputStyle,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                null,
            decoration: InputDecoration(
              filled: true,
              fillColor: readOnlyStyle ? const Color(0xFFF0EDF2) : AppColors.white,
              hintText: hint,
              hintStyle: _inputStyle.copyWith(color: AppColors.fieldHint),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: _border(borderColor),
              enabledBorder: _border(borderColor),
              disabledBorder: _border(borderColor),
              focusedBorder: _border(hasError ? _errorBorderColor : AppColors.violet),
            ),
          ),
        ),
        // 오류 문구가 나타나도 아래 레이아웃이 움직이지 않도록 한 줄을 항상 확보합니다.
        SizedBox(
          height: 24,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    errorText ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _smallStyle.copyWith(color: AppColors.error),
                  ),
                ),
                if (showCounter && maxLength != null)
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => Text(
                      '${controller.text.characters.length} / $maxLength',
                      style: _smallStyle.copyWith(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
