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
  static const String colAiConversations = 'ai_conversations';
  static const String colMarketPrices = 'market_prices';

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
    'Other',
  ];

  // Expense categories
  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Misc',
    'Investment',
    'Business',
    'Other',
  ];

  // AI rate limit
  static const int aiDailyLimit = 20;

  // Inactivity sign-out duration
  static const int inactivityDays = 30;

  // Default currency
  static const String defaultCurrency = 'USD';
}
