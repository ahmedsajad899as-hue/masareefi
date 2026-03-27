import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/api_constants.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final _storage = const FlutterSecureStorage();
  late final Dio _dio = _buildDio();

  Dio get dio => _dio;

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              // Retry original request with new token
              final token = await _storage.read(key: 'access_token');
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final resp = await _dio.fetch(opts);
                handler.resolve(resp);
                return;
              } catch (_) {}
            }
          }
          handler.next(error);
        },
      ),
    );

    return dio;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    try {
      final resp = await Dio(
        BaseOptions(baseUrl: ApiConstants.baseUrl),
      ).post(ApiConstants.refresh, data: {'refresh_token': refresh});
      await saveTokens(resp.data['access_token'], resp.data['refresh_token']);
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  Future<bool> hasTokens() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? 'Network error';
  }

  // ─── Generic helpers ──────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, dynamic>? params}) async {
    try {
      final r = await _dio.get(path, queryParameters: params);
      return r.data;
    } on DioException catch (e) {
      throw _errorMessage(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final r = await _dio.post(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _errorMessage(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final r = await _dio.patch(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _errorMessage(e);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      throw _errorMessage(e);
    }
  }

  Future<dynamic> postFormData(String path, FormData formData) async {
    try {
      final r = await _dio.post(path, data: formData);
      return r.data;
    } on DioException catch (e) {
      throw _errorMessage(e);
    }
  }
}
