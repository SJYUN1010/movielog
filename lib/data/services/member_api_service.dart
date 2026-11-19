import 'package:dio/dio.dart';

import '../models/member_info.dart';

/// 내 정보 조회·수정입니다. 보호 API라 보호용 Client를 씁니다.
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get<dynamic>('/v7/members/me');
    return parseMemberInfo(response.data);
  }

  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch<dynamic>(
      '/v7/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
