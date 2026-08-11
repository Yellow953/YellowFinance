import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yellow_finance/core/services/user_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => UserPrefs.bind(null));

  test('keys are namespaced per account', () {
    UserPrefs.bind('uid1');
    final first = UserPrefs.keyFor('nofap_enabled');

    UserPrefs.bind('uid2');
    final second = UserPrefs.keyFor('nofap_enabled');

    expect(first, isNot(second));
  });

  test('keys are null while signed out, so writes have nowhere to land', () {
    UserPrefs.bind(null);
    expect(UserPrefs.keyFor('nofap_enabled'), isNull);
  });

  test('one account cannot read another account\'s setting', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    UserPrefs.bind('uid1');
    await prefs.setBool(UserPrefs.keyFor('nofap_enabled')!, true);

    UserPrefs.bind('uid2');
    expect(prefs.getBool(UserPrefs.keyFor('nofap_enabled')!), isNull);

    UserPrefs.bind('uid1');
    expect(prefs.getBool(UserPrefs.keyFor('nofap_enabled')!), isTrue);
  });

  group('legacy migration', () {
    test('adopts pre-namespacing settings for the signed-in account', () async {
      SharedPreferences.setMockInitialValues({
        'nofap_enabled': true,
        'nofap_hour': 22,
        'home_excluded_income_categories': <String>['Salary'],
        'hide_balances': true,
      });
      final prefs = await SharedPreferences.getInstance();

      UserPrefs.bind('uid1');
      await UserPrefs.migrateLegacyKeys();

      expect(prefs.getBool(UserPrefs.keyFor('nofap_enabled')!), isTrue);
      expect(prefs.getInt(UserPrefs.keyFor('nofap_hour')!), 22);
      expect(
        prefs.getStringList(
            UserPrefs.keyFor('home_excluded_income_categories')!),
        ['Salary'],
      );
      expect(prefs.getBool(UserPrefs.keyFor('hide_balances')!), isTrue);
    });

    test('removes the shared key so a second account starts clean', () async {
      SharedPreferences.setMockInitialValues({'nofap_enabled': true});
      final prefs = await SharedPreferences.getInstance();

      UserPrefs.bind('uid1');
      await UserPrefs.migrateLegacyKeys();

      expect(prefs.getBool('nofap_enabled'), isNull);

      UserPrefs.bind('uid2');
      await UserPrefs.migrateLegacyKeys();
      expect(prefs.getBool(UserPrefs.keyFor('nofap_enabled')!), isNull);
    });

    test('never overwrites a setting the account already has', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      UserPrefs.bind('uid1');
      await prefs.setInt(UserPrefs.keyFor('nofap_hour')!, 7);
      await prefs.setInt('nofap_hour', 22); // stale device-global leftover

      await UserPrefs.migrateLegacyKeys();

      expect(prefs.getInt(UserPrefs.keyFor('nofap_hour')!), 7);
      expect(prefs.getInt('nofap_hour'), isNull);
    });

    test('is a no-op while signed out', () async {
      SharedPreferences.setMockInitialValues({'nofap_enabled': true});
      final prefs = await SharedPreferences.getInstance();

      UserPrefs.bind(null);
      await UserPrefs.migrateLegacyKeys();

      // Left in place for whoever signs in first to claim.
      expect(prefs.getBool('nofap_enabled'), isTrue);
    });
  });
}
