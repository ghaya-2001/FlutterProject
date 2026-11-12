/// What an account can do. One role per account, stored in `users/{uid}.role`.
///
/// - [user]: donates food and uses the fridge, lists and recipes.
/// - [restaurant]: browses available donations and requests them.
/// - [admin]: accepts or refuses donation requests. Never chosen in the app:
///   set by hand in the Firebase console.
enum UserRole {
  user,
  restaurant,
  admin;

  /// Roles a person may pick when registering (admin is console-only).
  static const selfRegistered = [UserRole.user, UserRole.restaurant];

  /// Unknown or missing values mean a normal user.
  static UserRole fromName(String? name) {
    for (final role in values) {
      if (role.name == name) {
        return role;
      }
    }
    return UserRole.user;
  }

  String get label {
    switch (this) {
      case UserRole.user:
        return 'Individual';
      case UserRole.restaurant:
        return 'Restaurant';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
