import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';

/// 영화 상세 화면의 즐겨찾기 상태입니다. 서버 값이 기준이라 서버 성공을 확인한 뒤에만 북마크를 바꿉니다
/// (결과를 기다리지 않고 먼저 바꾸는 optimistic update는 쓰지 않습니다).
///
/// - isLoading: 첫 여부 조회 중, isSaving: 등록·해제 중, isFavorite: 서버에서 확인한 값
/// - 세션(계정)이 바뀌었거나 화면이 사라진 뒤에 도착한 응답은 반영하지 않습니다.
/// - AUTH401_2/3/4는 [onSessionExpired]로 현재 세션을 한 번 정리하고, 403·네트워크 실패는 로그아웃하지 않습니다.
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    this.onSessionExpired,
  });

  /// 상세 화면의 TMDB 영화 id입니다. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 씁니다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;

  /// 세션 만료(AUTH401_2/3/4)를 받았을 때 호출합니다. 보통 `AuthViewModel.expireSession`입니다.
  final VoidCallback? onSessionExpired;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (generation: generation, ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed);
  }

  bool _isStale(int generation) => !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (_isStale(snap.generation)) return;
      if (isSessionExpiredError(error)) {
        onSessionExpired?.call();
      } else {
        errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
      }
    } catch (_) {
      if (_isStale(snap.generation)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (!_isStale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 요청 중에는 중복 탭을 막습니다. timeout 같은 불확실한 실패 뒤에도 같은 POST를 자동으로 다시 보내지 않습니다.
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (_isStale(snap.generation)) return;
        isFavorite = false;
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
        if (_isStale(snap.generation)) return;
        isFavorite = true;
      }
    } on DioException catch (error) {
      if (_isStale(snap.generation)) return;
      final code = apiErrorCode(error);
      if (isSessionExpiredCode(code)) {
        onSessionExpired?.call();
      } else if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        // 이미 등록(409)이거나 이미 해제(404)이면 서버의 현재 여부로 화면을 맞춥니다.
        await _syncWithServer(snap.generation, before);
      } else {
        isFavorite = before;
        errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
      }
    } catch (_) {
      if (_isStale(snap.generation)) return;
      isFavorite = before;
      errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    } finally {
      if (!_isStale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }

  Future<void> _syncWithServer(int generation, bool before) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (_isStale(generation)) return;
      isFavorite = synced.isFavorite;
      errorMessage = null;
    } catch (_) {
      if (_isStale(generation)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }

  /// 영화 기록 저장(평점 + 즐겨찾기)이 끝난 뒤 북마크를 서버 값으로 다시 맞춥니다(Challenge).
  Future<void> refreshFromServer() async {
    hasLoadedStatus = false;
    await load();
  }
}
