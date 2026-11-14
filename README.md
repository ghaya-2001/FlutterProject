# foodsaver

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Membre 1 — Authentification et Profil (Auth & Profile module)

Code: `lib/features/auth/`, `lib/features/profile/`, `lib/features/roles/`, `lib/features/welcome/`, `lib/core/session/`

| Folder | Content |
| --- | --- |
| `auth/domain/` | `AppUser`, `AuthFailure` (error code → English message), form validators |
| `auth/data/` | `AuthRepository` (ChangeNotifier; in-memory accounts without Firebase), `AuthFirebase` (the only file importing `firebase_auth`), `SessionBinder` |
| `auth/presentation/` | `SplashScreen`, `LoginScreen`, `RegisterScreen`, `ResetPasswordScreen`, shared form widgets, logout helpers |
| `profile/` | `UserProfile`, `UserSettings`, `UserRole`, `UserProfileRepository` + `UserProfileFirestore`, `ProfileScreen`, `EditProfileScreen`, `SettingsScreen` |
| `roles/presentation/` | `RoleHome` (start screen by role), `RoleShell` (restaurants and admins), `RequestHistoryTab` (request history) |
| `core/session/` | `CurrentUser.uid`, the signed-in uid read by every Firestore class |

| Feature (cahier des charges) | Where |
| --- | --- |
| Splash Screen | First screen: waits for Firebase, then opens the app (signed in) or Welcome (signed out) |
| Welcome Screen | Get Started → Login, Create account → Register |
| Inscription | Register: name, email, password, confirmation; Individual or Restaurant (with business name). A verification email is sent but never blocks access |
| Connexion | Login: validation, loading state, error messages |
| Réinitialisation du mot de passe | Login → Forgot password? → Reset password (reset link by email) |
| Gestion du profil utilisateur | Profile tab: real name, email, photo, verify-email banner |
| Modification des informations personnelles | Profile → Edit profile: name (and business name for restaurants) |
| Photo de profil | Edit profile → tap the photo: gallery, camera or remove. Stored as a small base64 JPEG in `users/{uid}.photo` (no Firebase Storage) |
| Paramètres utilisateur | Profile → Settings: notifications on/off, change password, delete account (all the user data, then the account) |
| Déconnexion sécurisée | Profile → Logout: confirmation, sign out, cancel phone alerts, back to Welcome with no way back |

Beyond the original split:
- **Roles:** `user`, `restaurant` and `admin` (`users/{uid}.role`). Chosen at sign-up (never admin), fixed afterwards. The first admin is set by hand in the Firebase console (Firestore → `users/{uid}` → `role` = `admin`). Restaurants and admins get their own start screen without the fridge, list or recipes; their donation tab is a placeholder until the donation workflow is built (see `TODO.md`).
- **Per-user data:** each repository has `connect()` and `clear()`, driven by `SessionBinder`, so accounts never see each other's data. An `_AuthGate` returns to Welcome if the session ends while the app is open.
- **Security rules:** `firestore.rules`, tested with the emulator (`cd firestore-tests && npm test`, needs the Firebase CLI and Java).

Sign-in method: email and password only (enable it in Firebase console → Authentication → Sign-in method).

Tests: `test/features/auth/`, `test/features/profile/`, `test/widget_test.dart`, `firestore-tests/`

## Membre 2 — Gestion du Frigo (Fridge module)

Code: `lib/features/fridge/`

| Folder | Content |
| --- | --- |
| `domain/` | `FoodItem`, `FoodCategory`, expiry status and formatting helpers, `FridgeStats`, recipe book and matching, shelf life, achievements |
| `data/` | `FridgeRepository` (ChangeNotifier), `FridgeFirestore` (Cloud Firestore) |
| `presentation/` | `FridgeScreen`, `AddFoodScreen`, `EditFoodScreen`, `FoodDetailsScreen`, `FridgeStatsScreen`, `RecipesScreen`, `ImportGroceriesScreen` |

| Feature (cahier des charges) | Where |
| --- | --- |
| Ajout d'aliments | Fridge `+` button → Add Food |
| Modification d'aliments | Food Details → Edit → Edit Food |
| Suppression d'aliments | Food Details → Delete, or swipe left on the Fridge list (with Undo) |
| Consultation du stock / visualisation des produits | Fridge screen list |
| Gestion des catégories alimentaires | 10 default categories; Fridge category icon → add / delete custom ones; also "New category" in the form |
| Recherche d'aliments | Search bar (name, category, note) |
| Suivi des quantités disponibles | Quantity + unit on every food |
| Enregistrement des dates d'expiration | Required date picker + quick dates in the form |
| Classement par date d'expiration | Default sort (also by name / recently added) |
| Aliments à consommer en priorité | "Use first" section: expired or expiring within 3 days |
| Nombre total d'ingrédients disponibles | Summary card: "N ingredients ready to use", in stock, to use first, expired |
| Mise à jour du stock après consommation | Food Details → Consume (removed automatically when finished) |
| Consultation des détails d'un aliment | Tap a food → Food Details |

| Synchronisation temps réel (Firestore) | The fridge is listened to with Firestore snapshots: a change on one phone appears on the others; "Synced live with the cloud" badge |
| Historique de consommation | Every consumption and every thrown away food is saved in `fridge_history` |
| Statistiques anti-gaspillage | Fridge chart icon → anti-waste score, eaten / wasted, days without waste, last 7 days chart, most wasted categories, recent activity |
| Aliments jetés | Expired food → Food Details → Throw away (counted as waste; Delete stays for corrections) |
| Recettes anti-gaspillage ("Cook now") | Fridge → Cook now: built-in recipe book matched against the fridge, recipes using the foods that expire soonest first; adjustable quantities; "I cooked it" removes them from the stock and counts them as eaten; "Add missing to shopping list" (Membre 4 lists) |
| Courses → frigo | Fridge → Groceries: items checked as bought in the shopping lists go to the fridge in one tap, expiry date suggested from the shelf life of the category (editable), each item imported only once |
| Badges / succès | Anti-waste stats → Achievements: First bite, Food saver, Last-minute rescue, Anti-waste chef, Balanced diet, Zero-waste week, Anti-waste champion, with progress bars |

Tests: `test/features/fridge/` (including `fridge_firestore_test.dart` with a fake Firestore and `fridge_stats_test.dart`)

## Module 4 — Shopping list (Gestion de la Liste de Courses)

Code: `lib/features/list/`

| Folder | Content |
| --- | --- |
| `domain/` | `ShoppingList`, `ShoppingItem`, `ShoppingCategory` models |
| `data/` | `ShoppingListRepository` (ChangeNotifier, in-memory store) |
| `presentation/` | `ListScreen` (Shopping List), `AddItemScreen` (Add Item / Edit Item) |

Features:

- Create, rename, switch between and delete shopping lists
- Add items (name, quantity, unit, category, note); adding an existing item merges the quantity
- Edit an item by tapping it
- Delete items (delete button or swipe left), with Undo
- Mark items as bought / not bought
- Manage categories: 10 default categories, add / delete custom ones, filter the list by category
- View the list grouped by category, with "To buy" and "Bought" sections
- Automatic purchase updates: progress bar, counters, bought items move to the "Bought" section, "Mark all as bought" and "Clear bought items"

Tests: `test/features/list/`

## Membre 3 — Gestion des Dons Alimentaires (Donations module)

Code: `lib/features/donations/`

| Folder | Content |
| --- | --- |
| `domain/` | `Donation`, `DonationRequest`, `Beneficiary` (sample restaurants / charities), statuses |
| `data/` | `DonationRepository` (ChangeNotifier, in-memory store, linked to the fridge) |
| `presentation/` | `DonationsScreen`, `CreateDonationScreen`, `DonationDetailsScreen`, `DonationHistoryScreen` |

| Feature (cahier des charges) | Where |
| --- | --- |
| Aliments pouvant être proposés au don | Donations → "Could be donated" (fridge food expiring within 7 days) |
| Créer une annonce à partir d'un aliment du frigo | "New donation", or "Donate" on Food Details / Expiring soon |
| Quantité et date limite de consommation | Create Donation (quantity ≤ stock, date ≤ fridge expiry date) + optional description |
| Consultation des annonces disponibles | Restaurant account → Donations tab |
| Demande de récupération par un bénéficiaire | Restaurant account → "Request" (users cannot request, not even their own donation) |
| Acceptation / refus d'une demande | Donation Details → Accept / Refuse |
| Statut : disponible, réservé, récupéré | Accept → Reserved, "Mark as collected" → Collected |
| Historique des dons | History icon on Donations, or Profile → My donations |

Rules: the donated quantity is removed from the fridge; cancelling an available donation puts it back.
Beneficiaries are restaurant accounts; the old simulated requests were removed from the user screens.

## Membre 4 — Courses, Péremption, Notifications et Chatbot

Code: `lib/features/list/` (shopping list, see above), `lib/features/expiry/`, `lib/features/notifications/`, `lib/features/chatbot/`

| Feature (cahier des charges) | Where |
| --- | --- |
| Liste de courses (création, ajout, suppression, modification, achetés, catégories) | Shopping List module above |
| Calcul du temps restant / aliments proches de l'expiration | `expiry/domain/expiry_alerts.dart`, always computed from the fridge expiry date (single source of truth) |
| Alertes à 7 jours, 3 jours et le jour même | Notifications screen (bell on Home) + scheduled phone notifications at 9:00 |
| Section « Expiring Soon » | Home card (live data) → "View all" → Expiring Soon screen (Donate / Add to list) |
| Notifications push | `NotificationService` (flutter_local_notifications), Android/iOS only |
| Chatbot | Home → Assistant: predefined questions + simple keyword matching, no AI service |

Android: notifications need the `POST_NOTIFICATIONS` permission and core library desugaring (already configured).

Tests: `test/features/donations/`, `test/features/expiry/`, `test/features/notifications/`, `test/features/chatbot/`

## Base de données — Firestore (Membres 2, 3 et 4)

The fridge, shopping lists, donations and notifications are saved in **Cloud Firestore**.

| Collection | Content | Code |
| --- | --- | --- |
| `users/{userId}` | `displayName`, `email`, `photo` (base64 JPEG), `createdAt`, `settings`, `role` (`user` / `restaurant` / `admin`), `businessName` (restaurants), `customFoodCategories`, `fridgeSeeded`, `importedShoppingItemIds`, `customShoppingCategories`, `selectedShoppingListId`, `readNotificationIds` | — |
| `users/{userId}/fridge_items/{id}` | `name`, `category`, `quantity`, `unit`, `expiryDate`, `addedAt`, `note` (listened to in real time) | `lib/features/fridge/data/fridge_firestore.dart` |
| `users/{userId}/fridge_history/{id}` | `type` (consumed / wasted), `foodName`, `category`, `quantity`, `unit`, `at`, `daysLeft`, `recipe` | `lib/features/fridge/data/fridge_firestore.dart` |
| `users/{userId}/shopping_lists/{listId}` | `name`, `createdAt`, `items: [...]` | `lib/features/list/data/shopping_list_firestore.dart` |
| `users/{userId}/notifications/{id}` | donation events: `type`, `title`, `body`, `donationId`, `createdAt` | `lib/features/notifications/data/notification_firestore.dart` |
| `donations/{donationId}` | `donorId`, `foodName`, `category`, `quantity`, `unit`, `expiryDate`, `status`, `requests: [...]` | `lib/features/donations/data/donation_firestore.dart` |

- Every module reads and writes under the signed-in uid (`CurrentUser.uid`, `lib/core/session/current_user.dart`). `SessionBinder` empties and reloads the repositories when the account changes. Without Firebase (tests) the fixed `demo-user` is used.
- Roles (beyond the original split): a normal **user** donates food and uses the fridge, a **restaurant** requests donations, an **admin** accepts or refuses requests. The role is chosen at sign-up (user or restaurant, never admin), cannot be changed afterwards, and admin is set by hand in the Firebase console.
- Expiry alerts are never stored: they are recomputed from the fridge expiry dates.
- If Firebase is not configured (or in tests), the app falls back to in-memory data.
- Rules: `firestore.rules` is the auth-based version with roles (tested with the emulator: `cd firestore-tests && npm test`; not deployed yet). The previous open development rules are kept as a comment at the bottom.

Setup (once per developer):

```bash
firebase login
flutterfire configure
```

Then in the Firebase console: Build → Firestore Database → Create database.
