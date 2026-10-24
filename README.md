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
| `data/` | `FridgeRepository` (ChangeNotifier, in-memory store) |
| `presentation/` | `FridgeScreen`, `AddFoodScreen`, `EditFoodScreen`, `FoodDetailsScreen` |

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

Tests: `test/features/fridge/`
