import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../data/services/member_check_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

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
        // 워크북 자체 백엔드(/v5)는 TMDB와 baseUrl, 헤더가 달라 Client를 따로 둡니다.
        Provider<MovieLogClient>(create: (_) => MovieLogClient()),
        ProxyProvider<MovieLogClient, MemberCheckService>(
          update: (_, client, _) => MemberCheckService(client.dio),
        ),
        ProxyProvider<MovieLogClient, RatingApiService>(
          update: (_, client, _) => RatingApiService(client.dio),
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
