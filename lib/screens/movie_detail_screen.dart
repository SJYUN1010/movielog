import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/favorite_detail_view_model.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/favorite_button.dart';
import '../widgets/movie_action_bar.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/rating_write_guard.dart';
import '../widgets/tmdb_poster_image.dart';

/// 영화 상세 화면입니다. 영화 정보는 [MovieDetailViewModel]에서 읽습니다.
/// 이 화면에서는 평점 등록만 하고(로그인 토큰으로 요청), 조회·수정·삭제는 마이페이지의 "내가 등록한 평점"에서 합니다.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    // build()에서는 조회하지 않고, 화면이 처음 만들어진 뒤 서버의 즐겨찾기 여부를 한 번만 조회합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FavoriteDetailViewModel>().load();
    });
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
      );
  }

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final favoriteViewModel = context.read<FavoriteDetailViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    // 서버에서 "아직 즐겨찾기하지 않음"을 확인한 영화에서만 체크박스를 보여줍니다.
    final canAddFavorite = favoriteViewModel.hasLoadedStatus && !favoriteViewModel.isFavorite;

    final saved = await RatingDialog.show(
      context,
      showAddToFavorite: canAddFavorite,
      // 400·네트워크 실패는 Dialog 안에, 409(이미 평점·즐겨찾기)·404는 Snackbar로 안내합니다. 401이면 로그인 화면으로 이동합니다.
      onSubmit: (score, comment, addToFavorites) => guardRatingWrite(
        messenger,
        () => canAddFavorite
            // 즐겨찾기하지 않은 영화는 평점과 즐겨찾기를 한 번에 저장합니다(POST /v8/movie-records).
            ? viewModel.saveRecord(score: score, comment: comment, addToFavorites: addToFavorites)
            // 이미 즐겨찾기한 영화는 평점만 저장합니다(POST /v8/ratings).
            : viewModel.createRating(score: score, comment: comment),
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계라 await 뒤에 mounted를 다시 확인합니다.
    if (!mounted || saved != true) return;
    _showSnackBar('평점을 저장했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
    // 평점과 함께 즐겨찾기를 저장했을 수 있으니 북마크를 서버 값으로 다시 맞춥니다.
    if (canAddFavorite) await favoriteViewModel.refreshFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MovieDetailViewModel>();
    final movie = viewModel.movie;
    final year = movie.releaseYear;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: TmdbPosterImage(posterPath: movie.posterPath),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목·정보 텍스트 오른쪽에 즐겨찾기 북마크를 둡니다.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.title, style: AppTextStyles.detailTitle),
                            if (year != null) ...[
                              const SizedBox(height: 8),
                              Text('$year', style: AppTextStyles.detailMeta),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const FavoriteButton(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StarRow(rating: movie.fiveStarRating),
                      const SizedBox(width: 12),
                      Text(
                        movie.fiveStarRating.toStringAsFixed(1),
                        style: AppTextStyles.ratingNumber,
                      ),
                      const SizedBox(width: 6),
                      Text('(${movie.voteCount})', style: AppTextStyles.voteCount),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('시놉시스', style: AppTextStyles.synopsisHeading),
                  const SizedBox(height: 12),
                  Text(
                    movie.overview.isEmpty ? '등록된 줄거리가 없습니다.' : movie.overview,
                    style: AppTextStyles.synopsisBody,
                  ),
                  if (viewModel.lastCreatedScore != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.violet),
                        const SizedBox(width: 8),
                        Text(
                          '내 평점 ${viewModel.lastCreatedScore}',
                          style: AppTextStyles.tagChip,
                        ),
                      ],
                    ),
                  ],
                  const _FavoriteErrorBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MovieActionBar(
        onRatePressed: _openRatingDialog,
      ),
    );
  }
}

/// 즐겨찾기 등록·해제·여부 조회에 실패했을 때 사유를 남겨 둡니다(W9 Figma "실패 · 이전 상태 유지").
class _FavoriteErrorBanner extends StatelessWidget {
  const _FavoriteErrorBanner();

  @override
  Widget build(BuildContext context) {
    final message = context.select<FavoriteDetailViewModel, String?>((vm) => vm.errorMessage);
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.deleteFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 18 / 13,
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = rating - index;
        final IconData icon;
        if (filled >= 1) {
          icon = Icons.star_rounded;
        } else if (filled >= 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: 20, color: AppColors.violet);
      }),
    );
  }
}
