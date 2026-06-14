import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/market_model.dart';
import '../services/api_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MarketProductsState {
  final List<MarketProductModel> products;
  final bool isLoading;
  final String? error;

  const MarketProductsState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });

  MarketProductsState copyWith({
    List<MarketProductModel>? products,
    bool? isLoading,
    String? error,
  }) =>
      MarketProductsState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MarketProductsNotifier extends StateNotifier<MarketProductsState> {
  MarketProductsNotifier() : super(const MarketProductsState());

  final _api = ApiService.instance;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final products = await _api.getProducts();
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<MarketProductModel?> add({
    required String name,
    required double unitPrice,
    String? barcode,
  }) async {
    try {
      final product = await _api.createProduct(
        name: name,
        unitPrice: unitPrice,
        barcode: barcode,
      );
      state = state.copyWith(
        products: [...state.products, product]
          ..sort((a, b) => a.name.compareTo(b.name)),
      );
      return product;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> edit(
    String id, {
    String? name,
    double? unitPrice,
    String? barcode,
    bool clearBarcode = false,
  }) async {
    try {
      final updated = await _api.updateProduct(
        id,
        name: name,
        unitPrice: unitPrice,
        barcode: barcode,
        clearBarcode: clearBarcode,
      );
      state = state.copyWith(
        products: state.products
            .map((p) => p.id == id ? updated : p)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _api.deleteProduct(id);
      state = state.copyWith(
        products: state.products.where((p) => p.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Add an extra barcode to a product and refresh local state.
  Future<bool> addBarcode(String productId, String barcode) async {
    try {
      final updated = await _api.addProductBarcode(productId, barcode);
      state = state.copyWith(
        products: state.products.map((p) => p.id == productId ? updated : p).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Remove an extra barcode from a product and refresh local state.
  Future<bool> removeBarcode(String productId, String barcodeValue) async {
    try {
      await _api.removeProductBarcode(productId, barcodeValue);
      // Reload this product to get updated barcodes list
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final marketProductsProvider =
    StateNotifierProvider<MarketProductsNotifier, MarketProductsState>(
  (_) => MarketProductsNotifier(),
);
