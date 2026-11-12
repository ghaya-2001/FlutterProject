/// Id of the user whose data is read and written in Firestore.
///
/// Set by `SessionBinder` when someone signs in or out. Until then (tests,
/// or Firebase not configured) it falls back to [demoUserId], so every
/// module keeps working with a fixed user.
class CurrentUser {
  CurrentUser._();

  static const demoUserId = 'demo-user';

  static String? _uid;

  /// The signed-in user's uid, or [demoUserId] when nobody is bound.
  static String get uid => _uid ?? demoUserId;

  /// True when a real signed-in user is bound.
  static bool get isBound => _uid != null;

  static void bind(String? uid) => _uid = uid;
}
