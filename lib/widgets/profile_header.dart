import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 마이페이지 상단의 프로필 영역입니다. 닉네임·가입일·이메일은 `GET /v7/members/me` 응답 값입니다.
/// 사진은 서버 응답에 없는 기존 디자인 예시 이미지입니다.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.nickname,
    required this.email,
    this.joinedLabel,
  });

  final String nickname;
  final String email;

  /// "2026.10.10 가입" 형식의 가입일입니다(Challenge). null이면 표시하지 않습니다.
  final String? joinedLabel;

  static const _subStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 44,
          backgroundImage: AssetImage('assets/images/profile/profile_movielog.jpg'),
        ),
        const SizedBox(height: 16),
        Text(
          nickname,
          style: AppTextStyles.nickname,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        if (joinedLabel != null) ...[
          Text(joinedLabel!, style: _subStyle),
          const SizedBox(height: 4),
        ],
        Text(email, style: _subStyle, textAlign: TextAlign.center),
      ],
    );
  }
}
