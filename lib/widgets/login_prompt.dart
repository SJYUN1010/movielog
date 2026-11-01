import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  // W6-01 Figma: 안내 문구는 14 / Regular, 로그인 링크는 14 / Bold입니다.
  static const _questionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 19 / 14,
    color: AppColors.black,
  );

  static const _linkStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 19 / 14,
    color: AppColors.violet,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('이미 계정이 있나요?', style: _questionStyle),
        TextButton(
          onPressed: onLoginPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.only(left: 16),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('로그인', style: _linkStyle),
        ),
      ],
    );
  }
}
