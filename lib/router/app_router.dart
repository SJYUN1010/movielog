import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/services/member_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../genre_preference.dart';
import '../screens/button_width_demo_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/movie_detail_loader.dart';
import '../screens/movie_list_screen.dart';
import '../screens/my_ratings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../view_models/movie_home_view_model.dart';
import '../view_models/movie_list_view_model.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/movielog_button.dart';

/// 로그인하지 않아도 볼 수 있는 화면입니다.
const publicPaths = {'/login', '/signup'};

/// 인증 상태에 따라 어디로 보낼지 정합니다. 상태만 읽고, API 호출 같은 비동기 작업은 하지 않습니다.
/// null이면 이동하지 않고 요청한 화면을 보여줍니다.
String? authRedirect(AuthStatus status, String location) {
  final atStart = location == '/start';
  final atPublic = publicPaths.contains(location);

  return switch (status) {
    // 토큰 확인 중이거나 확인 실패(재시도 버튼): 스플래시를 유지합니다. 로그인·보호 화면이 비치지 않습니다.
    AuthStatus.initializing || AuthStatus.retryRequired => atStart ? null : '/start',
    // 로그아웃 또는 로그인 요청 중: 공개 화면만 허용합니다.
    AuthStatus.signedOut || AuthStatus.authenticating => atPublic ? null : '/login',
    // 로그인됨: 스플래시와 로그인·회원가입 화면은 홈으로 보냅니다.
    AuthStatus.signedIn => (atStart || atPublic) ? '/home' : null,
  };
}

class AppRouter {
  AppRouter._();

  /// 하단 NavigationBar를 가리는 자식 화면은 ShellRoute가 아닌 root Navigator 위에 올립니다.
  static final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// GoRouter는 앱이 살아 있는 동안 한 번만 만들어야 해서 호출부가 State 필드에 보관합니다.
  static GoRouter createRouter(AuthViewModel authViewModel) {
    return GoRouter(
      initialLocation: '/start',
      navigatorKey: rootNavigatorKey,
      // 인증 상태가 바뀌면 redirect를 다시 실행합니다. 이것이 없으면 이동할 때만 검사됩니다.
      refreshListenable: authViewModel,
      redirect: (context, state) => authRedirect(authViewModel.status, state.uri.path),
      routes: [
        GoRoute(
          path: '/start', // 스플래시: 토큰 확인 중 / 확인 실패 시 재시도
          builder: (context, state) {
            final auth = context.watch<AuthViewModel>();
            return SplashScreen(
              message: auth.message,
              onRetry: auth.status == AuthStatus.retryRequired ? auth.restoreSession : null,
            );
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => SignUpViewModel(context.read<SignUpService>()),
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
            if (movieId == null || movieId < 1) {
              return const Scaffold(body: Center(child: Text('영화 ID가 올바르지 않습니다.')));
            }
            return MovieDetailLoader(
              movieId: movieId,
              initialMovie: extra is TmdbMovieDto && extra.id == movieId ? extra : null,
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
                  builder: (context, state) => const MyRatingsScreen(),
                ),
                GoRoute(
                  path: 'profile/edit', // 최종 경로: /my/profile/edit
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final auth = context.watch<AuthViewModel>();
                    // 내 정보를 아직 못 불러왔으면 수정 화면 대신 로딩·재시도를 보여줍니다.
                    if (auth.member == null) {
                      return Scaffold(
                        appBar: AppBar(centerTitle: true, title: const Text('프로필 수정')),
                        body: Center(
                          child: auth.memberStatus == MemberLoadStatus.error
                              ? MovieLogButton(
                                  label: '다시 시도',
                                  onPressed: () => auth.loadMember(force: true),
                                )
                              : const CircularProgressIndicator(),
                        ),
                      );
                    }
                    return ChangeNotifierProvider<EditProfileViewModel>(
                      create: (context) =>
                          EditProfileViewModel(context.read<MemberApiService>(), auth),
                      child: const EditProfileScreen(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
