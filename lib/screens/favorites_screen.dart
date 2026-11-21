import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/favorites_view_model.dart';
import '../view_models/load_phase.dart';
import '../widgets/center_message.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_tile.dart';

/// 마이페이지 → 내 즐겨찾기 화면입니다. 하단 NavigationBar 없이 뒤로가기만 둡니다.
///
/// 목록·빈 목록·조회 오류·영화 정보 한 건 실패를 서로 다른 화면으로 구분합니다. 카드를 눌러 상세에서
/// 즐겨찾기를 해제하고 돌아오면 목록을 다시 조회해 해제한 영화가 사라지게 합니다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpenMovie});

  /// 영화 상세로 이동하고, 상세에서 돌아오면 끝나는 Future입니다.
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // build()에서는 조회하지 않고, 화면이 처음 만들어진 뒤 한 번만 조회합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoritesViewModel>().refresh();
    });
  }

  Future<void> _open(TmdbMovieDto movie) async {
    final viewModel = context.read<FavoritesViewModel>();
    await widget.onOpenMovie(movie);
    if (!mounted) return;
    // 상세에서 해제했을 수 있으니 목록을 다시 조회합니다(같은 세션인지 ViewModel이 다시 확인합니다).
    await viewModel.refresh(silent: true);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/my');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '내 즐겨찾기',
        centerTitle: true,
        titleStyle: AppTextStyles.subScreenTitle,
        onBack: _goBack,
      ),
      body: SafeArea(
        child: Consumer<FavoritesViewModel>(
          builder: (context, vm, _) {
            switch (vm.phase) {
              case LoadPhase.idle:
              case LoadPhase.loading:
                return const Center(child: CircularProgressIndicator(color: AppColors.violet));
              case LoadPhase.empty:
                return const CenterMessage(
                  icon: Icons.bookmark_border,
                  title: '아직 즐겨찾기한 영화가 없습니다.',
                  subtitle: '영화 상세에서 북마크를 눌러보세요.',
                );
              case LoadPhase.error:
                return CenterMessage(
                  title: vm.errorMessage ?? favoritesLoadFailedMessage,
                  actionLabel: '다시 시도',
                  onAction: vm.refresh,
                );
              case LoadPhase.ready:
                return RefreshIndicator(
                  color: AppColors.violet,
                  onRefresh: () => vm.refresh(silent: true),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: vm.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = vm.items[index];
                      final movie = item.movie;
                      return MovieListTile(
                        movieId: item.favorite.movieId,
                        movie: movie,
                        label: '즐겨찾기한 영화',
                        onTap: movie == null ? null : () => _open(movie),
                        // 정보를 못 가져온 카드만 다시 조회합니다. 다른 카드와 목록은 그대로 둡니다.
                        onRetryInfo: movie == null ? () => vm.retryMovie(item.favorite.movieId) : null,
                      );
                    },
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
