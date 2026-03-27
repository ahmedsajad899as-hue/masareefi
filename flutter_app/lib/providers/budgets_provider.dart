import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_constants.dart';

// ─── State ─────────────────────────────────────────────────────────────────────

class BudgetsState {
  final List<BudgetModel> budgets;
  final List<GoalModel> goals;
  final bool isLoading;
  final String? error;

  const BudgetsState({
    this.budgets = const [],
    this.goals = const [],
    this.isLoading = false,
    this.error,
  });

  BudgetsState copyWith({
    List<BudgetModel>? budgets,
    List<GoalModel>? goals,
    bool? isLoading,
    String? error,
  }) =>
      BudgetsState(
        budgets: budgets ?? this.budgets,
        goals: goals ?? this.goals,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class BudgetsNotifier extends StateNotifier<BudgetsState> {
  BudgetsNotifier() : super(const BudgetsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final results = await Future.wait([
        ApiService.instance.get('${ApiConstants.budgets}?year=${now.year}&month=${now.month}'),
        ApiService.instance.get(ApiConstants.goals),
      ]);

      final budgetsData = results[0] as List<dynamic>;
      final goalsData = results[1] as List<dynamic>;

      state = state.copyWith(
        isLoading: false,
        budgets: budgetsData.map((e) => BudgetModel.fromJson(e as Map<String, dynamic>)).toList(),
        goals: goalsData.map((e) => GoalModel.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createBudget(Map<String, dynamic> payload) async {
    try {
      final data = await ApiService.instance.post(ApiConstants.budgets, data: payload);
      final budget = BudgetModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(budgets: [...state.budgets, budget]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBudget(String id, Map<String, dynamic> payload) async {
    try {
      final data = await ApiService.instance.patch('${ApiConstants.budgets}/$id', data: payload);
      final updated = BudgetModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(
        budgets: state.budgets.map((b) => b.id == id ? updated : b).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBudget(String id) async {
    try {
      await ApiService.instance.delete('${ApiConstants.budgets}/$id');
      state = state.copyWith(budgets: state.budgets.where((b) => b.id != id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createGoal(Map<String, dynamic> payload) async {
    try {
      final data = await ApiService.instance.post(ApiConstants.goals, data: payload);
      final goal = GoalModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(goals: [...state.goals, goal]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateGoal(String id, Map<String, dynamic> payload) async {
    try {
      final data = await ApiService.instance.patch('${ApiConstants.goals}/$id', data: payload);
      final updated = GoalModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(
        goals: state.goals.map((g) => g.id == id ? updated : g).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    try {
      await ApiService.instance.delete('${ApiConstants.goals}/$id');
      state = state.copyWith(goals: state.goals.where((g) => g.id != id).toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final budgetsProvider = StateNotifierProvider<BudgetsNotifier, BudgetsState>((ref) {
  return BudgetsNotifier();
});
