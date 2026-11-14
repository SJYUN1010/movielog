import 'package:flutter/material.dart';

import '../data/models/rating_request.dart';
import '../theme/app_colors.dart';
import 'movie_rating_input.dart';
import 'movielog_button.dart';
import 'rating_write_guard.dart';

/// 별점과 코멘트를 입력받아 저장까지 마치는 Dialog입니다. 등록과 수정에 같이 씁니다.
///
/// 저장은 [onSubmit]에서 실행합니다.
/// - 예외 없이 끝나면 `true`를 돌려주며 닫힙니다.
/// - 실패하면 Dialog는 열린 채로 입력을 보존하고 오류 문구를 보여줍니다.
/// - 취소를 누르면 [onSubmit]을 호출하지 않고 `false`를 돌려줍니다.
/// 저장 중에는 PopScope로 뒤로가기를 막고, 호출부에서 `barrierDismissible: false`로 바깥 탭도 막습니다.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.onSubmit,
    this.initialScore = 0,
    this.initialComment,
    this.title = '평점을 남겨주세요',
  });

  final Future<void> Function(int score, String? comment) onSubmit;

  /// 수정할 때 서버에 저장된 값으로 채웁니다. comment가 null이면 빈 칸으로 시작합니다.
  final int initialScore;
  final String? initialComment;
  final String title;

  static const commentMaxLength = 500;

  /// 저장 성공 true, 취소 false, 아무 동작 없이 닫힘 null입니다.
  static Future<bool?> show(
    BuildContext context, {
    required Future<void> Function(int score, String? comment) onSubmit,
    int initialScore = 0,
    String? initialComment,
    String title = '평점을 남겨주세요',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // 저장 중 바깥 탭으로 닫히는 것도 막습니다.
      barrierColor: Colors.black.withValues(alpha: 0.33),
      builder: (_) => RatingDialog(
        onSubmit: onSubmit,
        initialScore: initialScore,
        initialComment: initialComment,
        title: title,
      ),
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _score = widget.initialScore.toDouble();
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialComment ?? '',
  );
  bool _isSubmitting = false;
  String? _errorMessage;

  /// 별점을 선택해야 확인할 수 있습니다. 코멘트만 입력해서는 활성화되지 않습니다.
  bool get _canSubmit => _score > 0 && !_isSubmitting;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final score = validateServerScore(_score);
    final trimmed = _commentController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(score, trimmed.isEmpty ? null : trimmed);
      if (!mounted) return;
      popDialogIfActive(context, true);
    } catch (error) {
      // 실패해도 입력(별점·코멘트)은 그대로 두고, 버튼이 로딩 상태로 남지 않게 풉니다.
      if (!mounted) return;
      if (error is RatingDialogDismiss) {
        // 403·409처럼 Snackbar로 안내하거나 세션이 만료된 경우에는 Dialog를 닫습니다.
        popDialogIfActive(context, false);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = error is StateError ? error.message : '저장에 실패했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 33, 17, 38),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, textAlign: TextAlign.center, style: _titleStyle),
              const SizedBox(height: 14),
              Center(
                child: MovieRatingInput(
                  rating: _score,
                  enabled: !_isSubmitting,
                  onChanged: (value) => setState(() => _score = value),
                ),
              ),
              const SizedBox(height: 27),
              const Padding(
                padding: EdgeInsets.only(left: 3),
                child: Text('코멘트 (선택, 최대 500자)', style: _labelStyle),
              ),
              const SizedBox(height: 13),
              SizedBox(height: 105, child: _buildCommentField()),
              // 저장 실패 문구가 나타나도 아래 버튼이 움직이지 않도록 고정 높이로 둡니다.
              SizedBox(
                height: 34,
                child: Padding(
                  padding: const EdgeInsets.only(left: 3, top: 8),
                  child: Text(
                    _errorMessage ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _errorStyle,
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 3),
                  Expanded(
                    child: MovieLogButton(
                      label: '취소',
                      buttonHeight: 46,
                      borderRadius: 23,
                      backgroundColor: AppColors.softViolet,
                      foregroundColor: AppColors.violet,
                      labelStyle: _buttonStyle,
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: MovieLogButton(
                      label: '확인',
                      buttonHeight: 46,
                      borderRadius: 23,
                      labelStyle: _buttonStyle,
                      isLoading: _isSubmitting,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 2),
    );

    return TextField(
      controller: _commentController,
      enabled: !_isSubmitting,
      expands: true,
      maxLines: null,
      minLines: null,
      maxLength: RatingDialog.commentMaxLength,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
          null,
      textAlignVertical: TextAlignVertical.top,
      cursorColor: AppColors.violet,
      style: _inputStyle,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.commentFill,
        hintText: '이 영화의 인상적인 장면은...',
        hintStyle: _inputHintStyle,
        contentPadding: const EdgeInsets.fromLTRB(11, 16, 11, 16),
        border: border(AppColors.fieldBorder),
        enabledBorder: border(AppColors.fieldBorder),
        disabledBorder: border(AppColors.fieldBorder),
        focusedBorder: border(AppColors.violet),
      ),
    );
  }

  // W7-01 Figma: 제목 22 / Bold, 라벨 13 / Bold, 입력 13 / Regular, 버튼 15 / Bold.
  static const _titleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 30 / 22,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.commentText,
  );

  static const _inputStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _inputHintStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0,
    color: AppColors.commentText,
  );

  static const _errorStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.error,
  );

  static const _buttonStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 20 / 15,
    letterSpacing: 0,
  );
}
