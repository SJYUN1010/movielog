import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 영화 목록 요청이 실패했을 때 띄우는 재시도 Dialog입니다.
/// "다시 시도"는 true, "취소"는 false를 돌려줍니다.
class MovieListRetryDialog extends StatelessWidget {
  const MovieListRetryDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.33),
      builder: (context) => const MovieListRetryDialog(),
    );
    return retry ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.softViolet,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, size: 32, color: AppColors.violet),
            ),
            const SizedBox(height: 8),
            const Text('영화를 불러오지 못했어요', style: _titleStyle),
            const SizedBox(height: 13),
            const Text(
              '네트워크 상태를 확인하고\n다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: _bodyStyle,
            ),
            const SizedBox(height: 38),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: '취소',
                    background: AppColors.cancelFill,
                    foreground: AppColors.violet,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: _DialogButton(
                    label: '다시 시도',
                    background: AppColors.violet,
                    foreground: AppColors.white,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // W5-01 Figma: 제목 20 / Bold, 본문 14 / Regular, 버튼 15 / Bold.
  static const _titleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 27 / 20,
    color: AppColors.black,
  );

  static const _bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 19 / 14,
    color: AppColors.commentText,
  );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
