import 'category_model.dart';

class BudgetModel {
  final String id;
  final String? categoryId;
  final double amount;
  final int month;
  final int year;
  final CategoryModel? category;
  final double spent;
  final double remaining;
  final double percentage;

  const BudgetModel({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.month,
    required this.year,
    this.category,
    required this.spent,
    required this.remaining,
    required this.percentage,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) => BudgetModel(
        id: json['id'] as String,
        categoryId: json['category_id'] as String?,
        amount: (json['amount'] as num).toDouble(),
        month: json['month'] as int,
        year: json['year'] as int,
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        spent: (json['spent'] as num?)?.toDouble() ?? 0.0,
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

class GoalModel {
  final String id;
  final String title;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final String? deadline;
  final String currency;
  final bool isAchieved;
  final double progressPercentage;

  const GoalModel({
    required this.id,
    required this.title,
    this.description,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.currency,
    required this.isAchieved,
    required this.progressPercentage,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) => GoalModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        targetAmount: (json['target_amount'] as num).toDouble(),
        currentAmount: (json['current_amount'] as num).toDouble(),
        deadline: json['deadline'] as String?,
        currency: json['currency'] as String? ?? 'IQD',
        isAchieved: json['is_achieved'] as bool? ?? false,
        progressPercentage:
            (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

class CategoryStat {
  final String categoryId;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String color;
  final double total;
  final int count;
  final double percentage;

  const CategoryStat({
    required this.categoryId,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.color,
    required this.total,
    required this.count,
    required this.percentage,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) => CategoryStat(
        categoryId: json['category_id'] as String,
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        icon: json['icon'] as String? ?? '💰',
        color: json['color'] as String? ?? '#9E9E9E',
        total: (json['total'] as num).toDouble(),
        count: json['count'] as int,
        percentage: (json['percentage'] as num).toDouble(),
      );

  String localName(String lang) => lang == 'ar' ? nameAr : nameEn;
}

class DailyTrendPoint {
  final DateTime date;
  final double total;
  final int count;

  const DailyTrendPoint({
    required this.date,
    required this.total,
    required this.count,
  });

  factory DailyTrendPoint.fromJson(Map<String, dynamic> json) =>
      DailyTrendPoint(
        date: DateTime.parse(json['date'] as String),
        total: (json['total'] as num).toDouble(),
        count: json['count'] as int,
      );
}

class MonthlyPoint {
  final int year;
  final int month;
  final double total;

  const MonthlyPoint({
    required this.year,
    required this.month,
    required this.total,
  });

  factory MonthlyPoint.fromJson(Map<String, dynamic> json) => MonthlyPoint(
        year: json['year'] as int,
        month: json['month'] as int,
        total: (json['total'] as num).toDouble(),
      );
}
