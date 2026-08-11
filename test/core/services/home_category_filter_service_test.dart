import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_finance/core/services/home_category_filter_service.dart';
import 'package:yellow_finance/core/services/user_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => UserPrefs.bind(null));

  test('a second account does not inherit the first account\'s filters',
      () async {
    final service = HomeCategoryFilterService();

    UserPrefs.bind('uid1');
    await service.init();
    await service.setCategoryIncluded(
      income: false,
      category: 'Food',
      included: false,
    );
    expect(service.excludedExpense, contains('Food'));

    // Sign out, then in as somebody else. The service is permanent, so it is
    // the same instance across both sessions.
    UserPrefs.bind(null);
    service.clear();
    UserPrefs.bind('uid2');
    await service.reload();

    expect(service.excludedExpense, isEmpty);
    expect(
      service.isCategoryIncluded(income: false, category: 'Food'),
      isTrue,
    );
  });

  test('an account gets its own filters back on the next sign-in', () async {
    final service = HomeCategoryFilterService();

    UserPrefs.bind('uid1');
    await service.init();
    await service.setCategoryIncluded(
      income: true,
      category: 'Salary',
      included: false,
    );

    UserPrefs.bind(null);
    service.clear();
    UserPrefs.bind('uid1');
    await service.reload();

    expect(service.excludedIncome, contains('Salary'));
  });

  test('signed out, nothing is held in memory and writes are dropped',
      () async {
    final service = HomeCategoryFilterService();

    UserPrefs.bind(null);
    await service.init();
    await service.setCategoryIncluded(
      income: false,
      category: 'Food',
      included: false,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home_excluded_expense_categories'), isNull);
  });
}
