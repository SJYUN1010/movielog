import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 44,
          backgroundImage: AssetImage('assets/images/profile/profile_movielog.jpg'),
        ),
        const SizedBox(height: 12),
        const Text('무비러버', style: AppTextStyles.nickname),
        const SizedBox(height: 8),
        const Text(
          '매주 주말엔 영화관으로 출근하는 프로 관람객. 좋은 영화를 보고 기록하는 것을 좋아합니다.',
          style: AppTextStyles.bodyDescription,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
