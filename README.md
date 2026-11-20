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
| Inscription | Register: name, email, password, confirmation, with a live checklist that ticks each password rule; Individual or Restaurant (with business name). A verification email is sent but never blocks access |
| Connexion | Login: validation, loading state, error messages |
| Réinitialisation du mot de passe | Login → Forgot password? → Reset password (reset link by email) |
| Gestion du profil utilisateur | Profile tab: real name, email, photo, verify-email banner |
| Modification des informations personnelles | Profile → Edit profile: name (and business name for restaurants) |
| Photo de profil | Edit profile → tap the photo: gallery, camera or remove. Stored as a small base64 JPEG in `users/{uid}.photo` (no Firebase Storage) |
| Paramètres utilisateur | Profile → Settings: notifications on/off, change password (current password + new one twice, live checklist of the password rules, reset link if the current one is forgotten), delete account (all the user data, then the account) |
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
| Objectifs de dons (asked by the professor) | See "Donation goals" below |

Tests: `test/features/fridge/` (including `fridge_firestore_test.dart` with a fake Firestore and `fridge_stats_test.dart`)

### Donation goals (Membre 2, asked by the professor)

Code: `lib/features/goals/`. A restaurant or a charity publishes what it needs ("10 kg of rice for the soup kitchen", optional deadline). Users give part of it, **from their fridge** or with food they buy; every gift moves a progress bar until the target is reached.

| Folder | Content |
| --- | --- |
| `domain/` | `DonationGoal` (collected, remaining, progress, status: open / reached / closed / ended), `GoalContribution`, unit conversion (kg ↔ g, L ↔ ml), fridge food ↔ goal matching (case, accents and plural ignored) |
| `data/` | `GoalRepository` (ChangeNotifier, real-time Firestore listener), `GoalFirestore` |
| `presentation/` | `DonationGoalsScreen` (users), `GoalDetailsScreen`, `CreateGoalScreen` and `RestaurantGoalsTab` (restaurants; read-only for the admin), `showContributeSheet`, `GoalCard` / `GoalProgressBar` |

| Who | Where | What |
| --- | --- | --- |
| Restaurant / charity | Goals tab → `+` | Publish a goal: food, target + unit, category, optional title, deadline and reason |
| Restaurant / charity | Goals tab | Follow every goal live: progress, donors, latest gift; close a goal, or delete it while nobody gave |
| User | Donations → Donation goals (and "See all") | Open goals with their progress; "You have … in your fridge" when a fridge food matches |
| User | Goal → Give | Choose a matching fridge food (converted to the goal unit, it leaves the fridge without counting as eaten) or "Food not in my fridge"; the quantity is capped at what is still needed and at what the user has |
| User | Fridge → food details | "<Charity> needs milk" banner with a Give button when an open goal asks for this food |
| Admin | Goals tab | Every goal of every restaurant |

- Stored in `users/shared/donation_goals` (shared by every account), not at the top level: the rules deployed on the Firebase project only open `users/...` and `donations/...`.
- The progress is never stored: it is the sum of the contributions, which are appended with `arrayUnion`, so two donors giving at the same moment both count. The goal is reached when the sum reaches the target; it can no longer receive gifts once reached, closed or past its deadline.
- Tests: `test/features/goals/` (rules, conversions, fridge link, screens for users, restaurants and the admin).

**Demo data** — `dart run tool/seed_demo_goals.dart` (default password `Demo2026`) creates or reuses five demo accounts, fills Khaoula's fridge (12 foods + 2 weeks of history for the anti-waste stats) and publishes 5 goals with some progress. Run it again the day before the demo: all dates are relative to today and the goals start again from the same progress.

| Account | Role | Used for |
| --- | --- | --- |
| `khaoula.demo@example.com` | user | Fridge, expiry, stats, giving to goals |
| `maintendue.demo@example.com` | restaurant (Association Main Tendue) | Goals: rice 5.5/10 kg, milk 10/12 L, pasta reached |
| `jardin.demo@example.com` | restaurant (Le Jardin Solidaire) | Goals: eggs 24/60, tomatoes 1/5 kg |
| `sami.demo@example.com`, `lina.demo@example.com` | user | The other donors already in the goals |

Scenario (two phones, or sign out / in):
1. Charity phone (`maintendue`): Goals tab → rice 55 %, milk 83 %, pasta reached. Publish a new goal with `+`.
2. Khaoula's phone: Fridge → Milk (expires in 2 days) → banner "Association Main Tendue needs milk" → Give 2 L → **goal reached**, the milk leaves the fridge.
3. Donations → Donation goals → Rice for the soup kitchen → Give → choose Basmati rice → 2 kg → 75 %.
4. Back on the charity phone: the bars moved in real time, "Latest: Khaoula gave 2 kg of rice".

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
| `presentation/` | `DonationsScreen`, `CreateDonationScreen`, `DonationDetailsScreen`, `DonationHistoryScreen`, `DonationLeaderboardScreen` |

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
| Classement des aliments les plus donnés | Trophy icon on Donations → **Top donated foods**: completed (collected) donations of every user, grouped by food name and unit, with total quantity and number of donations, most donated first (`donations/domain/donation_leaderboard.dart`) |

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

## Membre 5 — Recettes intelligentes et Tableau de bord (Recipes & Dashboard module)

Code: `lib/features/recipes/`, `lib/features/statistics/`, `lib/features/home/` · Spec: [docs/SPEC_MEMBRE5.md](docs/SPEC_MEMBRE5.md)

| Folder | Content |
| --- | --- |
| `recipes/domain/` | `extra_recipes.dart` (16 recipes + `allRecipes` = 28 with the fridge book), `recipe_search.dart` (matching, search, filters), `SavedRecipe`, `nutrition.dart` (kcal, macros, health tags), `health_goal.dart` |
| `recipes/data/` | `SavedRecipesRepository` (ChangeNotifier), `SavedRecipesFirestore`, `HealthProfileRepository`, `HealthProfileFirestore` |
| `recipes/presentation/` | `RecipeBookScreen` (Recipes), `SavedRecipesScreen`, `RecipeViewScreen` (details), `RecipeTile` |
| `statistics/domain/` | `impact.dart` (weights, meals saved, CO₂, score, periods), `activity.dart` (action history), `nutrition_stats.dart` (calories of cooked meals), `challenges.dart` (weekly challenges) |
| `statistics/presentation/` | `StatisticsScreen`, `ActivityHistoryScreen` |
| `home/presentation/` | `FoodSaverHomePage` (Home Dashboard) |

| Feature (cahier des charges) | Where |
| --- | --- |
| Suggestions de recettes selon les ingrédients disponibles | Recipes → "Suggested for you" (recipes saving the foods that expire soonest first); Home → "Cook before it expires" |
| Recherche de recettes | Recipes search bar (recipe name or ingredient) + filters: Ready to cook, Uses my fridge, Quick (≤ 15 min) |
| Sauvegarde des recettes favorites | Heart on every recipe card and in the recipe details |
| Consultation des recettes enregistrées | Recipes → heart icon, Home → Your impact → saved recipes, or Profile → Saved recipes |
| Tableau de bord principal | Home: greeting with the first name, meals saved this week, Fridge / Recipes / Donations / Assistant, Your impact, Expiring soon, recipe idea |
| Calcul des repas sauvés | Saved food = eaten, cooked, or donated and collected; 1 meal ≈ 400 g |
| Calcul de l'impact environnemental | CO₂ avoided = saved kg × factor of the category (e.g. 0.8 vegetables, 15 meat & fish), car km equivalent (120 g/km) |
| Bonus: healthy lifestyle | kcal and macros per recipe, health tags and filters, health goal (Profile) ranking the suggestions, calories of cooked meals and weekly challenges in Statistics |
| Statistiques utilisateur | Home → Food saved card, or Statistics: week / month / all time, score, last 7 days chart, breakdown |
| Historique des actions | Statistics → Recent activity → See all: grouped by day, with filters |

Statistics are never stored: they are recomputed from `fridge_history` and the donations. Recipe details also offer "Add missing to shopping list" (Membre 4) and "I cooked it" (recorded in the fridge history of Membre 2).

Tests: `test/features/recipes/`, `test/features/statistics/`, `test/features/home/`

## Base de données — Firestore (Membres 2, 3, 4 et 5)

The fridge, shopping lists, donations and notifications are saved in **Cloud Firestore**.

| Collection | Content | Code |
| --- | --- | --- |
| `users/{userId}` | `displayName`, `email`, `photo` (base64 JPEG), `createdAt`, `settings`, `role` (`user` / `restaurant` / `admin`), `businessName` (restaurants), `customFoodCategories`, `fridgeSeeded`, `importedShoppingItemIds`, `customShoppingCategories`, `selectedShoppingListId`, `readNotificationIds` | — |
| `users/{userId}/fridge_items/{id}` | `name`, `category`, `quantity`, `unit`, `expiryDate`, `addedAt`, `note` (listened to in real time) | `lib/features/fridge/data/fridge_firestore.dart` |
| `users/{userId}/fridge_history/{id}` | `type` (consumed / wasted), `foodName`, `category`, `quantity`, `unit`, `at`, `daysLeft`, `recipe` | `lib/features/fridge/data/fridge_firestore.dart` |
| `users/{userId}/shopping_lists/{listId}` | `name`, `createdAt`, `items: [...]` | `lib/features/list/data/shopping_list_firestore.dart` |
| `users/{userId}/notifications/{id}` | donation events: `type`, `title`, `body`, `donationId`, `createdAt` | `lib/features/notifications/data/notification_firestore.dart` |
| `users/{userId}/saved_recipes/{recipeId}` | favorite recipes: `savedAt` (the recipe itself comes from the app) | `lib/features/recipes/data/saved_recipes_firestore.dart` |
| `users/{userId}/health/profile` | health goal: `goal`, `updatedAt` | `lib/features/recipes/data/health_profile_firestore.dart` |
| `donations/{donationId}` | `donorId`, `foodName`, `category`, `quantity`, `unit`, `expiryDate`, `status`, `requests: [...]` | `lib/features/donations/data/donation_firestore.dart` |
| `users/shared/donation_goals/{goalId}` | `restaurantId`, `restaurantName`, `title`, `foodName`, `category`, `target`, `unit`, `description`, `deadline`, `createdAt`, `closed`, `contributions: [{id, donorId, donorName, quantity, createdAt, fromFridge}]` (listened to in real time) | `lib/features/goals/data/goal_firestore.dart` |

- Every module reads and writes under the signed-in uid (`CurrentUser.uid`, `lib/core/session/current_user.dart`). `SessionBinder` empties and reloads the repositories when the account changes. Without Firebase (tests) the fixed `demo-user` is used.
- Roles (beyond the original split): a normal **user** donates food and uses the fridge, a **restaurant** requests donations and publishes donation goals, an **admin** accepts or refuses requests. The role is chosen at sign-up (user or restaurant, never admin), cannot be changed afterwards, and admin is set by hand in the Firebase console.
- Expiry alerts are never stored: they are recomputed from the fridge expiry dates.
- If Firebase is not configured (or in tests), the app falls back to in-memory data.
- Rules: `firestore.rules` is the auth-based version with roles (tested with the emulator: `cd firestore-tests && npm test`; not deployed yet). The previous open development rules are kept as a comment at the bottom.

Setup (once per developer):

```bash
firebase login
flutterfire configure
```

Then in the Firebase console: Build → Firestore Database → Create database.
