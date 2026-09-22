import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('이미 계정이 있나요?', style: AppTextStyles.bodyDescription),
        TextButton(
          onPressed: onLoginPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.only(left: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('로그인', style: AppTextStyles.linkText),
        ),
      ],
    );
  }
}
