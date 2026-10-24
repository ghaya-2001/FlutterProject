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
