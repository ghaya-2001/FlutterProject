/// User preferences shown on the Settings screen.
class UserSettings {
  const UserSettings({this.notificationsEnabled = true});

  /// Phone notifications for expiry alerts and donation requests.
  final bool notificationsEnabled;

  UserSettings copyWith({bool? notificationsEnabled}) {
    return UserSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserSettings &&
      other.notificationsEnabled == notificationsEnabled;

  @override
  int get hashCode => notificationsEnabled.hashCode;
}
