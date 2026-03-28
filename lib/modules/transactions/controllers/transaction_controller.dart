import 'dart:async';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/controllers/auth_controller.dart';

/// Manages the full transactions list and add-transaction form.
class TransactionController extends GetxController {
  final TransactionRepository _txnRepo;

  final RxList<TransactionModel> transactions = <TransactionModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  // Add transaction form state
  final RxString selectedType = AppConstants.txnExpense.obs;
  final RxString selectedCategory = AppConstants.expenseCategories.first.obs;

  // Filter state
  final RxString filterType = 'All'.obs;
  final RxString filterCategory = 'All'.obs;

  static const filterTypes = ['All', 'Income', 'Expense'];

  StreamSubscription<List<TransactionModel>>? _sub;

  TransactionController({required TransactionRepository txnRepo})
      : _txnRepo = txnRepo;

  @override
  void onInit() {
    super.onInit();
    _subscribe();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _subscribe() {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    _sub = _txnRepo.watchTransactions(uid).listen(
      (txns) {
        transactions.assignAll(txns);
        isLoading.value = false;
      },
      onError: (_) => isLoading.value = false,
    );
  }

  /// Switches the type and resets the category picker.
  void setType(String type) {
    selectedType.value = type;
    selectedCategory.value = type == AppConstants.txnIncome
        ? AppConstants.incomeCategories.first
        : AppConstants.expenseCategories.first;
  }

  List<String> get categories => selectedType.value == AppConstants.txnIncome
      ? AppConstants.incomeCategories
      : AppConstants.expenseCategories;

  /// Categories available for the active type filter (for filter chips).
  List<String> get filterCategories {
    if (filterType.value == 'Income') return AppConstants.incomeCategories;
    if (filterType.value == 'Expense') return AppConstants.expenseCategories;
    return [...AppConstants.incomeCategories, ...AppConstants.expenseCategories];
  }

  List<TransactionModel> get filteredTransactions {
    return transactions.where((t) {
      if (filterType.value == 'Income' && !t.isIncome) return false;
      if (filterType.value == 'Expense' && !t.isExpense) return false;
      if (filterCategory.value != 'All' &&
          t.category != filterCategory.value) { return false; }
      return true;
    }).toList();
  }

  void setFilterType(String type) {
    filterType.value = type;
    filterCategory.value = 'All'; // reset category when type changes
  }

  void setFilterCategory(String category) {
    filterCategory.value = category;
  }

  /// Saves a new transaction.
  Future<void> addTransaction({
    required String amountText,
    required String title,
    String description = '',
    required DateTime date,
  }) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;

    final parsed = double.tryParse(amountText.replaceAll(',', ''));
    if (parsed == null || parsed <= 0) return;
    final amountCents = (parsed * 100).round();

    isSaving.value = true;
    try {
      await _txnRepo.addTransaction(
        uid: uid,
        type: selectedType.value,
        amount: amountCents,
        category: selectedCategory.value,
        title: title,
        description: description,
        date: date,
      );
      Get.back();
      AppSnackbar.success('Transaction added');
    } catch (e) {
      AppSnackbar.error('Could not save transaction.');
    } finally {
      isSaving.value = false;
    }
  }

  /// Deletes a transaction.
  Future<void> deleteTransaction(String txnId) async {
    final uid = Get.find<AuthController>().user.value?.uid;
    if (uid == null) return;
    try {
      await _txnRepo.deleteTransaction(uid, txnId);
    } catch (_) {
      AppSnackbar.error('Could not delete transaction.');
    }
  }
}
