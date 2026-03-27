import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/expense_model.dart';
import '../services/api_service.dart';

class ExpensesState {
  final List<ExpenseModel> items;
  final bool isLoading;
  final String? error;
  final int total;
  final int page;
  final int pages;

  const ExpensesState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
    this.page = 1,
    this.pages = 1,
  });

  ExpensesState copyWith({
    List<ExpenseModel>? items,
    bool? isLoading,
    String? error,
    int? total,
    int? page,
    int? pages,
  }) =>
      ExpensesState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        total: total ?? this.total,
        page: page ?? this.page,
        pages: pages ?? this.pages,
      );
}

class ExpensesNotifier extends StateNotifier<ExpensesState> {
  ExpensesNotifier() : super(const ExpensesState());

  final _api = ApiService.instance;

  Future<void> load({
    int page = 1,
    String? categoryId,
    String? dateFrom,
    String? dateTo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.get(ApiConstants.expenses, params: {
        'page': page,
        'size': 20,
        if (categoryId != null) 'category_id': categoryId,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      });
      final result = data as Map<String, dynamic>;
      final items = (result['items'] as List)
          .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        items: page == 1 ? items : [...state.items, ...items],
        isLoading: false,
        total: result['total'] as int,
        page: result['page'] as int,
        pages: result['pages'] as int,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<ExpenseModel?> create(Map<String, dynamic> payload) async {
    try {
      final data = await _api.post(ApiConstants.expenses, data: payload);
      final expense = ExpenseModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(items: [expense, ...state.items]);
      return expense;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> createBulk(List<Map<String, dynamic>> expenses) async {
    try {
      final data = await _api.post(
        ApiConstants.expensesBulk,
        data: {'expenses': expenses},
      );
      final newItems = (data as List)
          .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(items: [...newItems, ...state.items]);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> payload) async {
    try {
      final data = await _api.patch('${ApiConstants.expenses}/$id', data: payload);
      final updated = ExpenseModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(
        items: state.items.map((e) => e.id == id ? updated : e).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _api.delete('${ApiConstants.expenses}/$id');
      state = state.copyWith(items: state.items.where((e) => e.id != id).toList());
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final expensesProvider =
    StateNotifierProvider<ExpensesNotifier, ExpensesState>(
  (_) => ExpensesNotifier(),
);
