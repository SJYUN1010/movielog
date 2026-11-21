import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/dto/tmdb_movie_dto.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/center_message.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_list_tile.dart';
import '../widgets/movie_page_footer.dart';

/// 영화 검색 화면(`/movies/search`)입니다. 영화 목록과는 별도의 [PagedMoviesViewModel]을 씁니다.
///
/// - 검색어를 제출하거나 입력을 500ms 멈췄을 때(debounce)만 요청하고, 빈 검색어는 서버에 보내지 않습니다.
/// - 처음 진입(idle)과 결과 없음(empty)을 구분하고, 결과는 "더 보기"로 이어서 불러옵니다.
/// - 검색어를 바꾸면 이전 결과를 비우고 첫 page부터 불러오며, 이전 검색어의 늦은 응답은 무시됩니다.
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({
    super.key,
    required this.onOpenMovie,
    this.debounce = const Duration(milliseconds: 500),
  });

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  /// 입력이 멈춘 뒤 검색을 시작하기까지의 대기 시간입니다(Challenge A).
  final Duration debounce;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  String _submittedQuery = '';
  String? _inputError;

  /// 입력을 제출하면(키보드 검색·버튼) 기다리지 않고 바로 검색합니다.
  void _submit(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }
    _search(query);
  }

  void _search(String query) {
    if (!mounted) return;
    setState(() {
      _inputError = null;
      _submittedQuery = query;
    });
    context.read<PagedMoviesViewModel>().loadInitial(query: query);
  }

  /// 글자를 입력할 때마다 요청하지 않고, 마지막 입력 뒤 [MovieSearchScreen.debounce]가 지나면 한 번만 검색합니다.
  void _onChanged(String value) {
    _debounce?.cancel();
    if (_inputError != null) setState(() => _inputError = null);
    final query = value.trim();
    // 같은 검색어를 다시 요청하지 않고, 비어 있으면 서버에 보내지 않습니다.
    if (query.isEmpty || query == _submittedQuery) return;
    _debounce = Timer(widget.debounce, () {
      if (!mounted) return;
      _search(query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel(); // 대기 중인 타이머가 화면이 사라진 뒤 실행되지 않게 합니다.
    _controller.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/movies');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: '영화 검색',
        centerTitle: true,
        titleStyle: AppTextStyles.subScreenTitle,
        onBack: _goBack,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: _SearchField(
                controller: _controller,
                errorText: _inputError,
                onChanged: _onChanged,
                onSubmitted: _submit,
              ),
            ),
            Expanded(
              child: Consumer<PagedMoviesViewModel>(
                builder: (context, vm, _) => _Results(
                  vm: vm,
                  query: _submittedQuery,
                  onRetry: () => vm.loadInitial(query: _submittedQuery),
                  onOpenMovie: widget.onOpenMovie,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: AppColors.violet,
      style: AppTextStyles.inputText,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        hintText: '검색어를 입력하세요',
        hintStyle: AppTextStyles.inputHint,
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: TextButton(
          onPressed: () => onSubmitted(controller.text),
          child: const Text('검색', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.violet)),
        ),
        border: _border(AppColors.cardBorder),
        enabledBorder: _border(AppColors.cardBorder),
        focusedBorder: _border(AppColors.violet),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.vm,
    required this.query,
    required this.onRetry,
    required this.onOpenMovie,
  });

  final PagedMoviesViewModel vm;
  final String query;
  final VoidCallback onRetry;
  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  @override
  Widget build(BuildContext context) {
    switch (vm.phase) {
      case LoadPhase.idle:
        return const CenterMessage(title: '검색어를 입력해 주세요.');
      case LoadPhase.loading:
        return const Center(child: CircularProgressIndicator(color: AppColors.violet));
      case LoadPhase.error:
        return CenterMessage(
          title: vm.errorMessage ?? movieSearchFailedMessage,
          actionLabel: '다시 시도',
          onAction: onRetry,
        );
      case LoadPhase.empty:
        return const CenterMessage(title: '검색 결과가 없습니다.');
      case LoadPhase.ready:
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          itemCount: vm.movies.length + 1,
          itemBuilder: (context, index) {
            if (index == vm.movies.length) {
              return MoviePageFooter(vm: vm, moreLabel: '검색 결과 더 보기');
            }
            final movie = vm.movies[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MovieListTile(
                movieId: movie.id,
                movie: movie,
                onTap: () => onOpenMovie(movie),
              ),
            );
          },
        );
    }
  }
}
