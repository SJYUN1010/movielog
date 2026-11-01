import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/services/tmdb_movie_service.dart';
import '../data/services/member_check_service.dart';
import '../data/services/rating_api_service.dart';
import '../genre_preference.dart';
import '../screens/home_screen.dart';
import '../screens/button_width_demo_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/start_screen.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/my_ratings_view_model.dart';
import '../view_models/sign_up_view_model.dart';

class AppRouter {
  AppRouter._();

  static const _initialRoute = String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: '/start',
  );

  /// 하단 NavigationBar를 가리는 자식 화면은 ShellRoute가 아닌 root Navigator 위에 올립니다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: _initialRoute,
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const StartScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => SignUpViewModel(context.read<MemberCheckService>()),
          child: const SignUpScreen(),
        ),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev/button-width',
          builder: (context, state) => const ButtonWidthDemoScreen(),
        ),
      GoRoute(
        path: '/movies/:movieId',
        builder: (context, state) {
          final movieId = int.tryParse(state.pathParameters['movieId'] ?? '');
          final extra = state.extra;
          return MovieDetailScreen(
            movieId: movieId ?? -1,
            movie: extra is TmdbMovieDto && extra.id == movieId ? extra : null,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(
            currentIndex: MainScreen.indexFromLocation(state.uri.path),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) =>
                  MovieHomeViewModel(context.read<TmdbMovieService>())..load(),
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) => MovieListViewModel(
                context.read<TmdbMovieService>(),
                genrePreference: GenrePreference(),
              )..load(),
              child: const MovieListScreen(),
            ),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: 'ratings', // 최종 경로: /my/ratings
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => MyRatingsViewModel(
                    context.read<RatingApiService>(),
                    context.read<TmdbMovieService>(),
                    sampleMemberId,
                  )..load(),
                  child: const MyRatingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
