import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/api_constants.dart';
import '../models/market_model.dart';

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
        receiveTimeout: const Duration(seconds: 120),
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

  Future<String?> readToken(String key) async {
    return _storage.read(key: key);
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

  // ─── Market Products ──────────────────────────────────────────────────────

  Future<List<MarketProductModel>> getProducts() async {
    final data = await get(ApiConstants.marketProducts);
    return (data as List)
        .map((j) => MarketProductModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<MarketProductModel> createProduct({
    required String name,
    required double unitPrice,
    String? barcode,
  }) async {
    final data = await post(ApiConstants.marketProducts, data: {
      'name': name,
      'unit_price': unitPrice,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
    });
    return MarketProductModel.fromJson(data as Map<String, dynamic>);
  }

  Future<MarketProductModel> updateProduct(
    String id, {
    String? name,
    double? unitPrice,
    String? barcode,
    bool clearBarcode = false,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (unitPrice != null) body['unit_price'] = unitPrice;
    if (clearBarcode) {
      body['barcode'] = null;
    } else if (barcode != null) {
      body['barcode'] = barcode;
    }
    final data = await patch('${ApiConstants.marketProducts}/$id', data: body);
    return MarketProductModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String id) async {
    await delete('${ApiConstants.marketProducts}/$id');
  }

  /// Returns the product matching [barcode], or null if not found in catalog.
  Future<MarketProductModel?> getProductByBarcode(String barcode) async {
    try {
      final data = await get(ApiConstants.marketProductByBarcode(barcode));
      return MarketProductModel.fromJson(data as Map<String, dynamic>);
    } on String catch (e) {
      if (e.contains('غير موجود') || e.contains('404')) return null;
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _errorMessage(e);
    }
  }

  /// Add an extra barcode to an existing catalog product.
  Future<MarketProductModel> addProductBarcode(String productId, String barcode) async {
    final data = await post(
      ApiConstants.marketProductBarcodes(productId),
      data: {'barcode': barcode},
    );
    return MarketProductModel.fromJson(data as Map<String, dynamic>);
  }

  /// Remove an extra barcode from a catalog product.
  Future<void> removeProductBarcode(String productId, String barcodeValue) async {
    await delete(ApiConstants.marketProductBarcodeValue(productId, barcodeValue));
  }
}
