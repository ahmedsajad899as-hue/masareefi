import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        user: user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _checkExistingSession();
  }

  final _api = ApiService.instance;

  Future<void> _checkExistingSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final hasToken = await _api.hasTokens();
      if (hasToken) {
        final data = await _api.get(ApiConstants.me);
        final user = UserModel.fromJson(data as Map<String, dynamic>);
        state = AuthState(user: user, isAuthenticated: true);
      } else {
        state = const AuthState();
      }
    } catch (_) {
      await _api.clearTokens();
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      final tokens = AuthTokens.fromJson(data as Map<String, dynamic>);
      await _api.saveTokens(tokens.accessToken, tokens.refreshToken);
      state = AuthState(user: tokens.user, isAuthenticated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    String language = 'ar',
    String currency = 'IQD',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'preferred_language': language,
          'currency': currency,
        },
      );
      final tokens = AuthTokens.fromJson(data as Map<String, dynamic>);
      await _api.saveTokens(tokens.accessToken, tokens.refreshToken);
      state = AuthState(user: tokens.user, isAuthenticated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      final storage = await _api._storage.read(key: 'refresh_token');
      if (storage != null) {
        await _api.post(ApiConstants.logout, data: {'refresh_token': storage});
      }
    } finally {
      await _api.clearTokens();
      state = const AuthState();
    }
  }

  Future<void> updateProfile({String? fullName, String? language, String? currency}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _api.patch(ApiConstants.meUpdate, data: {
        if (fullName != null) 'full_name': fullName,
        if (language != null) 'preferred_language': language,
        if (currency != null) 'currency': currency,
      });
      final user = UserModel.fromJson(data as Map<String, dynamic>);
      state = AuthState(user: user, isAuthenticated: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> changePassword(String current, String newPass) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post(ApiConstants.changePassword, data: {
        'current_password': current,
        'new_password': newPass,
      });
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
