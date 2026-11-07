import 'package:dio/dio.dart';

import 'package:movielog/data/dto/tmdb_genre_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_page_dto.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/genre_preference.dart';

TmdbMovieDto movieDto(
  int id, {
  String? title,
  String? posterPath = '/poster.jpg',
  double voteAverage = 8.0,
  List<int> genreIds = const [18],
  String releaseDate = '2024-05-01',
}) {
  return TmdbMovieDto(
    id: id,
    title: title ?? '영화 $id',
    overview: '영화 $id 줄거리',
    posterPath: posterPath,
    genreIds: genreIds,
    releaseDate: releaseDate,
    voteAverage: voteAverage,
    voteCount: 100,
  );
}

const sampleGenres = [
  TmdbGenreDto(id: 18, name: '드라마'),
  TmdbGenreDto(id: 878, name: 'SF'),
];

class DiscoverCall {
  const DiscoverCall(this.page, this.genreId);

  final int page;
  final int? genreId;
}

class FakeTmdbMovieService extends TmdbMovieService {
  FakeTmdbMovieService({
    this.popular = const [],
    this.genres = sampleGenres,
    this.pageSize = 20,
    this.totalPages = 5,
    this.delay = Duration.zero,
  }) : super(Dio());

  List<TmdbMovieDto> popular;
  List<TmdbGenreDto> genres;
  int pageSize;
  int totalPages;
  Duration delay;

  bool failPopular = false;
  bool failDiscover = false;
  bool failGenres = false;
  bool emptyDiscover = false;

  int popularCalls = 0;
  int genreCalls = 0;
  final discoverCalls = <DiscoverCall>[];

  /// 페이지 사이에 id가 겹치도록 하려면 [overlap]만큼 이전 페이지 id를 다시 내려줍니다.
  int overlap = 0;

  Future<void> _wait() => Future<void>.delayed(delay);

  @override
  Future<TmdbMoviePageDto> fetchPopular({int page = 1}) async {
    popularCalls++;
    await _wait();
    if (failPopular) throw DioException(requestOptions: RequestOptions(path: '/movie/popular'));
    return TmdbMoviePageDto(
      page: page,
      results: popular,
      totalPages: 1,
      totalResults: popular.length,
    );
  }

  @override
  Future<TmdbMoviePageDto> discoverMovies({int page = 1, int? genreId}) async {
    discoverCalls.add(DiscoverCall(page, genreId));
    await _wait();
    if (failDiscover) throw DioException(requestOptions: RequestOptions(path: '/discover/movie'));
    if (emptyDiscover) {
      return const TmdbMoviePageDto(page: 1, results: [], totalPages: 1, totalResults: 0);
    }
    final start = (page - 1) * (pageSize - overlap);
    return TmdbMoviePageDto(
      page: page,
      results: [for (var i = 0; i < pageSize; i++) movieDto(start + i + 1, genreIds: [genreId ?? 18])],
      totalPages: totalPages,
      totalResults: totalPages * pageSize,
    );
  }

  /// id별 영화 상세입니다. 없는 id는 TMDB 404처럼 null을 돌려줍니다.
  final movieDetails = <int, TmdbMovieDto>{};
  final failingDetailIds = <int>{};
  final detailCalls = <int>[];

  @override
  Future<TmdbMovieDto?> findMovieById(int movieId) async {
    detailCalls.add(movieId);
    await _wait();
    if (failingDetailIds.contains(movieId)) {
      throw DioException(requestOptions: RequestOptions(path: '/movie/$movieId'));
    }
    return movieDetails[movieId];
  }

  @override
  Future<List<TmdbGenreDto>> fetchGenres() async {
    genreCalls++;
    await _wait();
    if (failGenres) throw DioException(requestOptions: RequestOptions(path: '/genre/movie/list'));
    return genres;
  }
}

class MemoryGenrePreference implements GenrePreference {
  MemoryGenrePreference([this.value]);

  int? value;

  @override
  Future<int?> read() async => value;

  @override
  Future<void> save(int? genreId) async => value = genreId;
}


DioException dioFailure(String path, {int? statusCode, Object? data}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    response: statusCode == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: statusCode, data: data),
    type: statusCode == null
        ? DioExceptionType.connectionError
        : DioExceptionType.badResponse,
  );
}

/// v6 공통 오류 응답 `{ isSuccess: false, code, message, result: null }`을 가진 실패입니다.
DioException commonFailure(int statusCode, String code, String message) {
  return dioFailure(
    '/v6',
    statusCode: statusCode,
    data: {'isSuccess': false, 'code': code, 'message': message, 'result': null},
  );
}

class FakeSignUpService extends SignUpService {
  FakeSignUpService({
    Set<String>? takenNicknames,
    Set<String>? takenEmails,
    this.delay = Duration.zero,
  }) : takenNicknames = takenNicknames ?? {'영화광'},
       takenEmails = takenEmails ?? {'movie@umc.com'},
       super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  Duration delay;
  bool fail = false;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];

  // 회원가입 POST
  final signUpRequests = <CreateMemberRequest>[];
  Duration signUpDelay = Duration.zero;
  Object? signUpError;
  bool missingResult = false;
  int nextMemberId = 7;

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname.trim());
    await Future<void>.delayed(delay);
    if (fail) throw dioFailure('/v6/members/nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email.trim());
    await Future<void>.delayed(delay);
    if (fail) throw dioFailure('/v6/members/email');
    return !takenEmails.contains(email.trim());
  }

  @override
  Future<CommonResponse<SignUpResult>> signUp(CreateMemberRequest request) async {
    signUpRequests.add(request);
    await Future<void>.delayed(signUpDelay);
    final error = signUpError;
    if (error != null) throw error;
    return CommonResponse<SignUpResult>(
      isSuccess: true,
      code: 'COMMON201',
      message: '회원가입에 성공했습니다.',
      result: missingResult
          ? null
          : SignUpResult(
              memberId: nextMemberId,
              email: request.email.trim(),
              nickname: request.nickname.trim(),
            ),
    );
  }
}

RatingDto ratingDto(
  int ratingId, {
  int movieId = 550,
  int score = 5,
  String? comment = '좋아요',
}) {
  return RatingDto(
    ratingId: ratingId,
    movieId: movieId,
    score: score,
    comment: comment,
    createdAt: DateTime.utc(2026, 10, 31, 3),
  );
}

typedef RatingUpdate = ({int memberId, int ratingId, int score, String? comment});

/// 서버 상태를 흉내 내는 평점 서비스입니다. 쓰기 요청이 [ratings]를 바꾸므로 이어지는 GET이 그 결과를 돌려줍니다.
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings, this.delay = Duration.zero})
    : ratings = ratings ?? [],
      super(Dio());

  List<RatingDto> ratings;
  Duration delay;

  /// GET 실패입니다. null이면 정상입니다.
  DioException? failure;

  /// 다음 GET N번만 실패시킵니다(쓰기 성공 뒤 재조회 실패를 만들 때 씁니다).
  int failNextFetches = 0;

  DioException? createFailure;
  DioException? updateFailure;
  DioException? deleteFailure;

  /// 이 id의 삭제만 실패시킵니다(다중 삭제 일부 실패).
  final failingDeleteIds = <int>{};

  int _nextRatingId = 100;

  final requestedMemberIds = <int>[];
  final createdRequests = <CreateRatingRequest>[];
  final updates = <RatingUpdate>[];
  final deletedIds = <int>[];
  int fetchCount = 0;

  @override
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    requestedMemberIds.add(memberId);
    fetchCount++;
    await Future<void>.delayed(delay);
    if (failNextFetches > 0) {
      failNextFetches--;
      throw dioFailure('/v6/members/$memberId/ratings');
    }
    final error = failure;
    if (error != null) throw error;
    return List<RatingDto>.of(ratings);
  }

  @override
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    await Future<void>.delayed(delay);
    final error = createFailure;
    if (error != null) throw error;
    createdRequests.add(request);
    ratings = [
      RatingDto(
        ratingId: _nextRatingId++,
        movieId: request.movieId,
        score: request.score,
        comment: request.comment?.trim().isEmpty ?? true ? null : request.comment!.trim(),
        createdAt: DateTime.utc(2026, 11, 1, 3),
      ),
      ...ratings,
    ];
  }

  @override
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await Future<void>.delayed(delay);
    final error = updateFailure;
    if (error != null) throw error;
    updates.add((memberId: memberId, ratingId: ratingId, score: score, comment: comment));
    ratings = [
      for (final rating in ratings)
        if (rating.ratingId == ratingId)
          RatingDto(
            ratingId: rating.ratingId,
            movieId: rating.movieId,
            score: score,
            comment: comment,
            createdAt: rating.createdAt,
          )
        else
          rating,
    ];
  }

  @override
  Future<void> deleteRating({required int memberId, required int ratingId}) async {
    await Future<void>.delayed(delay);
    final error = deleteFailure;
    if (error != null) throw error;
    if (failingDeleteIds.contains(ratingId)) {
      throw commonFailure(404, 'COMMON404', '존재하지 않는 평점입니다.');
    }
    deletedIds.add(ratingId);
    ratings = [
      for (final rating in ratings)
        if (rating.ratingId != ratingId) rating,
    ];
  }
}
