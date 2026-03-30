import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // ── عنوان السيرفر ──────────────────────────────────────────
  // لتغيير الوضع: غيّر قيمة _useNetworkIp إلى true لأجهزة الشبكة
  static const bool _useNetworkIp = false;
  static const String _networkIp = '192.168.68.120';

  static final baseUrl = _useNetworkIp
      ? 'http://$_networkIp:8000/api/v1' // جهاز حقيقي على نفس الشبكة
      : kIsWeb
          ? 'http://localhost:8000/api/v1' // المتصفح (Flutter Web على 8081)
          : 'http://10.0.2.2:8000/api/v1'; // محاكي Android → localhost

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
