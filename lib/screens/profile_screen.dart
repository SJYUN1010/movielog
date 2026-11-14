import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/member_info.dart';
import '../theme/app_colors.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movielog_button.dart';
import '../widgets/my_ratings_entry_tile.dart';
import '../widgets/profile_header.dart';
import '../widgets/stat_item.dart';

/// 마이페이지입니다. 내 정보는 MainScreen이 불러온 [AuthViewModel.member]를 구독해서 보여줍니다.
/// 불러오는 동안은 화면 전체에 인디케이터, 실패하면 안내와 "다시 시도"를 보여줍니다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // 통계·장르는 서버 응답에 없는 기존 디자인 예시 값입니다.
  static const _genres = ['드라마', 'SF', '애니메이션'];
  static const _stats = [
    StatItem(label: '본 영화', value: '342'),
    StatItem(label: '평점', value: '4.2'),
    StatItem(label: '즐겨찾기', value: '58'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '내 프로필',
        actions: [
          TextButton(
            // 로그아웃은 이 기기의 토큰과 내 정보를 지웁니다. 서버 토큰 폐기를 보장하지는 않습니다.
            onPressed: auth.storageCleanupInProgress
                ? null
                : () => context.read<AuthViewModel>().logout(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.violet,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, auth, member)),
    );
  }

  Widget _buildBody(BuildContext context, AuthViewModel auth, MemberInfo? member) {
    if (member == null) {
      if (auth.memberStatus == MemberLoadStatus.error) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                memberLoadFailedMessage,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 19 / 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              MovieLogButton(
                label: '다시 시도',
                width: 218,
                onPressed: () => context.read<AuthViewModel>().loadMember(force: true),
              ),
            ],
          ),
        );
      }
      // idle(아직 MainScreen이 요청하기 전)과 loading 모두 인디케이터를 보여줍니다.
      return const Center(child: CircularProgressIndicator(color: AppColors.violet));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileHeader(
            nickname: member.nickname,
            email: member.email,
            joinedLabel: member.joinedLabel,
          ),
          const SizedBox(height: 20),
          Center(
            child: EditProfileButton(onPressed: () => context.push('/my/profile/edit')),
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
          MyRatingsEntryTile(onTap: () => context.push('/my/ratings')),
          const SizedBox(height: 24),
          const FavoriteGenres(genres: _genres),
        ],
      ),
    );
  }
}
