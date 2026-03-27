import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/stats_model.dart';
import '../services/api_service.dart';

class StatsState {
  final Map<String, dynamic>? daily;
  final Map<String, dynamic>? monthly;
  final List<CategoryStat> categories;
  final List<DailyTrendPoint> trend;
  final List<MonthlyPoint> comparison;
  final String? insights;
  final bool isLoading;
  final String? error;

  const StatsState({
    this.daily,
    this.monthly,
    this.categories = const [],
    this.trend = const [],
    this.comparison = const [],
    this.insights,
    this.isLoading = false,
    this.error,
  });

  StatsState copyWith({
    Map<String, dynamic>? daily,
    Map<String, dynamic>? monthly,
    List<CategoryStat>? categories,
    List<DailyTrendPoint>? trend,
    List<MonthlyPoint>? comparison,
    String? insights,
    bool? isLoading,
    String? error,
  }) =>
      StatsState(
        daily: daily ?? this.daily,
        monthly: monthly ?? this.monthly,
        categories: categories ?? this.categories,
        trend: trend ?? this.trend,
        comparison: comparison ?? this.comparison,
        insights: insights ?? this.insights,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class StatsNotifier extends StateNotifier<StatsState> {
  StatsNotifier() : super(const StatsState());

  final _api = ApiService.instance;

  Future<void> loadDashboard({int? year, int? month}) async {
    state = state.copyWith(isLoading: true, error: null);
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;
    try {
      final results = await Future.wait([
        _api.get(ApiConstants.statsDaily),
        _api.get(ApiConstants.statsMonthly, params: {'year': y, 'month': m}),
        _api.get(ApiConstants.statsCategories, params: {'year': y, 'month': m}),
        _api.get(ApiConstants.statsTrend, params: {'year': y, 'month': m}),
        _api.get(ApiConstants.statsComparison, params: {'months': 6}),
      ]);

      state = state.copyWith(
        daily: results[0] as Map<String, dynamic>,
        monthly: results[1] as Map<String, dynamic>,
        categories: (results[2] as List)
            .map((e) => CategoryStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        trend: (results[3] as List)
            .map((e) => DailyTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        comparison: (results[4] as List)
            .map((e) => MonthlyPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadInsights() async {
    final now = DateTime.now();
    try {
      final data = await _api.get(
        ApiConstants.statsInsights,
        params: {'year': now.year, 'month': now.month},
      );
      state = state.copyWith(insights: (data as Map)['tips'] as String?);
    } catch (_) {}
  }
}

final statsProvider =
    StateNotifierProvider<StatsNotifier, StatsState>((_) => StatsNotifier());
