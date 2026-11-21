import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'movielog_button.dart';

/// 빈 결과·조회 오류처럼 화면 가운데에 안내 문구(와 다시 시도 버튼)를 보여줍니다(W9 Figma).
class CenterMessage extends StatelessWidget {
  const CenterMessage({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  static const _subtitleStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 36, color: AppColors.violet),
              const SizedBox(height: 22),
            ],
            Text(title, textAlign: TextAlign.center, style: _titleStyle),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(subtitle!, textAlign: TextAlign.center, style: _subtitleStyle),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 28),
              MovieLogButton(label: actionLabel!, width: 222, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
