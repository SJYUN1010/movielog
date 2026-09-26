import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'movie_rating_input.dart';

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, this.initialRating = 0});

  final double initialRating;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating = widget.initialRating;
  bool _hasSelected = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('영화는 어떠셨나요?', style: AppTextStyles.dialogTitle),
            const SizedBox(height: 16),
            MovieRatingInput(
              rating: _rating,
              onChanged: (value) {
                setState(() {
                  _rating = value;
                  _hasSelected = true;
                });
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: _hasSelected
                  ? TextButton(
                      onPressed: () => setState(() {
                        _rating = 0;
                        _hasSelected = false;
                      }),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('다시 선택하기', style: AppTextStyles.linkText),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasSelected
                    ? () => Navigator.of(context).pop(_rating)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.buttonDisabled,
                  disabledForegroundColor: AppColors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
