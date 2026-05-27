import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/market_model.dart';
import '../services/api_service.dart';

class MarketSalesState {
  final List<MarketSaleModel> sales;
  final bool isLoading;
  final String? error;

  const MarketSalesState({
    this.sales = const [],
    this.isLoading = false,
    this.error,
  });

  MarketSalesState copyWith({
    List<MarketSaleModel>? sales,
    bool? isLoading,
    String? error,
  }) =>
      MarketSalesState(
        sales: sales ?? this.sales,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class MarketSalesNotifier extends StateNotifier<MarketSalesState> {
  MarketSalesNotifier() : super(const MarketSalesState());

  final _api = ApiService.instance;

  Future<void> loadForCustomer(String customerId, {bool? isPaid}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{'customer_id': customerId};
      if (isPaid != null) params['is_paid'] = isPaid.toString();
      final data = await _api.get(ApiConstants.marketSales, params: params);
      final list = (data as List<dynamic>)
          .map((e) => MarketSaleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(sales: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<MarketSaleModel?> createSale({
    required String customerId,
    required DateTime saleDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final data = await _api.post(ApiConstants.marketSales, data: {
        'customer_id': customerId,
        'sale_date': saleDate.toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      });
      final sale = MarketSaleModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(sales: [sale, ...state.sales]);
      return sale;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> markPaid(String saleId) async {
    try {
      final data =
          await _api.patch('${ApiConstants.marketSales}/$saleId/pay', data: {});
      final updated = MarketSaleModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(
        sales: state.sales.map((s) => s.id == saleId ? updated : s).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String saleId) async {
    try {
      await _api.delete('${ApiConstants.marketSales}/$saleId');
      state = state.copyWith(
        sales: state.sales.where((s) => s.id != saleId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final marketSalesProvider =
    StateNotifierProvider<MarketSalesNotifier, MarketSalesState>(
  (ref) => MarketSalesNotifier(),
);
