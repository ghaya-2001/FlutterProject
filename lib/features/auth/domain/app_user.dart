/// The signed-in account, as seen by the app.
///
/// Screens use this instead of Firebase's `User`, so they keep working in
/// tests and without Firebase.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.emailVerified = false,
  });

  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;

  AppUser copyWith({String? displayName, bool? emailVerified}) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified;

  @override
  int get hashCode => Object.hash(uid, email, displayName, emailVerified);
}
