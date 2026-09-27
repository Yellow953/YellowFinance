/// A destination requested before the app could navigate to it.
///
/// Notification taps and home-screen widget taps can cold-start the app, when
/// GetX has no navigator yet — or while nobody is signed in. They park the
/// destination here and [HomeController] opens it on its first load, which is
/// also the first screen after a sign-in.
abstract class PendingLaunch {
  static String? _route;
  static Object? _arguments;

  /// Records [route] (with optional route [arguments], e.g. 'add' to open a
  /// page's add sheet), replacing any destination not yet consumed.
  static void set(String route, {Object? arguments}) {
    _route = route;
    _arguments = arguments;
  }

  /// Returns the pending destination and clears it, or null if there is none.
  static ({String route, Object? arguments})? consume() {
    final route = _route;
    if (route == null) return null;
    final arguments = _arguments;
    _route = null;
    _arguments = null;
    return (route: route, arguments: arguments);
  }
}
