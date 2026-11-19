import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../widgets/movielog_button.dart';

/// 앱 시작 화면이자 세션 확인 화면입니다. 1주차 StartScreen의 로고·제목·설명 레이아웃을 재사용합니다.
///
/// 토큰을 확인하는 동안 빈 화면 대신 이 화면을 보여줘서, 로그인 화면이나 보호 화면이 잠깐 비치지 않게 합니다.
/// - [onRetry]가 null이면 확인 중(initializing)이라 하단에 인디케이터를 보여줍니다.
/// - [onRetry]가 있으면 확인 실패(retryRequired)라 안내 문구와 "다시 시도" 버튼을 보여줍니다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  // W8 Figma: 상단 라벨 12, 제목 24 (두 줄), 설명 14 (두 줄), 안내 14.
  static const _labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  static const _titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 35 / 24,
    letterSpacing: 0,
    color: AppColors.black,
  );

  static const _descriptionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 24 / 14,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 52),
          // 하단에 전체 너비 버튼이 없는 확인 중 상태에서도 내용이 가운데 정렬되도록 너비를 채웁니다.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Text('FLUTTER 8주차', style: _labelStyle),
                const Spacer(flex: 6),
                SvgPicture.asset(
                  'assets/logos/movielog_logo.svg',
                  width: 72,
                  height: 72,
                  semanticsLabel: 'MovieLog 로고',
                ),
                const SizedBox(height: 28),
                const Text(
                  '영화의 순간을\n기록하세요',
                  textAlign: TextAlign.center,
                  style: _titleStyle,
                ),
                const SizedBox(height: 18),
                const Text(
                  '보고 싶은 영화부터 나만의 평점까지\n한곳에서 관리해요',
                  textAlign: TextAlign.center,
                  style: _descriptionStyle,
                ),
                const Spacer(flex: 11),
                if (retry == null)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.violet,
                    ),
                  )
                else ...[
                  Text(
                    message ?? '로그인 상태를 확인하지 못했어요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 19 / 14,
                      letterSpacing: 0,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  MovieLogButton(
                    label: '다시 시도',
                    width: double.infinity,
                    onPressed: retry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
