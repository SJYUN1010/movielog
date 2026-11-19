import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../core/storage/token_storage.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../email_preference.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/my_ratings_view_model.dart';

class MovieLogApp extends StatelessWidget {
  const MovieLogApp({super.key, this.tokenStorage});

  /// 테스트에서 메모리 저장소로 바꿀 수 있습니다. 앱은 기본으로 보안 저장소를 씁니다.
  final TokenStorage? tokenStorage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStorage>(
          create: (_) => tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage()),
        ),
        // TMDB Client에는 MovieLog 인증 Interceptor를 붙이지 않습니다. TMDB Token만 보냅니다.
        Provider<TmdbClient>(
          create: (_) => TmdbClient(
            accessToken: dotenv.maybeGet('TMDB_ACCESS_TOKEN') ?? '',
          ),
        ),
        ProxyProvider<TmdbClient, TmdbMovieService>(
          update: (_, client, _) => TmdbMovieService(client.dio),
        ),
        // 워크북 백엔드는 공개용(토큰 없음)과 보호용(Bearer 토큰) Client를 나눕니다.
        Provider<MovieLogClient>(create: (_) => MovieLogClient()),
        ProxyProvider<TokenStorage, AuthMovieLogClient>(
          update: (_, storage, _) => AuthMovieLogClient(storage),
        ),
        ProxyProvider<MovieLogClient, AuthApiService>(
          update: (_, client, _) => AuthApiService(client.dio),
        ),
        ProxyProvider<MovieLogClient, SignUpService>(
          update: (_, client, _) => SignUpService(client.dio),
        ),
        ProxyProvider<AuthMovieLogClient, MemberApiService>(
          update: (_, client, _) => MemberApiService(client.dio),
        ),
        // 평점 조회는 공개용, 등록·수정·삭제는 보호용 Client를 씁니다.
        ProxyProvider2<MovieLogClient, AuthMovieLogClient, RatingApiService>(
          update: (_, publicClient, authClient, _) =>
              RatingApiService(publicClient.dio, authClient.dio),
        ),
        Provider<EmailPreference>(create: (_) => EmailPreference()),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
          ),
        ),
        // 이번 로그인 세션에서 등록한 평점입니다. 세션이 바뀌면 AuthViewModel을 보고 스스로 비웁니다.
        ChangeNotifierProvider<MyRatingsViewModel>(
          create: (context) => MyRatingsViewModel(
            context.read<RatingApiService>(),
            context.read<TmdbMovieService>(),
            context.read<AuthViewModel>(),
          ),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

/// MaterialApp.router를 별도 StatefulWidget으로 분리해 GoRouter를 한 번만 만듭니다.
/// build()에서 만들면 화면이 다시 그려질 때마다 Router가 새로 생겨 현재 위치가 초기화됩니다.
class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel);
    // 첫 build 이후에 세션 복원을 시작합니다(build 도중 notifyListeners를 막기 위해).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
