import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/transaction_model.dart';
import 'user_prefs.dart';

/// Which income / expense categories count toward the Home screen figures.
///
/// Only affects what Home shows — Transactions, Reports and the AI context
/// still see every category.
///
/// *Excluded* categories are persisted rather than included ones, so a category
/// added to `AppConstants` later shows up on Home by default instead of
/// silently vanishing for users who saved their settings beforehand.
class HomeCategoryFilterService extends GetxService {
  static const _prefIncomeExcluded = 'home_excluded_income_categories';
  static const _prefExpenseExcluded = 'home_excluded_expense_categories';

  /// Income categories hidden from the Home screen.
  final RxSet<String> excludedIncome = <String>{}.obs;

  /// Expense categories hidden from the Home screen.
  final RxSet<String> excludedExpense = <String>{}.obs;

  /// Loads persisted selections. Register with `Get.putAsync`.
  Future<HomeCategoryFilterService> init() async {
    await reload();
    return this;
  }

  /// Re-reads the bound account's selections, replacing whatever is held.
  ///
  /// Called on sign-in as well as at startup: this service is permanent, so it
  /// outlives the session that loaded it and has to be re-pointed when the
  /// account changes.
  Future<void> reload() async {
    final incomeKey = UserPrefs.keyFor(_prefIncomeExcluded);
    final expenseKey = UserPrefs.keyFor(_prefExpenseExcluded);
    if (incomeKey == null || expenseKey == null) {
      clear();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    excludedIncome
      ..clear()
      ..addAll(prefs.getStringList(incomeKey) ?? const <String>[]);
    excludedExpense
      ..clear()
      ..addAll(prefs.getStringList(expenseKey) ?? const <String>[]);
  }

  /// Drops the in-memory selections on sign-out. The stored values stay put so
  /// the account gets them back on its next sign-in.
  void clear() {
    excludedIncome.clear();
    excludedExpense.clear();
  }

  /// Whether [txn] should be counted and listed on Home.
  bool includes(TransactionModel txn) => isCategoryIncluded(
        income: txn.isIncome,
        category: txn.category,
      );

  /// Whether [category] is counted on Home for the given transaction kind.
  bool isCategoryIncluded({required bool income, required String category}) =>
      !(income ? excludedIncome : excludedExpense).contains(category);

  /// Includes or excludes [category] on Home and persists the choice.
  Future<void> setCategoryIncluded({
    required bool income,
    required String category,
    required bool included,
  }) async {
    final excluded = income ? excludedIncome : excludedExpense;
    if (included) {
      excluded.remove(category);
    } else {
      excluded.add(category);
    }
    await _persist(income);
  }

  /// Replaces the whole selection for one transaction kind in a single write.
  ///
  /// [categories] is the full set of options; everything not in [included] is
  /// excluded. Doing this as one update avoids the interleaved writes (and the
  /// UI flicker) of toggling categories one by one.
  Future<void> setSelection({
    required bool income,
    required List<String> categories,
    required Set<String> included,
  }) async {
    final excluded = income ? excludedIncome : excludedExpense;
    excluded
      ..removeAll(categories)
      ..addAll(categories.where((c) => !included.contains(c)));
    await _persist(income);
  }

  Future<void> _persist(bool income) async {
    final key = UserPrefs.keyFor(
      income ? _prefIncomeExcluded : _prefExpenseExcluded,
    );
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      (income ? excludedIncome : excludedExpense).toList(),
    );
  }
}
