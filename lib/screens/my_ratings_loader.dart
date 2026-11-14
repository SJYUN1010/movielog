import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/my_ratings_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movielog_button.dart';
import 'my_ratings_screen.dart';

/// `/my/ratings`의 시작점입니다. 회원가입으로 얻은 학습용 memberId로 조회하고,
/// 아직 가입하지 않았다면 평점 대신 회원가입을 안내합니다.
class MyRatingsLoader extends StatelessWidget {
  const MyRatingsLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final memberId = context.watch<LearningMemberSession>().memberId;

    if (memberId == null) {
      return Scaffold(
        appBar: CommonAppBar(
          title: '내가 등록한 평점',
          centerTitle: true,
          titleStyle: AppTextStyles.subScreenTitle,
          onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/my');
            }
          },
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('학습용 회원가입이 필요합니다.', style: AppTextStyles.bodyDescription),
              const SizedBox(height: 16),
              MovieLogButton(
                label: '회원가입하러 가기',
                onPressed: () => context.push('/signup'),
              ),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider<MyRatingsViewModel>(
      key: ValueKey(memberId), // 가입한 회원이 바뀌면 목록을 새로 조회합니다.
      create: (context) => MyRatingsViewModel(
        context.read<RatingApiService>(),
        context.read<TmdbMovieService>(),
        memberId,
      )..load(),
      child: const MyRatingsScreen(),
    );
  }
}
