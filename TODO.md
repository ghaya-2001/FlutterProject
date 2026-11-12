# TODO — Food Saver

Progress tracked against `Food_Saver_Repartition_Finale` (the final feature split).
Legend: `[x]` done · `[~]` partly done / UI only · `[ ]` not started

> **Ownership note:** the final split differs from the labels already in the code.
> In the code, donations are labelled "Membre 3" and expiry/notifications/chatbot are labelled "Membre 4".
> In the final split, **Membre 3 = Notifications & Expiry**, **Membre 4 = Shopping list**, **Membre 5 = Recipes & Dashboard**,
> and donations and the chatbot are extras not assigned to anyone.

Baseline (2026-11-01, `main` @ `2d1bd88`): `flutter analyze` clean · `flutter test` 94 passed, **3 failed** (`test/features/list/list_screen_test.dart`).
After Phase 0 (`feature/m1-auth-profile`): analyze clean · 129 passed, the same 3 failed.
After Phase 1 (2026-11-12): analyze clean · **166 passed, 0 failed** (the 3 list tests were fixed on `main` by Membre 2).
After Phase 2 + roles (2026-11-13): analyze clean · **187 passed, 0 failed**.
After business-name editing (2026-11-13): analyze clean · **191 passed, 0 failed** · 27 rules tests.

---

## Membre 1 — Authentication & User Profile (me)

### Decisions (made 2026-11-01)
- [x] Sign-in: **email/password only** (2026-11-12: passwordless email-link sign-in considered and skipped: it needs a link domain, Android/iOS link handling and a real-device test)
- [x] Email verification: send the verification email, but don't block access (default; can be changed later)
- [x] Profile photo: **compressed image stored in the `users/{uid}` Firestore document** (free Spark plan, kept well under 1 MB)
- [x] Settings: **notifications on/off**, **change password**, **delete account**

### Phase 0 — Setup ✅ (2026-11-01, branch `feature/m1-auth-profile`)
- [x] **(You, in the console)** Enabled **Email/Password** sign-in in the Firebase console (confirmed 2026-11-13). The first real sign-up on a device is still the end-to-end check (`operation-not-allowed` would mean it is off)
- [x] Add `firebase_auth` and `image_picker`; iOS photo/camera usage descriptions added to `Info.plist`
- [x] `auth/data/auth_firebase.dart`: `AuthFirebase` wraps `FirebaseAuth` and throws `AuthFailure` instead of Firebase exceptions
- [x] `auth/data/auth_repository.dart`: `AuthRepository` (`ChangeNotifier` singleton, in-memory accounts when there is no Firebase) with `currentUser`, `isLoading`, `signUp`, `signIn`, `sendPasswordReset`, `sendEmailVerification`, `reloadUser`, `updateDisplayName`, `reauthenticate`, `changePassword`, `deleteAccount`, `signOut`
- [x] `auth/domain/auth_failure.dart`: Firebase error codes → English messages
- [x] `auth/domain/auth_validators.dart`: email, password (≥ 6 characters, a letter and a number), confirmation and name validators for the forms
- [x] `profile/data/user_profile_firestore.dart` + `user_profile_repository.dart`: profile in `users/{uid}` (`displayName`, `email`, `photo`, `createdAt`, `settings.notificationsEnabled`), merged with other modules' fields, created on first sign-in, follows sign-in/sign-out; `deleteUserData` for account deletion
- [x] `profile/domain/user_profile.dart` + `user_settings.dart` models
- [x] Tests: `test/features/auth/` + `test/features/profile/` (35 tests)

### Phase 1 — Screens ✅ (2026-11-12, not yet committed)
- [x] **Splash Screen** (new, listed as a feature in the doc but not in its screen list; kept as a screen for auth routing): logo/Lottie, waits for Firebase + auth state, then goes to Home (signed in) or Welcome (signed out)
- [x] **Welcome**: screen for signed-out users; links to Login and Register
- [x] **Login**
  - [x] Form validation (email format, password not empty)
  - [x] Real `signIn`, loading state, error messages
  - [x] Fix `Image.asset('')` (now `assets/animations/food_login.gif`)
  - [x] "Sign up" opens Register, "Forgot password?" opens Reset
- [x] **Register** (new): name, email, password, confirm password; creates the account and the `users/{uid}` profile
- [x] **Reset password** (new dedicated screen, opened from Login): `sendPasswordResetEmail` + confirmation message
- [x] **Profile** (the stats stay placeholders for Membre 5)
  - [x] Show the real name, email and photo
  - [x] Wire up "Settings"
  - [x] Fix the bottom-bar Fridge tab (index 1 has no handler)
- [x] **Edit profile** (new screen): change display name and photo only (no email change; password change lives in Settings)
- [x] **Profile photo**: gallery/camera, compressed, saved in `users/{uid}.photo`, shown on Profile
  - [ ] Show it on the Home header too (Home belongs to Membre 5; coordinate)
- [x] **Settings** (new), saved in `users/{uid}.settings`. The three items below go beyond the doc ("Paramètres utilisateur") on purpose:
  - [x] Notifications on/off, connected to `NotificationService.setEnabled` (cancel or re-schedule alerts)
  - [x] Change password (re-authenticate with the current password, then update)
  - [x] Delete account (confirm + re-authenticate, delete the user's Firestore data, then the auth user)
- [x] **Secure logout**
  - [x] Profile "Verify your email" banner (dismissible, Resend + refresh check, never blocks access)
  - [x] `signOut()` + cancel scheduled notifications + `pushAndRemoveUntil(Welcome)`
  - [x] Clear the other modules in-memory data (`SessionBinder` calls each repository `clear()`)

### Phase 2 — Integration (the doc lists "Intégration des modules" as shared work: I build the mechanism and the gate, each owner reviews their own module's change)
- [x] Replace the `currentUserId = 'demo-user'` constant with the signed-in uid: `CurrentUser.uid` (`lib/core/session/current_user.dart`), read by `FridgeFirestore`, `ShoppingListFirestore`, `NotificationFirestore` and `DonationRepository` (the `'demo-user'` fallback remains for tests)
- [x] Re-bind on login / reset on logout: every repository has `connect()` and `clear()`, driven by `SessionBinder` (started in `main.dart`); the app-wide instances use `autoConnect: false`. Tests: `session_binder_test.dart`
- [x] Auth gate: `_AuthGate` in `app.dart` returns to Welcome if the session ends while the app is open; Splash and logout already route on auth state
- [~] `firestore.rules` is now the auth-based version **with roles** (old dev rules kept as a comment). Tested with the emulator (`firestore-tests/`, 27 tests, run `npm test` there; it found and fixed a self-promotion hole). **Not deployed**: deploy only after every teammate build uses the real uid and the donor screens follow the new request flow
- [x] Roles (decided 2026-11-13, beyond the original doc): `user` / `restaurant` / `admin` in `users/{uid}.role`; chosen at Register (user or restaurant + business name), immutable, admin only from the Firebase console; `RoleHome` + `RoleShell` give restaurants and admins their own start screen (placeholder donation tab + Profile). Tests: `user_role_test.dart`
- [x] Set the first admin by hand: Firebase console → Firestore → `users/{uid}` → add `role` = `admin` (done and checked on a device, 2026-11-13)
- [x] Clear the other modules in-memory data on logout: done through `SessionBinder`; verified on a real device with two accounts (2026-11-13)
- [x] Edit profile for restaurants: change the business name (`UserProfileRepository.updateBusinessName`, field shown to restaurants only)
- [x] `NotificationService`: cancel/re-schedule hook (`setEnabled`, `cancelAll`; Membre 3: please review) for the Settings toggle, logout and delete account (Membre 3 owns it; add a method only if missing)
- [ ] Profile stats ("128 meals saved / 92%") stay as placeholders for Membre 5
- [ ] Home header greeting uses the profile name (Home belongs to Membre 5; coordinate)

### Phase 3 — Tests & docs
- [x] `test/features/auth/`: auth repository with a fake remote, error mapping, form validation (done in Phase 0)
- [x] Widget tests: Splash routing, Login, Register, Reset, Profile, Edit profile, Settings, Logout (`auth_screens_test.dart`, `profile_screens_test.dart`)
- [x] Update `test/widget_test.dart` (the flow now goes through Splash and sign-up)
- [x] Update `CLAUDE.md`, `PROJECT_OVERVIEW.md` and the README "Membre 1" section

---

## Donations workflow with roles — handoff spec (not assigned)
Roles exist (see Phase 2 above); the donation screens still follow the old flow where the donor accepts requests on their own donation, and restaurants are `sampleBeneficiaries`. Target flow, agreed 2026-11-13:
- [ ] A user creates a donation; it appears as available to every restaurant
- [ ] Restaurants browse available donations and send a request (optional message) from the **Donations** tab of `RoleShell`; the beneficiary is the restaurant account (`businessName`), replacing `sampleBeneficiaries`
- [ ] The admin sees all pending requests in the **Requests** tab and accepts or refuses; accepting one reserves the donation and refuses the other requests on it
- [ ] The donor sees the status and gets a notification (rules already allow restaurant/admin to create an event in the donor notifications), then marks the donation collected after the handover (the admin can as a fallback)
- [ ] Remove the donor-side accept/refuse buttons (the new rules forbid them)
- [ ] Manual donations without a fridge item ("Donate something else": name, category, quantity, optional expiry; food and pantry items only)
- [x] Emulator tests for the donation rules (`firestore-tests/rules.test.js`); rerun after changing the donation flow

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
- [x] Fixed on `main` (the 3 `list_screen_test.dart` failures)

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
