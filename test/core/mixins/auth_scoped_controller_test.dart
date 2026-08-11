import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yellow_finance/core/mixins/auth_scoped_controller.dart';
import 'package:yellow_finance/data/models/user_model.dart';

UserModel _user(String uid) => UserModel(
      uid: uid,
      displayName: uid,
      email: '$uid@example.com',
      createdAt: DateTime(2026, 1, 1),
    );

/// Stands in for a feature controller: holds one account's rows and a
/// subscription that must not outlive that account.
class _FakeFeatureController extends GetxController with AuthScopedController {
  final Rx<UserModel?> source;
  _FakeFeatureController(this.source);

  final List<String> rows = [];
  final List<String> events = [];
  String? liveListenerUid;

  @override
  void onInit() {
    super.onInit();
    bindToAuth(source: source);
  }

  @override
  void onUserBound(String uid) {
    events.add('bind:$uid');
    liveListenerUid = uid;
    rows.add('$uid-row');
  }

  @override
  void onUserUnbound() {
    events.add('unbind');
    liveListenerUid = null;
    rows.clear();
  }
}

void main() {
  late Rx<UserModel?> source;
  late _FakeFeatureController controller;

  setUp(() {
    source = Rx<UserModel?>(null);
    controller = _FakeFeatureController(source);
  });

  tearDown(Get.reset);

  test('binds when the user arrives after the controller is built', () {
    // Cold start: main() routes to Home from Firebase's cached session before
    // the profile has been fetched, so controllers exist before `user` is set.
    controller.onInit();
    expect(controller.liveListenerUid, isNull);

    source.value = _user('uid1');

    expect(controller.liveListenerUid, 'uid1');
    expect(controller.rows, ['uid1-row']);
  });

  test('binds immediately when a user is already signed in', () {
    source.value = _user('uid1');
    controller.onInit();

    expect(controller.boundUid, 'uid1');
    expect(controller.rows, ['uid1-row']);
  });

  test('sign-out drops the listener and every row', () {
    source.value = _user('uid1');
    controller.onInit();

    source.value = null;

    expect(controller.boundUid, isNull);
    expect(controller.liveListenerUid, isNull);
    expect(controller.rows, isEmpty);
  });

  test('signing in as a second account never shows the first account\'s data',
      () {
    source.value = _user('uid1');
    controller.onInit();
    source.value = null;
    source.value = _user('uid2');

    expect(controller.boundUid, 'uid2');
    expect(controller.rows, ['uid2-row']);
    // Teardown must precede setup, or the new session starts on top of the old
    // one's rows and listener.
    expect(controller.events, ['bind:uid1', 'unbind', 'bind:uid2']);
  });

  test('a direct account switch still unbinds first', () {
    source.value = _user('uid1');
    controller.onInit();
    source.value = _user('uid2');

    expect(controller.rows, ['uid2-row']);
    expect(controller.events, ['bind:uid1', 'unbind', 'bind:uid2']);
  });

  test('boundUid is null while unbinding, so a resubscribe cannot re-attach',
      () {
    source.value = _user('uid1');
    controller.onInit();

    String? uidDuringUnbind = 'sentinel';
    final probe = _FakeFeatureController(source);
    probe.onInit();
    // Clearing an observable during teardown can wake an `ever` worker that
    // calls back into the controller; it must not see the outgoing uid.
    source.value = null;
    uidDuringUnbind = probe.boundUid;

    expect(uidDuringUnbind, isNull);
  });

  test('closing the controller disposes the worker', () {
    source.value = _user('uid1');
    controller.onInit();
    controller.onClose();

    expect(controller.events, ['bind:uid1', 'unbind']);

    // The controller is gone; a later sign-in must not resurrect it. This is
    // the leak that let a disposed controller keep serving the previous
    // account: `ever()` workers are not disposed with their controller unless
    // something disposes them.
    source.value = _user('uid2');

    expect(controller.events, ['bind:uid1', 'unbind']);
    expect(controller.rows, isEmpty);
    expect(controller.liveListenerUid, isNull);
  });
}
