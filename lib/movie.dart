class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.year,
    required this.runtimeMinutes,
    required this.rating,
    required this.voteCount,
    required this.posterAsset,
    required this.tags,
    required this.synopsis,
  });

  final int id;
  final String title;
  final List<String> genres;
  final int year;
  final int runtimeMinutes;
  final double rating;
  final int voteCount;
  final String posterAsset;
  final List<String> tags;
  final String synopsis;

  String get genreLabel => genres.join('/');
}

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genres: ['로맨스', '드라마'],
    year: 2024,
    runtimeMinutes: 124,
    rating: 4.5,
    voteCount: 1245,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재조차 몰랐던 두 남녀가 우연한 계기로 작은 마을에서 재회하게 됩니다. '
        '매일 밤 별을 관측하며 가까워지고, 잊고 있던 꿈과 사랑을 되찾는 따뜻한 이야기입니다. '
        '과거의 아픔으로 인해 사람에게 곁을 주지 않던 여주인공은, 별자리처럼 변함없이 곁을 지켜주는 남주인공을 '
        '통해 마음의 문을 열게 됩니다. 아름다운 영상미와 감성적인 OST가 어우러져 깊은 여운을 남기는 '
        '올 겨울 최고의 로맨스 영화입니다.',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genres: ['SF'],
    year: 2024,
    runtimeMinutes: 118,
    rating: 4.2,
    voteCount: 892,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    tags: ['SF', '모험'],
    synopsis: '통신이 끊긴 심우주 탐사선의 마지막 대원이 우주의 끝에서 인류에게 보내는 메시지를 좇는 이야기.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genres: ['애니메이션'],
    year: 2022,
    runtimeMinutes: 101,
    rating: 4.9,
    voteCount: 2310,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    tags: ['애니메이션', '가족'],
    synopsis: '숲의 정령들이 지켜온 오래된 기억을 되찾기 위해 길을 떠나는 소녀의 성장 이야기.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genres: ['스릴러'],
    year: 2024,
    runtimeMinutes: 109,
    rating: 3.8,
    voteCount: 456,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    tags: ['스릴러', '범죄'],
    synopsis: '도시 곳곳에서 벌어지는 의문의 사건을 쫓는 형사와, 그림자 속에 숨은 진실을 다룬 느와르.',
  ),
  Movie(
    id: 5,
    title: '봄날의 커피',
    genres: ['로맨스'],
    year: 2021,
    runtimeMinutes: 96,
    rating: 4.5,
    voteCount: 731,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    tags: ['로맨스', '힐링'],
    synopsis: '작은 동네 카페를 배경으로 펼쳐지는 두 사람의 잔잔하고 따뜻한 사랑 이야기.',
  ),
  Movie(
    id: 6,
    title: '도시의 리듬',
    genres: ['다큐멘터리'],
    year: 2023,
    runtimeMinutes: 88,
    rating: 4.1,
    voteCount: 203,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    tags: ['다큐멘터리', '음악'],
    synopsis: '도시 곳곳의 거리 음악가들을 따라가며 기록한 진솔한 다큐멘터리.',
  ),
];

const popularMovies = [
  PopularEntry(
    rank: 1,
    title: '마션 레스큐',
    rating: 9.6,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
  ),
  PopularEntry(
    rank: 2,
    title: '스파이 코드',
    rating: 9.2,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
  ),
  PopularEntry(
    rank: 3,
    title: '비오는 날엔',
    rating: 8.9,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
  ),
];

class PopularEntry {
  const PopularEntry({
    required this.rank,
    required this.title,
    required this.rating,
    required this.posterAsset,
  });

  final int rank;
  final String title;
  final double rating;
  final String posterAsset;
}

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
