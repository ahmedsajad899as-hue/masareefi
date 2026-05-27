import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_constants.dart';
import '../models/market_model.dart';
import '../services/api_service.dart';

class SupplierInvoicesState {
  final List<SupplierInvoiceModel> invoices;
  final bool isLoading;
  final String? error;

  const SupplierInvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
  });

  SupplierInvoicesState copyWith({
    List<SupplierInvoiceModel>? invoices,
    bool? isLoading,
    String? error,
  }) =>
      SupplierInvoicesState(
        invoices: invoices ?? this.invoices,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class SupplierInvoicesNotifier extends StateNotifier<SupplierInvoicesState> {
  SupplierInvoicesNotifier() : super(const SupplierInvoicesState());

  final _api = ApiService.instance;

  Future<void> load({bool? isPaid}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params =
          isPaid != null ? {'is_paid': isPaid.toString()} : null;
      final data =
          await _api.get(ApiConstants.marketSuppliers, params: params);
      final list = (data as List<dynamic>)
          .map((e) =>
              SupplierInvoiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(invoices: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<SupplierInvoiceModel?> create({
    required String supplierName,
    required DateTime invoiceDate,
    DateTime? dueDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final data = await _api.post(ApiConstants.marketSuppliers, data: {
        'supplier_name': supplierName,
        'invoice_date': invoiceDate.toIso8601String(),
        if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'items': items,
      });
      final invoice =
          SupplierInvoiceModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(invoices: [invoice, ...state.invoices]);
      return invoice;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> markPaid(String invoiceId) async {
    try {
      final data = await _api
          .patch('${ApiConstants.marketSuppliers}/$invoiceId/pay', data: {});
      final updated =
          SupplierInvoiceModel.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(
        invoices: state.invoices
            .map((i) => i.id == invoiceId ? updated : i)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String invoiceId) async {
    try {
      await _api.delete('${ApiConstants.marketSuppliers}/$invoiceId');
      state = state.copyWith(
        invoices: state.invoices.where((i) => i.id != invoiceId).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final supplierInvoicesProvider =
    StateNotifierProvider<SupplierInvoicesNotifier, SupplierInvoicesState>(
  (ref) => SupplierInvoicesNotifier(),
);
