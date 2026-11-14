# CLAUDE.md

Food Saver (`foodsaver`) is a Flutter app for reducing household food waste. It has a fridge tracker with expiry alerts, shopping lists, food donations and a rule-based assistant, and stores data in Cloud Firestore. It is a team project: each feature module belongs to one member (Membre 1–4).

**Final feature split** (this replaces the member labels in older code and the README):
- Membre 1 (the user of this repo): Authentication & Profile (Splash, Welcome, Login, Register, reset password, profile, photo, Settings, logout)
- Membre 2: Fridge
- Membre 3: Notifications & Expiry
- Membre 4: Shopping list
- Membre 5: Recipes & Home dashboard/statistics
- Donations and the chatbot already exist in the code but aren't assigned to anyone.

Progress and the plan: [TODO.md](TODO.md).

- Architecture, UI conventions and known gaps: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)
- Features per module and the Firestore schema: [README.md](README.md)

## Permanent project rules

1. **Keep this file current.** Whenever the project progresses (new feature, convention, Firestore path, command, or a resolved gap), update this file in the same step, without being asked. Keep [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) accurate too.
2. **Git uses the user's own account and leaves no AI trace.** No `Co-Authored-By` trailers, no "Generated with …" lines, and no mention of AI in commits, branches or PRs. Use the configured git identity and write commit messages in the team's existing style, e.g. `Add X module (Membre N)`.
3. **TODO.md tracks the specs.** [TODO.md](TODO.md) is built from the final feature split. Update it every time a task is finished or a new one is added.

## Commands

```bash
flutter pub get
flutter analyze          # must be clean before committing
flutter test             # all tests; no Firebase needed
(cd firestore-tests && npm test)   # firestore.rules against the emulator (needs Firebase CLI + Java)
flutter test test/features/fridge/fridge_repository_test.dart   # one file
flutter run
dart run tool/generate_app_icon.dart && dart run flutter_launcher_icons   # regenerate the app icon
```

## Layout

- `lib/main.dart`: initialises Firebase, starts notifications, then calls `runApp`. `lib/app.dart` holds the `MaterialApp` and theme.
- `lib/core/firebase/firebase_setup.dart`: `FirebaseSetup.isReady`. `lib/core/session/current_user.dart`: `CurrentUser.uid` is the signed-in uid (`'demo-user'` when nobody is bound, i.e. in tests).
- `lib/shared/widgets/screen_header.dart`: shared widgets used by every feature (`ScreenHeader`, `HeaderIconButton`, `SectionTitle`, `EmptyCard`, `showAppSnackBar`).
- `lib/features/<feature>/{domain,data,presentation}/`: one folder per feature.
- `test/features/<feature>/`: tests, with the same folder layout as `lib/features/`.

## Conventions to follow

**Layers**
- `domain/` is plain Dart: models, enums and rules. It must not import Firebase or build widgets.
- `data/` has two classes per feature:
  - `<Feature>Repository extends ChangeNotifier`, exposed as `static final instance`.
  - `<Feature>Firestore`, plus top-level `xToMap` / `xFromMap` functions.
- `presentation/` holds the screens. A widget used by one feature only goes in `presentation/widgets/`. A widget used by one screen only is a private `_Widget` class at the bottom of that screen's file.

**State**
- Every change goes through a repository method. The method updates the in-memory data, calls `notifyListeners()`, and then saves to Firestore in the background without waiting for it, using the repository's `_sync`/`write().catchError` helper. Don't make the UI wait for Firestore.
- `remote` is nullable. Repositories must keep working when `remote == null`, because that is the case in tests and when Firebase is not configured.
- Screens take an optional `repository` parameter that defaults to `XRepository.instance`. Wrap the parts that depend on repository data in `ListenableBuilder`. Use `setState` only for local UI state.
- Pass an injectable `clock` instead of calling `DateTime.now()` directly in logic that depends on dates.

**Data rules**
- The fridge is the single source of truth for expiry dates. Expiry alerts are calculated by `features/expiry/domain/expiry_alerts.dart` every time and are never stored.
- Categories are saved in Firestore by name only. Their icon and colour come from the app.
- New Firestore paths go under `users/{userId}/...`, except shared data such as `donations/`. When you add one, update `firestore.rules` (auth-based with roles; the old open dev rules are a comment at the bottom) and the schema table in `README.md`.

**Navigation**
- Use `Navigator.of(context).push(MaterialPageRoute(...))`. There are no named routes.
- Form screens send their result back with `pop<String>(message)`, and the calling screen shows it with `showAppSnackBar`.
- Each main tab screen (Home, Fridge, List, Profile) builds its own `NavigationBar`, and tabs switch with `pushReplacement`. Keep them consistent if you change one.

**UI style**
- Material 3. Brand green is `0xFF2E7D32`, text is `0xFF1B1B1B` / `Colors.black54`, and the scaffold background is `0xFFF5F9F3`.
- Content sits in white rounded cards (radius 20–28) with 22–24 px side padding and large bold titles.
- Colours are currently written directly in each widget. Match the colours already used nearby instead of introducing new ones.
- UI text is in English. The chatbot also matches French keywords.

**Tests**
- Add or update tests in `test/features/<feature>/` with every change to a module.
- Build repositories with `remote: null` (or a fake Firestore) and a fixed `clock`.
- Widget tests find elements by `ValueKey` (e.g. `'home-notifications-button'`), so keep existing keys when you edit widgets.

## Auth & profile (Membre 1)

- `features/auth/data/auth_repository.dart`: `AuthRepository.instance` is the signed-in account (`currentUser` is an `AppUser`, never Firebase's `User`). Without Firebase it keeps accounts in memory.
- Only `auth_firebase.dart` imports `firebase_auth`. It turns `FirebaseAuthException` into `AuthFailure(code)`, whose `.message` is ready to show in the UI. Add new codes to `authErrorMessage`.
- Forms use the validators in `auth/domain/auth_validators.dart`. Don't write new ones inline.
- `UserProfileRepository.instance` follows `AuthRepository`. It creates `users/{uid}` on first sign-in, listens to it, and clears it on sign-out. Writes to `users/{uid}` are always merges, because other modules store fields in the same document.
- The profile photo is a base64 JPEG in `users/{uid}.photo`, limited to `maxProfilePhotoLength`. It is not in Firebase Storage.
- Screens (`auth/presentation/`, `profile/presentation/`): Splash (routes on auth state; start screen in `app.dart`), Welcome, Login, Register, Reset password, Profile, Edit profile (name + photo, and the business name for restaurants), Settings (notifications switch, change password, delete account). All take an optional `repository`/`auth`/`profiles` parameter for tests. Form widgets are in `auth/presentation/widgets/auth_widgets.dart`.
- Logout and account deletion both end with `signOutAndShowWelcome` (`auth/presentation/session_actions.dart`): sign out, `NotificationService.cancelAll()`, `pushAndRemoveUntil(Welcome)`. The Settings notifications switch calls `NotificationService.setEnabled` (wired in `main.dart`).
- The Home greeting (`FoodSaverHomePage`, optional `profiles`/`auth` parameters) shows `UserProfileRepository.profile.displayName`, then the auth name, then "Food saver".
- Profile photo is picked and shrunk by `profile/data/profile_photo.dart` (400 px, quality 70) and shown by `ProfileAvatar`. Email verification is sent at sign-up but never blocks access; Profile shows a dismissible banner.
- Roles: `UserRole` (`profile/domain/user_role.dart`) is stored in `users/{uid}.role`: `user` (default), `restaurant` (also `businessName`), `admin`. Register calls `UserProfileRepository.prepareSignUp` before `signUp`; the role is fixed at creation and admin can only be set in the Firebase console. `RoleHome` (`roles/presentation/`) picks the start screen: users get the app, restaurants and admins get `RoleShell` (placeholder donation tab + Profile tab, to be filled by the donations owner). After sign-in wait for `UserProfileRepository.whenReady()` before routing, so the role is known.
- Per-user data: every Firestore class reads `CurrentUser.uid`. Each repository has `connect()` and `clear()`, and `SessionBinder` (started in `main.dart`) clears them all and reloads the new account on sign-in or sign-out. Fridge, lists and notifications only load for the `user` role. The app-wide `instance` of each repository is created with `autoConnect: false`. `_AuthGate` in `app.dart` returns to Welcome if the session ends while the app is open.
- Deleting an account: `reauthenticate` → `UserProfileRepository.deleteAllData()` → `AuthRepository.deleteAccount()`. The data must go first, because the security rules need the user signed in. Add any new per-user collection to `UserProfileFirestore.userCollections`.

## Gotchas

- The generated plugin registrant files under `linux/`, `macos/` and `windows/` often show up as modified only because of CRLF/LF line endings. Don't commit that noise. Stash or restore those files when they block a pull.
- `lib/firebase_options.dart` and `android/app/google-services.json` are generated by `flutterfire configure`. Don't edit them by hand.
- In `firestore.rules` never write `match /users/{userId}/{document=**}`: the recursive wildcard also matches the profile document itself and bypasses the role checks. Use `/users/{userId}/{collection}/{document=**}` for subcollections.
- `firestore.rules` is the auth-based version with roles and is tested with the emulator (`cd firestore-tests && npm test`, needs the Firebase CLI and Java; run it after every rules change) but is not deployed yet. Deploying it breaks builds that still use `demo-user`, and the donor screens that accept requests (with roles only the admin decides).
- `android/gradle.properties` sets `kotlin.incremental=false`. The project is on `D:` and the pub cache is on `C:`, and Kotlin's incremental caches fail across drives ("Could not close incremental caches" in `:firebase_core:compileDebugKotlin`). If the error comes back, run `flutter clean` and stop the Gradle daemon (`cd android && ./gradlew --stop`).
- On Windows, `flutter pub get` asks for **Developer Mode** (plugin symlinks). This only matters for Windows desktop builds.
- Notifications only work on Android and iOS. `NotificationService` does nothing on other platforms, so don't rely on it in logic that has to work everywhere.
- Commit to a feature branch and merge into `main`. This follows the team's history, where each member works on their own branch.
