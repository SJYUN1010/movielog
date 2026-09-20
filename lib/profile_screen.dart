import 'package:flutter/material.dart';

import 'widgets/common_app_bar.dart';
import 'widgets/edit_profile_button.dart';
import 'widgets/favorite_genres.dart';
import 'widgets/profile_header.dart';
import 'widgets/stat_item.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _genres = ['드라마', 'SF', '애니메이션'];
  static const _stats = [
    StatItem(label: '본 영화', value: '342'),
    StatItem(label: '평점', value: '4.2'),
    StatItem(label: '즐겨찾기', value: '58'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileHeader(),
              const SizedBox(height: 16),
              Center(
                child: EditProfileButton(
                  onPressed: () {
                    debugPrint('프로필 수정 버튼을 눌렀습니다.');
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  for (var i = 0; i < _stats.length; i++)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
                        child: _stats[i],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const FavoriteGenres(genres: _genres),
            ],
          ),
        ),
      ),
    );
  }
}
