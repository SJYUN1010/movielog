import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/movie_detail_view_model.dart';
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
  bool _isFavorite = false;

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
      );
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
    _showSnackBar(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기에서 삭제했습니다.');
  }

  Future<void> _openRatingDialog() async {
    final viewModel = context.read<MovieDetailViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await RatingDialog.show(
      context,
      // 400·네트워크 실패는 Dialog 안에, 409(이미 등록)·403·404는 Snackbar로 안내합니다.
      onSubmit: (score, comment) => guardRatingWrite(
        messenger,
        () => viewModel.createRating(score: score, comment: comment),
      ),
    );

    // 저장 요청과 Snackbar 표시는 서로 다른 비동기 경계라 await 뒤에 mounted를 다시 확인합니다.
    if (!mounted || saved != true) return;
    _showSnackBar('평점을 등록했습니다. 마이페이지의 "내가 등록한 평점"에서 확인할 수 있습니다.');
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
                  Text(movie.title, style: AppTextStyles.detailTitle),
                  if (year != null) ...[
                    const SizedBox(height: 8),
                    Text('$year', style: AppTextStyles.detailMeta),
                  ],
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
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MovieActionBar(
        isFavorite: _isFavorite,
        onFavoriteToggle: _toggleFavorite,
        onRatePressed: _openRatingDialog,
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
