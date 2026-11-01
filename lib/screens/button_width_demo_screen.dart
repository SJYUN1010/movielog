import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/movielog_button.dart';

/// MovieLogButton의 width 값(null / double.infinity / 고정 값)과 세 가지 상태를 한 화면에서 비교합니다.
/// 디버그 빌드에서만 `/dev/button-width`로 열립니다.
class ButtonWidthDemoScreen extends StatelessWidget {
  const ButtonWidthDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MovieLogButton 너비 비교')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Section(
              title: 'width: null (내용 기반)',
              child: Align(
                alignment: Alignment.centerLeft,
                child: MovieLogButton(label: '중복 확인', onPressed: _noop),
              ),
            ),
            _Section(
              title: 'width: double.infinity (부모 최대 너비)',
              child: const MovieLogButton(
                label: '가입하기',
                width: double.infinity,
                onPressed: _noop,
              ),
            ),
            const _Section(
              title: 'width: 96 (고정 값)',
              child: Align(
                alignment: Alignment.centerLeft,
                child: MovieLogButton(label: '확인', width: 96, onPressed: _noop),
              ),
            ),
            const _Section(
              title: '상태: 기본 / 통신 중 / 비활성',
              child: Row(
                children: [
                  MovieLogButton(label: '중복 확인', onPressed: _noop),
                  SizedBox(width: 8),
                  MovieLogButton(label: '중복 확인', isLoading: true, onPressed: _noop),
                  SizedBox(width: 8),
                  MovieLogButton(label: '중복 확인', onPressed: null),
                ],
              ),
            ),
            _Section(
              title: '입력창 옆: Expanded + width: null',
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: MovieLogButton.height,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        border: Border.all(color: AppColors.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const MovieLogButton(label: '중복 확인', onPressed: _noop),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _noop() {}
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.statLabel),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
