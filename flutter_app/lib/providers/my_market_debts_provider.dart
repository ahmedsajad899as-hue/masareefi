import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/market_model.dart';
import '../services/api_service.dart';

class MyMarketDebtsState {
  final List<MyMarketDebtModel> debts;
  final bool isLoading;
  final String? error;

  const MyMarketDebtsState({
    this.debts = const [],
    this.isLoading = false,
    this.error,
  });

  double get totalUnpaid =>
      debts.fold(0.0, (sum, d) => sum + d.totalUnpaid);

  MyMarketDebtsState copyWith({
    List<MyMarketDebtModel>? debts,
    bool? isLoading,
    String? error,
  }) =>
      MyMarketDebtsState(
        debts: debts ?? this.debts,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class MyMarketDebtsNotifier extends StateNotifier<MyMarketDebtsState> {
  MyMarketDebtsNotifier() : super(const MyMarketDebtsState());

  final _api = ApiService.instance;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.get(ApiConstants.myMarketDebts);
      final list = (data as List<dynamic>)
          .map((e) => MyMarketDebtModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(debts: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final myMarketDebtsProvider =
    StateNotifierProvider<MyMarketDebtsNotifier, MyMarketDebtsState>(
  (ref) => MyMarketDebtsNotifier(),
);
