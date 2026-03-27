import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/category_model.dart';
import '../services/api_service.dart';

class CategoriesNotifier extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  CategoriesNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  final _api = ApiService.instance;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final data = await _api.get(ApiConstants.categories);
      final list = (data as List)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<bool> create(Map<String, dynamic> payload) async {
    try {
      final data = await _api.post(ApiConstants.categories, data: payload);
      final cat = CategoryModel.fromJson(data as Map<String, dynamic>);
      state = AsyncValue.data([...state.value ?? [], cat]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _api.delete('${ApiConstants.categories}/$id');
      state = AsyncValue.data(
        (state.value ?? []).where((c) => c.id != id).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<CategoryModel>>>(
  (_) => CategoriesNotifier(),
);
