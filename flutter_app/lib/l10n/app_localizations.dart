import 'package:flutter/material.dart';

/// Hand-written minimal localizations delegate.
/// Replace with generated l10n after running `flutter gen-l10n`.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isArabic => locale.languageCode == 'ar';

  // ─── Proxy map ────────────────────────────────────────────────────────────
  static final Map<String, Map<String, String>> _strings = {
    'ar': {
      'appName': 'مصاريفي',
      'login': 'تسجيل الدخول',
      'register': 'إنشاء حساب',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'fullName': 'الاسم الكامل',
      'confirmPassword': 'تأكيد كلمة المرور',
      'forgotPassword': 'نسيت كلمة المرور؟',
      'noAccount': 'ليس لديك حساب؟',
      'haveAccount': 'لديك حساب بالفعل؟',
      'logout': 'تسجيل الخروج',
      'home': 'الرئيسية',
      'expenses': 'المصاريف',
      'statistics': 'الإحصائيات',
      'budgets': 'الميزانيات',
      'settings': 'الإعدادات',
      'addExpense': 'إضافة مصروف',
      'amount': 'المبلغ',
      'category': 'التصنيف',
      'description': 'الوصف',
      'date': 'التاريخ',
      'note': 'ملاحظة',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'delete': 'حذف',
      'edit': 'تعديل',
      'confirm': 'تأكيد',
      'today': 'اليوم',
      'yesterday': 'أمس',
      'thisMonth': 'هذا الشهر',
      'totalSpent': 'إجمالي المصاريف',
      'dailySummary': 'ملخص اليوم',
      'monthlySummary': 'ملخص الشهر',
      'categoryBreakdown': 'التوزيع حسب الفئة',
      'dailyTrend': 'الاتجاه اليومي',
      'monthlyComparison': 'مقارنة الأشهر',
      'spendingInsights': 'نصائح الإنفاق',
      'monthlyTotal': 'إجمالي الشهر',
      'aiInsights': 'تحليل ذكي',
      'budget': 'الميزانية',
      'spent': 'المصروف',
      'remaining': 'المتبقي',
      'addBudget': 'إضافة ميزانية',
      'goals': 'الأهداف',
      'addGoal': 'إضافة هدف',
      'targetAmount': 'المبلغ المستهدف',
      'currentAmount': 'المبلغ الحالي',
      'deadline': 'الموعد النهائي',
      'achieved': 'تم الإنجاز',
      'voiceInput': 'الإدخال الصوتي',
      'tapToSpeak': 'اضغط للتحدث',
      'listening': 'جارٍ الاستماع...',
      'processing': 'جارٍ المعالجة...',
      'transcript': 'النص المستخرج',
      'parsedExpenses': 'المصاريف المستخرجة',
      'confirmExpenses': 'تأكيد المصاريف',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'الإنجليزية',
      'theme': 'المظهر',
      'lightMode': 'فاتح',
      'darkMode': 'داكن',
      'systemMode': 'تلقائي',
      'currency': 'العملة',
      'profile': 'الملف الشخصي',
      'changePassword': 'تغيير كلمة المرور',
      'currentPassword': 'كلمة المرور الحالية',
      'newPassword': 'كلمة المرور الجديدة',
      'food': 'طعام',
      'transport': 'مواصلات',
      'shopping': 'تسوق',
      'health': 'صحة',
      'entertainment': 'ترفيه',
      'education': 'تعليم',
      'bills': 'فواتير',
      'housing': 'سكن',
      'other': 'أخرى',
      'recurring': 'متكرر',
      'noExpenses': 'لا يوجد مصاريف',
      'noExpensesYet': 'لم تسجل أي مصروف بعد',
      'startTracking': 'ابدأ بتسجيل مصاريفك اليومية',
      'error': 'خطأ',
      'success': 'نجاح',
      'loading': 'جارٍ التحميل...',
      'retry': 'إعادة المحاولة',
      'deleteConfirm': 'هل أنت متأكد من الحذف؟',
      'deleteWarning': 'لن يمكن التراجع عن هذا الإجراء',
      'expenseAdded': 'تم إضافة المصروف',
      'expenseUpdated': 'تم تحديث المصروف',
      'expenseDeleted': 'تم حذف المصروف',
      'budgetAdded': 'تم إضافة الميزانية',
      'goalAdded': 'تم إضافة الهدف',
      'passwordChanged': 'تم تغيير كلمة المرور',
      'profileUpdated': 'تم تحديث الملف الشخصي',
      'invalidEmail': 'البريد الإلكتروني غير صحيح',
      'passwordTooShort': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
      'passwordsNotMatch': 'كلمتا المرور غير متطابقتين',
      'fieldRequired': 'هذا الحقل مطلوب',
      'amountRequired': 'أدخل المبلغ',
      'invalidAmount': 'المبلغ غير صحيح',
      'selectDate': 'اختر التاريخ',
      'selectCategory': 'اختر التصنيف',
      'addCategory': 'إضافة تصنيف',
      'categoryName': 'اسم التصنيف',
      'exportReport': 'تصدير التقرير',
      'hi': 'مرحباً',
      'goodMorning': 'صباح الخير',
      'goodAfternoon': 'مساء الخير',
      'goodEvening': 'مساء النور',
      'recentExpenses': 'آخر المصروفات',
      'viewAll': 'عرض الكل',
      'progress': 'التقدم',
      'of': 'من',
    },
    'en': {
      'appName': 'Masareefi',
      'login': 'Login',
      'register': 'Create Account',
      'email': 'Email',
      'password': 'Password',
      'fullName': 'Full Name',
      'confirmPassword': 'Confirm Password',
      'forgotPassword': 'Forgot Password?',
      'noAccount': "Don't have an account?",
      'haveAccount': 'Already have an account?',
      'logout': 'Logout',
      'home': 'Home',
      'expenses': 'Expenses',
      'statistics': 'Statistics',
      'budgets': 'Budgets',
      'settings': 'Settings',
      'addExpense': 'Add Expense',
      'amount': 'Amount',
      'category': 'Category',
      'description': 'Description',
      'date': 'Date',
      'note': 'Note',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'edit': 'Edit',
      'confirm': 'Confirm',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'thisMonth': 'This Month',
      'totalSpent': 'Total Spent',
      'dailySummary': 'Daily Summary',
      'monthlySummary': 'Monthly Summary',
      'categoryBreakdown': 'Category Breakdown',
      'dailyTrend': 'Daily Trend',
      'monthlyComparison': 'Monthly Comparison',
      'spendingInsights': 'Spending Insights',
      'monthlyTotal': 'Monthly Total',
      'aiInsights': 'AI Insights',
      'budget': 'Budget',
      'spent': 'Spent',
      'remaining': 'Remaining',
      'addBudget': 'Add Budget',
      'goals': 'Goals',
      'addGoal': 'Add Goal',
      'targetAmount': 'Target Amount',
      'currentAmount': 'Current Amount',
      'deadline': 'Deadline',
      'achieved': 'Achieved',
      'voiceInput': 'Voice Input',
      'tapToSpeak': 'Tap to Speak',
      'listening': 'Listening...',
      'processing': 'Processing...',
      'transcript': 'Transcript',
      'parsedExpenses': 'Parsed Expenses',
      'confirmExpenses': 'Confirm Expenses',
      'language': 'Language',
      'arabic': 'Arabic',
      'english': 'English',
      'theme': 'Theme',
      'lightMode': 'Light',
      'darkMode': 'Dark',
      'systemMode': 'System',
      'currency': 'Currency',
      'profile': 'Profile',
      'changePassword': 'Change Password',
      'currentPassword': 'Current Password',
      'newPassword': 'New Password',
      'food': 'Food',
      'transport': 'Transport',
      'shopping': 'Shopping',
      'health': 'Health',
      'entertainment': 'Entertainment',
      'education': 'Education',
      'bills': 'Bills',
      'housing': 'Housing',
      'other': 'Other',
      'recurring': 'Recurring',
      'noExpenses': 'No Expenses',
      'noExpensesYet': 'No expenses recorded yet',
      'startTracking': 'Start tracking your daily expenses',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'retry': 'Retry',
      'deleteConfirm': 'Are you sure you want to delete?',
      'deleteWarning': 'This action cannot be undone',
      'expenseAdded': 'Expense added',
      'expenseUpdated': 'Expense updated',
      'expenseDeleted': 'Expense deleted',
      'budgetAdded': 'Budget added',
      'goalAdded': 'Goal added',
      'passwordChanged': 'Password changed',
      'profileUpdated': 'Profile updated',
      'invalidEmail': 'Invalid email address',
      'passwordTooShort': 'Password must be at least 8 characters',
      'passwordsNotMatch': 'Passwords do not match',
      'fieldRequired': 'This field is required',
      'amountRequired': 'Enter amount',
      'invalidAmount': 'Invalid amount',
      'selectDate': 'Select Date',
      'selectCategory': 'Select Category',
      'addCategory': 'Add Category',
      'categoryName': 'Category Name',
      'exportReport': 'Export Report',
      'hi': 'Hi',
      'goodMorning': 'Good Morning',
      'goodAfternoon': 'Good Afternoon',
      'goodEvening': 'Good Evening',
      'recentExpenses': 'Recent Expenses',
      'viewAll': 'View All',
      'progress': 'Progress',
      'of': 'of',
    },
  };

  String _t(String key) =>
      _strings[locale.languageCode]?[key] ??
      _strings['en']![key] ??
      key;

  // ─── Accessors ────────────────────────────────────────────────────────────
  String get appName => _t('appName');
  String get login => _t('login');
  String get register => _t('register');
  String get email => _t('email');
  String get password => _t('password');
  String get fullName => _t('fullName');
  String get confirmPassword => _t('confirmPassword');
  String get forgotPassword => _t('forgotPassword');
  String get noAccount => _t('noAccount');
  String get haveAccount => _t('haveAccount');
  String get logout => _t('logout');
  String get home => _t('home');
  String get expenses => _t('expenses');
  String get statistics => _t('statistics');
  String get budgets => _t('budgets');
  String get settings => _t('settings');
  String get addExpense => _t('addExpense');
  String get amount => _t('amount');
  String get category => _t('category');
  String get description => _t('description');
  String get date => _t('date');
  String get note => _t('note');
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get confirm => _t('confirm');
  String get today => _t('today');
  String get yesterday => _t('yesterday');
  String get thisMonth => _t('thisMonth');
  String get totalSpent => _t('totalSpent');
  String get dailySummary => _t('dailySummary');
  String get monthlySummary => _t('monthlySummary');
  String get categoryBreakdown => _t('categoryBreakdown');
  String get dailyTrend => _t('dailyTrend');
  String get monthlyComparison => _t('monthlyComparison');
  String get spendingInsights => _t('spendingInsights');
  String get monthlyTotal => _t('monthlyTotal');
  String get aiInsights => _t('aiInsights');
  String get budget => _t('budget');
  String get spent => _t('spent');
  String get remaining => _t('remaining');
  String get addBudget => _t('addBudget');
  String get goals => _t('goals');
  String get addGoal => _t('addGoal');
  String get targetAmount => _t('targetAmount');
  String get currentAmount => _t('currentAmount');
  String get deadline => _t('deadline');
  String get achieved => _t('achieved');
  String get voiceInput => _t('voiceInput');
  String get tapToSpeak => _t('tapToSpeak');
  String get listening => _t('listening');
  String get processing => _t('processing');
  String get transcript => _t('transcript');
  String get parsedExpenses => _t('parsedExpenses');
  String get confirmExpenses => _t('confirmExpenses');
  String get language => _t('language');
  String get arabic => _t('arabic');
  String get english => _t('english');
  String get theme => _t('theme');
  String get lightMode => _t('lightMode');
  String get darkMode => _t('darkMode');
  String get systemMode => _t('systemMode');
  String get currency => _t('currency');
  String get profile => _t('profile');
  String get changePassword => _t('changePassword');
  String get currentPassword => _t('currentPassword');
  String get newPassword => _t('newPassword');
  String get food => _t('food');
  String get transport => _t('transport');
  String get shopping => _t('shopping');
  String get health => _t('health');
  String get entertainment => _t('entertainment');
  String get education => _t('education');
  String get bills => _t('bills');
  String get housing => _t('housing');
  String get other => _t('other');
  String get recurring => _t('recurring');
  String get noExpenses => _t('noExpenses');
  String get noExpensesYet => _t('noExpensesYet');
  String get startTracking => _t('startTracking');
  String get error => _t('error');
  String get success => _t('success');
  String get loading => _t('loading');
  String get retry => _t('retry');
  String get deleteConfirm => _t('deleteConfirm');
  String get deleteWarning => _t('deleteWarning');
  String get expenseAdded => _t('expenseAdded');
  String get expenseUpdated => _t('expenseUpdated');
  String get expenseDeleted => _t('expenseDeleted');
  String get budgetAdded => _t('budgetAdded');
  String get goalAdded => _t('goalAdded');
  String get passwordChanged => _t('passwordChanged');
  String get profileUpdated => _t('profileUpdated');
  String get invalidEmail => _t('invalidEmail');
  String get passwordTooShort => _t('passwordTooShort');
  String get passwordsNotMatch => _t('passwordsNotMatch');
  String get fieldRequired => _t('fieldRequired');
  String get amountRequired => _t('amountRequired');
  String get invalidAmount => _t('invalidAmount');
  String get selectDate => _t('selectDate');
  String get selectCategory => _t('selectCategory');
  String get addCategory => _t('addCategory');
  String get categoryName => _t('categoryName');
  String get exportReport => _t('exportReport');
  String get hi => _t('hi');
  String get goodMorning => _t('goodMorning');
  String get goodAfternoon => _t('goodAfternoon');
  String get goodEvening => _t('goodEvening');
  String get recentExpenses => _t('recentExpenses');
  String get viewAll => _t('viewAll');
  String get progress => _t('progress');
  String get of => _t('of');

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return goodMorning;
    if (hour < 17) return goodAfternoon;
    return goodEvening;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
