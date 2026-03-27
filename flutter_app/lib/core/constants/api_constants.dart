import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Automatically selects the correct URL based on platform
  static final baseUrl = kIsWeb
      ? 'http://localhost:8000/api/v1' // Browser (Flutter Web)
      : 'http://10.0.2.2:8000/api/v1'; // Android emulator → localhost

  // Auth
  static const register = '/auth/register';
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const meUpdate = '/auth/me';
  static const changePassword = '/auth/change-password';

  // Expenses
  static const expenses = '/expenses';
  static const expensesBulk = '/expenses/bulk';

  // Categories
  static const categories = '/categories';

  // Statistics
  static const statsDaily = '/statistics/daily';
  static const statsMonthly = '/statistics/monthly';
  static const statsCategories = '/statistics/categories';
  static const statsTrend = '/statistics/trend';
  static const statsComparison = '/statistics/comparison';
  static const statsInsights = '/statistics/insights';

  // Budgets
  static const budgets = '/budgets';
  static const goals = '/budgets/goals';

  // Voice
  static const voiceParse = '/voice/parse-expense';
}
