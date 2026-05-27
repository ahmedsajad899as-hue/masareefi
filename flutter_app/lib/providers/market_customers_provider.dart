import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/market_model.dart';
import '../services/api_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────
class MarketCustomersState {
  final List<MarketCustomerModel> customers;
  final List<MarketCustomerModel> overdueCustomers;
  final bool isLoading;
  final String? error;

  const MarketCustomersState({
    this.customers = const [],
    this.overdueCustomers = const [],
    this.isLoading = false,
    this.error,
  });

  MarketCustomersState copyWith({
    List<MarketCustomerModel>? customers,
    List<MarketCustomerModel>? overdueCustomers,
    bool? isLoading,
    String? error,
  }) =>
      MarketCustomersState(
        customers: customers ?? this.customers,
        overdueCustomers: overdueCustomers ?? this.overdueCustomers,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class MarketCustomersNotifier extends StateNotifier<MarketCustomersState> {
  MarketCustomersNotifier() : super(const MarketCustomersState());

  final _api = ApiService.instance;

  Future<void> load({String? query}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = query != null && query.isNotEmpty ? {'q': query} : null;
      final data = await _api.get(ApiConstants.marketCustomers, params: params);
      final list = (data as List<dynamic>)
          .map((e) => MarketCustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(customers: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadOverdue() async {
    try {
      final data = await _api.get(ApiConstants.marketCustomersOverdue);
      final list = (data as List<dynamic>)
          .map((e) => MarketCustomerModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(overdueCustomers: list);
    } catch (_) {}
  }

  Future<MarketCustomerModel?> create({
    required String name,
    String? phone,
    String? notes,
  }) async {
    try {
      final data = await _api.post(ApiConstants.marketCustomers, data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      final customer =
          MarketCustomerModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(customers: [customer, ...state.customers]);
      return customer;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> update(
    String id, {
    String? name,
    String? phone,
    String? notes,
  }) async {
    try {
      final data = await _api.patch(
        '${ApiConstants.marketCustomers}/$id',
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (notes != null) 'notes': notes,
        },
      );
      final updated =
          MarketCustomerModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(
        customers:
            state.customers.map((c) => c.id == id ? updated : c).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _api.delete('${ApiConstants.marketCustomers}/$id');
      state = state.copyWith(
        customers: state.customers.where((c) => c.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final marketCustomersProvider =
    StateNotifierProvider<MarketCustomersNotifier, MarketCustomersState>(
  (ref) => MarketCustomersNotifier(),
);
