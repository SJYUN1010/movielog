import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../theme/app_text_styles.dart';
import '../view_models/learning_member_session.dart';
import '../view_models/movie_detail_view_model.dart';
import '../widgets/movielog_button.dart';
import 'movie_detail_screen.dart';

/// 영화 상세 화면의 시작점입니다.
///
/// 목록에서 들어오면 `state.extra`로 받은 DTO를 그대로 쓰고, 직접 접근·Deep Link처럼 extra가 없으면
/// TMDB `GET /movie/{id}`로 다시 조회합니다. 로딩이 끝나면 영화와 학습용 회원 id를 가진
/// [MovieDetailViewModel]을 이 화면 아래에 제공합니다.
class MovieDetailLoader extends StatefulWidget {
  const MovieDetailLoader({super.key, required this.movieId, this.initialMovie});

  final int movieId;
  final TmdbMovieDto? initialMovie;

  @override
  State<MovieDetailLoader> createState() => _MovieDetailLoaderState();
}

class _MovieDetailLoaderState extends State<MovieDetailLoader> {
  late Future<TmdbMovieDto?> _movieFuture;

  @override
  void initState() {
    super.initState();
    _movieFuture = _load();
  }

  Future<TmdbMovieDto?> _load() {
    final initial = widget.initialMovie;
    if (initial != null) return Future.value(initial);
    return context.read<TmdbMovieService>().findMovieById(widget.movieId);
  }

  void _retry() {
    setState(() {
      _movieFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 가입으로 학습용 회원이 바뀌면 ViewModel을 새로 만듭니다.
    final memberId = context.watch<LearningMemberSession>().memberId;

    return FutureBuilder<TmdbMovieDto?>(
      future: _movieFuture, // build마다 새 Future를 만들지 않습니다.
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _Message(
            text: '영화를 불러오지 못했습니다.',
            onRetry: _retry,
          );
        }
        final movie = snapshot.data;
        if (movie == null) {
          return const _Message(text: '영화를 찾을 수 없어요.');
        }
        return ChangeNotifierProvider<MovieDetailViewModel>(
          key: ValueKey(memberId),
          create: (context) => MovieDetailViewModel(
            context.read<RatingApiService>(),
            memberId,
            movie,
          ),
          child: const MovieDetailScreen(),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: AppTextStyles.bodyDescription),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              MovieLogButton(label: '다시 시도', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
