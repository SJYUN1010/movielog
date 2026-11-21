import 'package:dio/dio.dart';

import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/dto/tmdb_genre_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_dto.dart';
import 'package:movielog/data/dto/tmdb_movie_page_dto.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/sign_up_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/email_preference.dart';
import 'package:movielog/genre_preference.dart';
import 'package:movielog/view_models/auth_view_model.dart';

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

  /// 이 page의 Discover/Search 요청만 실패시킵니다(다음 page 실패 후 같은 page 재시도 확인용).
  final failingPages = <int>{};

  /// page별 응답 지연입니다. 늦게 도착한 이전 응답이 섞이는지 볼 때 씁니다.
  final pageDelays = <int, Duration>{};

  /// 조건(장르·검색어)별 응답 지연입니다. key는 `genre:{id}` 또는 `query:{text}`입니다.
  final conditionDelays = <String, Duration>{};

  // 검색
  bool failSearch = false;
  bool emptySearch = false;
  final searchCalls = <({int page, String query})>[];

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
    await Future<void>.delayed((pageDelays[page] ?? Duration.zero) + (conditionDelays['genre:$genreId'] ?? delay));
    if (failDiscover || failingPages.contains(page)) {
      throw DioException(requestOptions: RequestOptions(path: '/discover/movie'));
    }
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

  @override
  Future<TmdbMoviePageDto> searchMovies({required int page, required String query}) async {
    searchCalls.add((page: page, query: query));
    await Future<void>.delayed((pageDelays[page] ?? Duration.zero) + (conditionDelays['query:$query'] ?? delay));
    if (failSearch || failingPages.contains(page)) {
      throw DioException(requestOptions: RequestOptions(path: '/search/movie'));
    }
    if (emptySearch) {
      return const TmdbMoviePageDto(page: 1, results: [], totalPages: 1, totalResults: 0);
    }
    final start = (page - 1) * pageSize;
    return TmdbMoviePageDto(
      page: page,
      results: [
        for (var i = 0; i < pageSize; i++)
          movieDto(start + i + 1000, title: '$query ${start + i + 1}'),
      ],
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

  /// 영화 한 편 조회입니다. 없는 id는 TMDB처럼 404 DioException을 던집니다.
  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    detailCalls.add(movieId);
    await _wait();
    if (failingDetailIds.contains(movieId)) {
      throw DioException(requestOptions: RequestOptions(path: '/movie/$movieId'));
    }
    final movie = movieDetails[movieId];
    if (movie == null) {
      throw dioFailure('/movie/$movieId', statusCode: 404, data: {'success': false});
    }
    return movie;
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

/// 공통 오류 응답 `{ isSuccess: false, code, message, result: null }`을 가진 실패입니다.
DioException commonFailure(int statusCode, String code, String message) {
  return dioFailure(
    '/v8',
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
    if (fail) throw dioFailure('/v8/members/nickname');
    return !takenNicknames.contains(nickname.trim());
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email.trim());
    await Future<void>.delayed(delay);
    if (fail) throw dioFailure('/v8/members/email');
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
    updatedAt: DateTime.utc(2026, 10, 31, 3),
  );
}

typedef RatingUpdate = ({int ratingId, int score, String? comment});

/// 서버 상태를 흉내 내는 v7 평점 서비스입니다. 쓰기 요청이 응답으로 Rating 객체를 돌려줍니다.
/// memberId 인자는 없습니다(토큰이 회원을 식별합니다).
class FakeRatingApiService extends RatingApiService {
  FakeRatingApiService({List<RatingDto>? ratings, this.delay = Duration.zero})
    : ratings = ratings ?? [],
      super(Dio(), Dio());

  List<RatingDto> ratings;
  Duration delay;

  DioException? createFailure;
  DioException? updateFailure;
  DioException? deleteFailure;

  /// 이 id의 삭제만 실패시킵니다(다중 삭제 일부 실패).
  final failingDeleteIds = <int>{};

  /// 이 id의 삭제만 네트워크 오류로 실패시킵니다(실패 항목이 선택 상태로 남는지 볼 때 씁니다).
  final networkFailingDeleteIds = <int>{};

  /// 다음 쓰기를 호출하는 동안 실행할 훅입니다(응답이 오기 전에 로그아웃하는 상황을 만들 때 씁니다).
  Future<void> Function()? beforeResponse;

  int _nextRatingId = 100;

  final createdRequests = <CreateRatingRequest>[];
  final updates = <RatingUpdate>[];
  final deletedIds = <int>[];

  @override
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    await Future<void>.delayed(delay);
    await beforeResponse?.call();
    final error = createFailure;
    if (error != null) throw error;
    createdRequests.add(request);
    final created = RatingDto(
      ratingId: _nextRatingId++,
      movieId: request.movieId,
      score: request.score,
      comment: request.comment?.trim().isEmpty ?? true ? null : request.comment!.trim(),
      createdAt: DateTime.utc(2026, 11, 14, 3),
      updatedAt: DateTime.utc(2026, 11, 14, 3),
    );
    ratings = [created, ...ratings];
    return created;
  }

  @override
  Future<RatingDto> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    await Future<void>.delayed(delay);
    await beforeResponse?.call();
    final error = updateFailure;
    if (error != null) throw error;
    updates.add((ratingId: ratingId, score: score, comment: comment));
    final current = ratings.firstWhere((rating) => rating.ratingId == ratingId);
    final updated = RatingDto(
      ratingId: current.ratingId,
      movieId: current.movieId,
      score: score,
      comment: comment,
      createdAt: current.createdAt,
      updatedAt: DateTime.utc(2026, 11, 14, 4),
    );
    ratings = [for (final rating in ratings) rating.ratingId == ratingId ? updated : rating];
    return updated;
  }

  @override
  Future<void> deleteRating(int ratingId) async {
    await Future<void>.delayed(delay);
    await beforeResponse?.call();
    final error = deleteFailure;
    if (error != null) throw error;
    if (networkFailingDeleteIds.contains(ratingId)) throw dioFailure('/v8/ratings/$ratingId');
    if (failingDeleteIds.contains(ratingId)) {
      throw commonFailure(404, 'RATING404_1', '해당 평점을 찾을 수 없습니다.');
    }
    deletedIds.add(ratingId);
    ratings = [
      for (final rating in ratings)
        if (rating.ratingId != ratingId) rating,
    ];
  }
}

/// 테스트용 토큰 저장소입니다. 실제 보안 저장소 대신 메모리에 보관합니다.
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.token]);

  String? token;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  int readCount = 0;
  int deleteCount = 0;

  /// 저장이 끝나기 전에 기다리게 하는 장치입니다.
  Future<void>? writeGate;

  @override
  Future<void> saveAccessToken(String token) async {
    await writeGate;
    if (failWrite) throw StateError('write failed');
    this.token = token;
  }

  @override
  Future<String?> readAccessToken() async {
    readCount++;
    if (failRead) throw StateError('read failed');
    return token;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCount++;
    if (failDelete) throw StateError('delete failed');
    token = null;
  }
}

MemberInfo memberInfo({
  String nickname = '무비러버',
  String email = 'movie@example.com',
  DateTime? createdAt,
}) {
  return MemberInfo(
    email: email,
    nickname: nickname,
    createdAt: createdAt ?? DateTime.utc(2026, 10, 10, 3),
  );
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(Dio());

  Duration delay = Duration.zero;
  Object? error;
  String accessToken = 'secret-token-1';
  final requests = <LoginRequest>[];

  @override
  Future<LoginResult> login(LoginRequest request) async {
    requests.add(request);
    await Future<void>.delayed(delay);
    final failure = error;
    if (failure != null) throw failure;
    return LoginResult(nickname: '무비러버', accessToken: accessToken);
  }
}

class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService({MemberInfo? member}) : member = member ?? memberInfo(), super(Dio());

  MemberInfo member;
  Duration delay = Duration.zero;

  /// 다음 GET me가 던질 오류입니다. [failMeTimes]만큼 차례로 던집니다.
  Object? meError;
  int failMeTimes = 0;
  Object? updateError;

  int fetchCount = 0;
  final nicknames = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCount++;
    await Future<void>.delayed(delay);
    if (failMeTimes > 0) {
      failMeTimes--;
      throw meError!;
    }
    return member;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    nicknames.add(nickname);
    await Future<void>.delayed(delay);
    final failure = updateError;
    if (failure != null) throw failure;
    member = memberInfo(nickname: nickname, email: member.email, createdAt: member.createdAt);
    return member;
  }
}

/// 로그인을 마친 AuthViewModel입니다(내 정보는 아직 불러오지 않은 상태).
Future<AuthViewModel> signedInAuthViewModel({
  FakeMemberApiService? members,
  MemoryTokenStorage? storage,
}) async {
  final auth = AuthViewModel(
    FakeAuthApiService(),
    members ?? FakeMemberApiService(),
    storage ?? MemoryTokenStorage(),
  );
  await auth.login('movie@example.com', 'Umc1234!');
  return auth;
}

/// 로그인 화면의 "이메일 저장" 값을 메모리에 보관하는 테스트용 구현입니다.
class MemoryEmailPreference implements EmailPreference {
  MemoryEmailPreference([this.email]);

  String? email;

  @override
  Future<String?> read() async => email;

  @override
  Future<void> save(String value) async => email = value.trim();

  @override
  Future<void> clear() async => email = null;
}


FavoriteResponseDto favoriteDto(int favoriteId, int movieId) {
  return FavoriteResponseDto(
    favoriteId: favoriteId,
    movieId: movieId,
    createdAt: DateTime.utc(2026, 11, 20, 3),
  );
}

/// 서버 상태를 흉내 내는 즐겨찾기 서비스입니다. memberId는 받지 않습니다(토큰이 회원을 식별합니다).
class FakeFavoriteApiService extends FavoriteApiService {
  FakeFavoriteApiService({Iterable<int> movieIds = const []})
    : super(Dio()) {
    for (final id in movieIds) {
      favorites[id] = favoriteDto(_nextId++, id);
    }
  }

  /// movieId → 즐겨찾기 응답입니다.
  final favorites = <int, FavoriteResponseDto>{};
  Duration delay = Duration.zero;
  int _nextId = 1;

  // 실패 주입: 값이 있으면 한 번 던지고 지워집니다. 계속 실패시키려면 Persistent를 true로 둡니다.
  Object? listError;
  Object? checkError;
  Object? addError;
  Object? deleteError;
  Object? recordError;
  bool persistentErrors = false;

  /// 즐겨찾기 목록 조회를 이 횟수만큼 실패시킵니다.
  int failListTimes = 0;

  // 호출 기록
  int listCalls = 0;
  final checkCalls = <int>[];
  final addCalls = <int>[];
  final deleteCalls = <int>[];
  final records = <MovieRecordRequest>[];

  /// 호출이 시작될 때 실행할 훅입니다(응답이 오기 전에 계정을 바꾸는 상황을 만들 때 씁니다).
  Future<void> Function()? onList;

  Object? _take(Object? error, void Function() clear) {
    if (error != null && !persistentErrors) clear();
    return error;
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    listCalls++;
    await onList?.call();
    await Future<void>.delayed(delay);
    if (failListTimes > 0) {
      failListTimes--;
      throw listError ?? dioFailure('/v8/favorites');
    }
    final error = _take(listError, () => listError = null);
    if (error != null) throw error;
    return favorites.values.toList().reversed.toList();
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    checkCalls.add(movieId);
    await Future<void>.delayed(delay);
    final error = _take(checkError, () => checkError = null);
    if (error != null) throw error;
    return FavoriteCheckDto(movieId: movieId, isFavorite: favorites.containsKey(movieId));
  }

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    addCalls.add(movieId);
    await Future<void>.delayed(delay);
    final error = _take(addError, () => addError = null);
    if (error != null) throw error;
    if (favorites.containsKey(movieId)) {
      throw commonFailure(409, 'FAVORITE409_1', '이미 이 영화를 즐겨찾기하셨습니다.');
    }
    return favorites[movieId] = favoriteDto(_nextId++, movieId);
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    deleteCalls.add(movieId);
    await Future<void>.delayed(delay);
    final error = _take(deleteError, () => deleteError = null);
    if (error != null) throw error;
    if (favorites.remove(movieId) == null) {
      throw commonFailure(404, 'FAVORITE404_1', '즐겨찾기한 영화를 찾을 수 없습니다.');
    }
  }

  @override
  Future<MovieRecordResult> saveMovieRecord(MovieRecordRequest request) async {
    records.add(request);
    await Future<void>.delayed(delay);
    final error = _take(recordError, () => recordError = null);
    if (error != null) throw error;
    final favorite = request.addToFavorites ? (favorites[request.movieId] = favoriteDto(_nextId++, request.movieId)) : null;
    return MovieRecordResult(rating: ratingDto(500, movieId: request.movieId, score: request.score, comment: request.comment), favorite: favorite);
  }
}
