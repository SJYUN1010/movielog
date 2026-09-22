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

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 4),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final hasInput = controller.text.isNotEmpty;
            final hasError = hasInput && validator(controller.text) != null;

            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: validator,
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
                errorStyle: AppTextStyles.errorText,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                suffixIcon: hasInput
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
                border: _border(AppColors.outline),
                enabledBorder: _border(AppColors.outline),
                focusedBorder: _border(AppColors.violet, width: 2),
                errorBorder: _border(AppColors.error),
                focusedErrorBorder: _border(AppColors.error, width: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
