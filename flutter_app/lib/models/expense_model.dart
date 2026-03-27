import 'category_model.dart';

class ExpenseModel {
  final String id;
  final String? categoryId;
  final double amount;
  final String currency;
  final String? description;
  final DateTime expenseDate;
  final bool isRecurring;
  final String? recurringType;
  final String? note;
  final CategoryModel? category;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.currency,
    this.description,
    required this.expenseDate,
    required this.isRecurring,
    this.recurringType,
    this.note,
    this.category,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        categoryId: json['category_id'] as String?,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'IQD',
        description: json['description'] as String?,
        expenseDate: DateTime.parse(json['expense_date'] as String),
        isRecurring: json['is_recurring'] as bool? ?? false,
        recurringType: json['recurring_type'] as String?,
        note: json['note'] as String?,
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        if (categoryId != null) 'category_id': categoryId,
        'amount': amount,
        'currency': currency,
        if (description != null) 'description': description,
        'expense_date': expenseDate.toIso8601String().split('T').first,
        'is_recurring': isRecurring,
        if (recurringType != null) 'recurring_type': recurringType,
        if (note != null) 'note': note,
      };
}

class ParsedExpenseItem {
  final double amount;
  final String currency;
  final String categoryHint;
  final String description;
  final DateTime expenseDate;
  final double confidence;

  // Set by user during confirmation
  String? resolvedCategoryId;

  ParsedExpenseItem({
    required this.amount,
    required this.currency,
    required this.categoryHint,
    required this.description,
    required this.expenseDate,
    required this.confidence,
    this.resolvedCategoryId,
  });

  factory ParsedExpenseItem.fromJson(Map<String, dynamic> json) =>
      ParsedExpenseItem(
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'IQD',
        categoryHint: json['category_hint'] as String? ?? '',
        description: json['description'] as String? ?? '',
        expenseDate: DateTime.parse(json['expense_date'] as String),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toExpenseCreateJson() => {
        if (resolvedCategoryId != null) 'category_id': resolvedCategoryId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'expense_date': expenseDate.toIso8601String().split('T').first,
        'is_recurring': false,
      };
}

class VoiceParseResponse {
  final String transcript;
  final List<ParsedExpenseItem> parsedExpenses;

  const VoiceParseResponse({
    required this.transcript,
    required this.parsedExpenses,
  });

  factory VoiceParseResponse.fromJson(Map<String, dynamic> json) =>
      VoiceParseResponse(
        transcript: json['transcript'] as String,
        parsedExpenses: (json['parsed_expenses'] as List)
            .map((e) => ParsedExpenseItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
