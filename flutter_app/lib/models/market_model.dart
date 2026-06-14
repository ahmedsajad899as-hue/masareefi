import 'dart:convert';

class MarketCustomerModel {
  final String id;
  final String marketOwnerId;
  final String name;
  final String? phone;
  final String? notes;
  final String? linkedUserId;
  final DateTime createdAt;
  final double totalDebt;
  final int unpaidSalesCount;

  const MarketCustomerModel({
    required this.id,
    required this.marketOwnerId,
    required this.name,
    this.phone,
    this.notes,
    this.linkedUserId,
    required this.createdAt,
    this.totalDebt = 0,
    this.unpaidSalesCount = 0,
  });

  factory MarketCustomerModel.fromJson(Map<String, dynamic> j) =>
      MarketCustomerModel(
        id: j['id'] as String,
        marketOwnerId: j['market_owner_id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        notes: j['notes'] as String?,
        linkedUserId: j['linked_user_id'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        totalDebt: (j['total_debt'] as num?)?.toDouble() ?? 0,
        unpaidSalesCount: j['unpaid_sales_count'] as int? ?? 0,
      );
}

class MarketSaleItemModel {
  final String id;
  final String productName;
  final double quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;

  const MarketSaleItemModel({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory MarketSaleItemModel.fromJson(Map<String, dynamic> j) =>
      MarketSaleItemModel(
        id: j['id'] as String,
        productName: j['product_name'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unitPrice: (j['unit_price'] as num).toDouble(),
      );
}

class MarketSaleModel {
  final String id;
  final String marketOwnerId;
  final String customerId;
  final String customerName;
  final DateTime saleDate;
  final String? notes;
  final double totalAmount;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime createdAt;
  final List<MarketSaleItemModel> items;

  const MarketSaleModel({
    required this.id,
    required this.marketOwnerId,
    required this.customerId,
    required this.customerName,
    required this.saleDate,
    this.notes,
    required this.totalAmount,
    required this.isPaid,
    this.paidAt,
    required this.createdAt,
    required this.items,
  });

  factory MarketSaleModel.fromJson(Map<String, dynamic> j) => MarketSaleModel(
        id: j['id'] as String,
        marketOwnerId: j['market_owner_id'] as String,
        customerId: j['customer_id'] as String,
        customerName: j['customer_name'] as String? ?? '',
        saleDate: DateTime.parse(j['sale_date'] as String),
        notes: j['notes'] as String?,
        totalAmount: (j['total_amount'] as num).toDouble(),
        isPaid: j['is_paid'] as bool? ?? false,
        paidAt: j['paid_at'] != null
            ? DateTime.parse(j['paid_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        items: (j['items'] as List<dynamic>? ?? [])
            .map((i) => MarketSaleItemModel.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

class SupplierInvoiceItemModel {
  final String id;
  final String productName;
  final double quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;

  const SupplierInvoiceItemModel({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory SupplierInvoiceItemModel.fromJson(Map<String, dynamic> j) =>
      SupplierInvoiceItemModel(
        id: j['id'] as String,
        productName: j['product_name'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unitPrice: (j['unit_price'] as num).toDouble(),
      );
}

class SupplierInvoiceModel {
  final String id;
  final String marketOwnerId;
  final String supplierName;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final double totalAmount;
  final bool isPaid;
  final DateTime? paidAt;
  final String? notes;
  final DateTime createdAt;
  final List<SupplierInvoiceItemModel> items;

  const SupplierInvoiceModel({
    required this.id,
    required this.marketOwnerId,
    required this.supplierName,
    required this.invoiceDate,
    this.dueDate,
    required this.totalAmount,
    required this.isPaid,
    this.paidAt,
    this.notes,
    required this.createdAt,
    required this.items,
  });

  factory SupplierInvoiceModel.fromJson(Map<String, dynamic> j) =>
      SupplierInvoiceModel(
        id: j['id'] as String,
        marketOwnerId: j['market_owner_id'] as String,
        supplierName: j['supplier_name'] as String,
        invoiceDate: DateTime.parse(j['invoice_date'] as String),
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
        totalAmount: (j['total_amount'] as num).toDouble(),
        isPaid: j['is_paid'] as bool? ?? false,
        paidAt: j['paid_at'] != null
            ? DateTime.parse(j['paid_at'] as String)
            : null,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        items: (j['items'] as List<dynamic>? ?? [])
            .map((i) =>
                SupplierInvoiceItemModel.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

// ─── My Market Debts (regular user) ──────────────────────────────────────────

class MyDebtSaleItemModel {
  final String productName;
  final double quantity;
  final double unitPrice;

  const MyDebtSaleItemModel({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory MyDebtSaleItemModel.fromJson(Map<String, dynamic> j) =>
      MyDebtSaleItemModel(
        productName: j['product_name'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        unitPrice: (j['unit_price'] as num).toDouble(),
      );
}

class MyDebtSaleModel {
  final String saleId;
  final DateTime saleDate;
  final double totalAmount;
  final String? notes;
  final List<MyDebtSaleItemModel> items;

  const MyDebtSaleModel({
    required this.saleId,
    required this.saleDate,
    required this.totalAmount,
    this.notes,
    required this.items,
  });

  factory MyDebtSaleModel.fromJson(Map<String, dynamic> j) => MyDebtSaleModel(
        saleId: j['sale_id'] as String,
        saleDate: DateTime.parse(j['sale_date'] as String),
        totalAmount: (j['total_amount'] as num).toDouble(),
        notes: j['notes'] as String?,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((i) =>
                MyDebtSaleItemModel.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

// ─── Market Product (catalog) ─────────────────────────────────────────────────

class MarketProductModel {
  final String id;
  final String name;
  final double unitPrice;
  final String? barcode;
  final List<String> barcodes;
  final DateTime updatedAt;
  final DateTime createdAt;

  const MarketProductModel({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.barcode,
    this.barcodes = const [],
    required this.updatedAt,
    required this.createdAt,
  });

  factory MarketProductModel.fromJson(Map<String, dynamic> j) =>
      MarketProductModel(
        id: j['id'] as String,
        name: j['name'] as String,
        unitPrice: (j['unit_price'] as num).toDouble(),
        barcode: j['barcode'] as String?,
        barcodes: (j['barcodes'] as List<dynamic>? ?? []).cast<String>(),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit_price': unitPrice,
        if (barcode != null) 'barcode': barcode,
      };

  MarketProductModel copyWith({
    String? name,
    double? unitPrice,
    String? barcode,
    List<String>? barcodes,
    bool clearBarcode = false,
  }) =>
      MarketProductModel(
        id: id,
        name: name ?? this.name,
        unitPrice: unitPrice ?? this.unitPrice,
        barcode: clearBarcode ? null : (barcode ?? this.barcode),
        barcodes: barcodes ?? this.barcodes,
        updatedAt: updatedAt,
        createdAt: createdAt,
      );
}

class MyMarketDebtModel {
  final String marketOwnerId;
  final String storeName;
  final String marketOwnerName;
  final double totalUnpaid;
  final List<MyDebtSaleModel> sales;

  const MyMarketDebtModel({
    required this.marketOwnerId,
    required this.storeName,
    required this.marketOwnerName,
    required this.totalUnpaid,
    required this.sales,
  });

  factory MyMarketDebtModel.fromJson(Map<String, dynamic> j) =>
      MyMarketDebtModel(
        marketOwnerId: j['market_owner_id'] as String,
        storeName: j['store_name'] as String,
        marketOwnerName: j['market_owner_name'] as String,
        totalUnpaid: (j['total_unpaid'] as num).toDouble(),
        sales: (j['sales'] as List<dynamic>? ?? [])
            .map((s) => MyDebtSaleModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
