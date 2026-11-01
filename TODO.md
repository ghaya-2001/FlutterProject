# TODO — Food Saver

Progress tracked against `Food_Saver_Repartition_Finale` (the final feature split).
Legend: `[x]` done · `[~]` partly done / UI only · `[ ]` not started

> **Ownership note:** the final split differs from the labels already in the code.
> In the code, donations are labelled "Membre 3" and expiry/notifications/chatbot are labelled "Membre 4".
> In the final split, **Membre 3 = Notifications & Expiry**, **Membre 4 = Shopping list**, **Membre 5 = Recipes & Dashboard**,
> and donations and the chatbot are extras not assigned to anyone.

Baseline (2026-11-01, `main` @ `2d1bd88`): `flutter analyze` clean · `flutter test` 94 passed, **3 failed** (`test/features/list/list_screen_test.dart`).
After Phase 0 (`feature/m1-auth-profile`): analyze clean · 129 passed, the same 3 failed.

---

## Membre 1 — Authentication & User Profile (me)

### Decisions (made 2026-11-01)
- [x] Sign-in: **email/password only**
- [x] Email verification: send the verification email, but don't block access (default; can be changed later)
- [x] Profile photo: **compressed image stored in the `users/{uid}` Firestore document** (free Spark plan, kept well under 1 MB)
- [x] Settings: **notifications on/off**, **change password**, **delete account**

### Phase 0 — Setup ✅ (2026-11-01, branch `feature/m1-auth-profile`)
- [ ] **(You, in the console)** Enable **Email/Password** sign-in in Firebase console (Authentication → Sign-in method)
- [x] Add `firebase_auth` and `image_picker`; iOS photo/camera usage descriptions added to `Info.plist`
- [x] `auth/data/auth_firebase.dart`: `AuthFirebase` wraps `FirebaseAuth` and throws `AuthFailure` instead of Firebase exceptions
- [x] `auth/data/auth_repository.dart`: `AuthRepository` (`ChangeNotifier` singleton, in-memory accounts when there is no Firebase) with `currentUser`, `isLoading`, `signUp`, `signIn`, `sendPasswordReset`, `sendEmailVerification`, `reloadUser`, `updateDisplayName`, `reauthenticate`, `changePassword`, `deleteAccount`, `signOut`
- [x] `auth/domain/auth_failure.dart`: Firebase error codes → English messages
- [x] `auth/domain/auth_validators.dart`: email, password (≥ 6 characters, a letter and a number), confirmation and name validators for the forms
- [x] `profile/data/user_profile_firestore.dart` + `user_profile_repository.dart`: profile in `users/{uid}` (`displayName`, `email`, `photo`, `createdAt`, `settings.notificationsEnabled`), merged with other modules' fields, created on first sign-in, follows sign-in/sign-out; `deleteUserData` for account deletion
- [x] `profile/domain/user_profile.dart` + `user_settings.dart` models
- [x] Tests: `test/features/auth/` + `test/features/profile/` (35 tests)

### Phase 1 — Screens
- [ ] **Splash Screen** (new): logo/Lottie, waits for Firebase + auth state, then goes to Home (signed in) or Welcome (signed out)
- [~] **Welcome**: UI exists; becomes the screen for signed-out users and links to Login and Register
- [~] **Login**: UI exists, but "Log In" skips straight to Home
  - [ ] Form validation (email format, password not empty)
  - [ ] Real `signIn`, loading state, error messages
  - [ ] Fix `Image.asset('')` (always shows the fallback icon)
  - [ ] "Sign up" opens Register, "Forgot password?" opens Reset
- [ ] **Register** (new): name, email, password, confirm password; creates the account and the `users/{uid}` profile
- [ ] **Reset password** (new screen or dialog): `sendPasswordResetEmail` + confirmation message
- [~] **Profile**: UI exists, but the name "Maya" and the stats are hard-coded
  - [ ] Show the real name, email and photo
  - [ ] Wire up "Settings" (it currently does nothing)
  - [ ] Fix the bottom-bar Fridge tab (index 1 has no handler)
- [ ] **Edit profile** (new): change display name (and email/password with re-authentication)
- [ ] **Profile photo**: choose from gallery/camera, crop/compress, upload, show it on Profile (and on the Home header)
- [ ] **Settings** (new), saved in `users/{uid}.settings`:
  - [ ] Notifications on/off, connected to `NotificationService` (cancel or re-schedule alerts)
  - [ ] Change password (re-authenticate with the current password, then update)
  - [ ] Delete account (confirm + re-authenticate, delete the user's Firestore data, then the auth user)
- [~] **Secure logout**: confirmation dialog exists, but it only navigates back
  - [ ] `signOut()` + clear all repositories' in-memory data + cancel scheduled notifications + `pushAndRemoveUntil(Welcome)`

### Phase 2 — Integration (touches other members' code, coordinate first)
- [ ] Replace the `currentUserId = 'demo-user'` constant with the signed-in uid. It is used by `FridgeFirestore`, `ShoppingListFirestore`, `NotificationFirestore` and `DonationRepository`.
- [ ] Repositories are `static final` singletons created at startup with a fixed user. Add a way to **re-bind on login / reset on logout** (e.g. `bindUser(uid)` / `clear()`), so a second account never sees the first one's data.
- [ ] Auth gate: no module screen opens without a signed-in user
- [ ] Switch `firestore.rules` to the auth-based rules (already written as a comment in the file)
- [ ] Home header greeting uses the profile name (Home belongs to Membre 5; coordinate)

### Phase 3 — Tests & docs
- [x] `test/features/auth/`: auth repository with a fake remote, error mapping, form validation (done in Phase 0)
- [ ] Widget tests: Splash routing, Login, Register, Reset, Settings, Logout
- [ ] Update `test/widget_test.dart` (the flow now goes through Splash and real login)
- [ ] Update `CLAUDE.md`, `PROJECT_OVERVIEW.md` and the README "Membre 1" section

---

## Membre 2 — Fridge management
Reported done in the README (`lib/features/fridge/`), with Firestore sync and anti-waste stats on top.
- [x] Add / edit / delete foods · stock view · categories · search · quantities · expiry dates · sort by expiry · "use first" · total count · consume · details
- [x] Screens: Fridge, Add Food, Edit Food, Food Details

## Membre 3 — Notifications & Expiry
Implemented in the code under the "Membre 4" label (`lib/features/expiry/`, `lib/features/notifications/`).
- [x] Expiry dates · time remaining · near-expiry detection · alerts 7 d / 3 d / same day · Expiring Soon section · push notifications (Android/iOS)
- [x] Screens: Notifications, Expiring Soon

## Membre 4 — Shopping list
Reported done in the README (`lib/features/list/`).
- [x] Create list · add / delete items · mark bought · categories · view list · automatic purchase updates
- [x] Screens: Shopping List, Add Item
- [ ] **Fix 3 failing tests** in `test/features/list/list_screen_test.dart` ("Bought" text not found; likely off-screen in the test viewport)

## Membre 5 — Recipes & Dashboard
- [ ] Recipe suggestions from the fridge ingredients
- [ ] Recipe search
- [ ] Save favorite recipes · view saved recipes
- [~] Home Dashboard: layout exists; "Food saved", "Fridge 7 items" and "Recipes 3 ideas" are placeholders
- [ ] Meals-saved calculation · environmental-impact calculation
- [~] User statistics: the fridge anti-waste stats screen exists; Profile "128 meals saved / 92% impact" are placeholders
- [~] Action history: fridge consumption/waste history exists (`fridge_history`)
- [ ] Screens: Recipes, Saved Recipes, Statistics

## Extras (in the code, not in the final split)
- [x] Donations (`lib/features/donations/`)
- [x] Chatbot assistant (`lib/features/chatbot/`)

## Shared contribution
- [ ] UI/UX: move hard-coded colours into the theme; single app shell for the bottom navigation (each tab screen currently builds its own bar)
- [ ] Module integration (mainly the auth/uid change above)
- [ ] Functional tests · bug fixes
- [~] Technical documentation (`README.md`, `PROJECT_OVERVIEW.md`, `CLAUDE.md`)
- [ ] Final presentation
