/// App-wide string constants and configuration values.
abstract class AppConstants {
  // App
  static const String appName = 'YellowFinance';
  static const String appTagline = 'Your money, clearly.';

  // Firebase Functions
  static const String fnAnalyzeFinances = 'analyzeFinances';
  static const String fnFetchPrices = 'fetchPrices';

  // Firestore collections
  static const String colUsers = 'users';
  static const String colTransactions = 'transactions';
  static const String colPortfolio = 'portfolio';
  static const String colMarketPrices = 'market_prices';
  static const String colSports = 'sports';
  static const String colTodos = 'todos';
  static const String colAllSports = 'all_sports';
  static const String colBudgets = 'budgets';
  static const String colGoals = 'goals';
  static const String colDiary = 'diary';

  /// Set at sign-out, read and cleared in `main()`: Firestore's on-disk cache
  /// can only be wiped before the client starts, so the request has to survive
  /// until the next launch.
  static const String prefPendingCacheClear = 'pending_firestore_cache_clear';

  /// Sentinel [BudgetModel.category] meaning "every category of this type".
  /// Not a real category name, so it can never collide with one.
  static const String budgetAllCategories = '__all__';

  // Transaction types
  static const String txnIncome = 'income';
  static const String txnExpense = 'expense';

  // Asset types
  static const String assetCrypto = 'crypto';
  static const String assetStock = 'stock';
  static const String assetEtf = 'etf';
  static const String assetGold = 'gold';
  static const String assetSilver = 'silver';

  // Income categories
  static const List<String> incomeCategories = [
    'Salary',
    'Project',
    'Business',
    'Debt',
    'Other',
  ];

  // Expense categories
  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Misc',
    'Investment',
    'Business',
    'Debt',
    'Other',
  ];

  // Sport categories
  static const List<String> sportCategories = [
    'Push Ups',
    'Pull Ups',
    'ABS',
    'Running',
    'Walking',
    'Activity',
    'Gym',
    'Other',
  ];

  // Input length limits.
  //
  // A Firestore document is capped at ~1 MB, and dictation can produce a lot of
  // text quickly, so free-text fields are bounded rather than trusted. Enforced
  // in the controllers as well as the fields — the field limit is a courtesy,
  // the controller clamp is the guarantee.
  static const int maxDiaryTitleLength = 120;
  static const int maxDiaryBodyLength = 20000;
  static const int maxGoalTitleLength = 60;
  static const int maxBudgetNameLength = 40;

  // Inactivity sign-out duration
  static const int inactivityDays = 30;

  // Default currency
  static const String defaultCurrency = 'USD';
}
