import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../view_models/learning_member_session.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TmdbClient>(
          create: (_) => TmdbClient(
            accessToken: dotenv.maybeGet('TMDB_ACCESS_TOKEN') ?? '',
          ),
        ),
        ProxyProvider<TmdbClient, TmdbMovieService>(
          update: (_, client, _) => TmdbMovieService(client.dio),
        ),
        // 워크북 자체 백엔드(/v6)는 TMDB와 baseUrl, 헤더가 달라 Client를 따로 둡니다.
        // TMDB Token은 이 Client로 보내지 않습니다.
        Provider<MovieLogClient>(create: (_) => MovieLogClient()),
        ProxyProvider<MovieLogClient, SignUpService>(
          update: (_, client, _) => SignUpService(client.dio),
        ),
        ProxyProvider<MovieLogClient, RatingApiService>(
          update: (_, client, _) => RatingApiService(client.dio),
        ),
        // 회원가입 결과의 memberId를 보관하는 학습용 세션입니다(인증이 아닙니다).
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession.fromEnvironment(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
