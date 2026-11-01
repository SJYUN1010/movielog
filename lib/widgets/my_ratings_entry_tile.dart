import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 마이페이지에서 "내가 등록한 평점" 화면으로 들어가는 행입니다.
///
/// W6-ENTRY Figma: 358×64, 테두리 1.5px, 텍스트 16 / Bold, 오른쪽 8×14 화살표(선 2.5px).
class MyRatingsEntryTile extends StatelessWidget {
  const MyRatingsEntryTile({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 22 / 16,
    letterSpacing: 0,
    color: AppColors.black,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.rowBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          height: 64,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 17),
            child: Row(
              children: [
                Expanded(child: Text('내가 등록한 평점', style: _titleStyle)),
                CustomPaint(size: Size(8, 14), painter: _ChevronPainter()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.violet
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(size.width - 1, size.height / 2)
      ..lineTo(1, size.height - 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronPainter oldDelegate) => false;
}
