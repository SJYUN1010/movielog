import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/signup_validators.dart';

void main() {
  group('SignUpValidators.nickname (2~12 characters)', () {
    test('accepts the boundaries and rejects outside them', () {
      expect(SignUpValidators.nickname('가나'), isNull);
      expect(SignUpValidators.nickname('가' * 12), isNull);
      expect(SignUpValidators.nickname('가'), '닉네임은 2자 이상이어야 합니다.');
      expect(SignUpValidators.nickname('가' * 13), '닉네임은 12자 이하여야 합니다.');
      expect(SignUpValidators.nickname('   '), '닉네임을 입력해주세요.');
    });
  });

  group('SignUpValidators.password', () {
    test('needs 8+ characters with lower, upper, digit and one of !@#\$%^&*', () {
      expect(SignUpValidators.password('Passw0rd!'), isNull);
      expect(SignUpValidators.password('Abcdef1*'), isNull);
    });

    test('rejects each missing class with the same guidance', () {
      const message = '비밀번호는 대문자·소문자·숫자·특수문자(!@#\$%^&*)를 모두 포함해야 합니다.';
      expect(SignUpValidators.password('passw0rd!'), message); // 대문자 없음
      expect(SignUpValidators.password('PASSW0RD!'), message); // 소문자 없음
      expect(SignUpValidators.password('Password!'), message); // 숫자 없음
      expect(SignUpValidators.password('Passw0rds'), message); // 특수문자 없음
      expect(SignUpValidators.password('Passw0rd-'), message); // 허용 목록 밖 특수문자
    });

    test('short and empty passwords keep their own messages', () {
      expect(SignUpValidators.password(''), '비밀번호를 입력해주세요.');
      expect(SignUpValidators.password('Aa1!'), '비밀번호는 8자 이상이어야 합니다.');
    });

    test('does not trim the password', () {
      expect(SignUpValidators.password('        '), isNotNull);
      expect(SignUpValidators.password(' Passw0rd!'), isNull);
    });
  });
}
