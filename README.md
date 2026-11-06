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

## Membre 2 — Gestion du Frigo (Fridge module)

Code: `lib/features/fridge/`

| Folder | Content |
| --- | --- |
| `domain/` | `FoodItem`, `FoodCategory`, expiry status and formatting helpers |
| `data/` | `FridgeRepository` (ChangeNotifier), `FridgeFirestore` (Cloud Firestore) |
| `presentation/` | `FridgeScreen`, `AddFoodScreen`, `EditFoodScreen`, `FoodDetailsScreen`, `FridgeStatsScreen` |

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
| Consultation des annonces disponibles | Donations → "Available" tab (what beneficiaries see) |
| Demande de récupération par un bénéficiaire | "Request" (simulated: choose a sample restaurant or charity) |
| Acceptation / refus d'une demande | Donation Details → Accept / Refuse |
| Statut : disponible, réservé, récupéré | Accept → Reserved, "Mark as collected" → Collected |
| Historique des dons | History icon on Donations, or Profile → My donations |

Rules: the donated quantity is removed from the fridge; cancelling an available donation puts it back.
Beneficiary accounts don't exist yet, so requests are simulated (allowed by the cahier des charges).

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
| `users/{userId}` | `customFoodCategories`, `fridgeSeeded`, `customShoppingCategories`, `selectedShoppingListId`, `readNotificationIds` | — |
| `users/{userId}/fridge_items/{id}` | `name`, `category`, `quantity`, `unit`, `expiryDate`, `addedAt`, `note` (listened to in real time) | `lib/features/fridge/data/fridge_firestore.dart` |
| `users/{userId}/fridge_history/{id}` | `type` (consumed / wasted), `foodName`, `category`, `quantity`, `unit`, `at` | `lib/features/fridge/data/fridge_firestore.dart` |
| `users/{userId}/shopping_lists/{listId}` | `name`, `createdAt`, `items: [...]` | `lib/features/list/data/shopping_list_firestore.dart` |
| `users/{userId}/notifications/{id}` | donation events: `type`, `title`, `body`, `donationId`, `createdAt` | `lib/features/notifications/data/notification_firestore.dart` |
| `donations/{donationId}` | `donorId`, `foodName`, `category`, `quantity`, `unit`, `expiryDate`, `status`, `requests: [...]` | `lib/features/donations/data/donation_firestore.dart` |

- No authentication yet: every phone uses `userId = demo-user` (`lib/core/firebase/firebase_setup.dart`). Replace it with the Firebase Auth uid when login is ready.
- Expiry alerts are never stored: they are recomputed from the fridge expiry dates.
- If Firebase is not configured (or in tests), the app falls back to in-memory data.
- Rules: `firestore.rules` (open until 31 Jan 2027, auth-based version included as a comment).

Setup (once per developer):

```bash
firebase login
flutterfire configure
```

Then in the Firebase console: Build → Firestore Database → Create database.
