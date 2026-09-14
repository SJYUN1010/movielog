// Mission 2. Dart 연습
// 실행: dart run lib/practice/dart_basics.dart
// ignore_for_file: avoid_print

class Movie {
  const Movie({required this.id, required this.title});

  final int id;
  final String title;
}

String displayName(String? nickname) {
  return nickname?.trim().isNotEmpty == true ? nickname! : '이름 없음';
}

void main() {
  final movies = <Movie>[
    const Movie(id: 1, title: '인터스텔라'),
    const Movie(id: 2, title: '기생충'),
    const Movie(id: 3, title: '라라랜드'),
  ];

  // for문으로 출력
  print('--- for문 ---');
  for (final movie in movies) {
    print(movie.title);
  }

  // map으로 출력
  print('--- map ---');
  movies.map((movie) => movie.title).forEach(print);

  // nullable 닉네임 처리
  print('--- null safety ---');
  print(displayName('무비러버')); // 무비러버
  print(displayName(''));       // 이름 없음
  print(displayName(null));     // 이름 없음
}
