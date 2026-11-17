# Spécification — Membre 5 : Recettes intelligentes & Tableau de bord

Branche : `feature/m5-recipes-dashboard` · Référence : *Food_Saver_Repartition_Finale* (Membre 5)

## 0. Périmètre

| Fonctionnalité (cahier des charges) | Livré par | Écran |
| --- | --- | --- |
| Suggestions de recettes selon les ingrédients disponibles | `recipes/` (réutilise l'algorithme de Membre 2) | Recipes |
| Recherche de recettes | `recipes/domain/recipe_search.dart` | Recipes |
| Sauvegarde des recettes favorites | `SavedRecipesRepository` + Firestore | Recipes, Recipe details |
| Consultation des recettes enregistrées | — | Saved Recipes |
| Tableau de bord principal | `home/` (données réelles) | Home Dashboard |
| Calcul des repas sauvés | `statistics/domain/impact.dart` | Home, Statistics, Profile |
| Calcul de l'impact environnemental | `statistics/domain/impact.dart` | Home, Statistics |
| Statistiques utilisateur | `statistics/` | Statistics |
| Historique des actions | `statistics/domain/activity.dart` | Statistics, Activity history |

Hors périmètre : l'écran « Cook now » et les statistiques anti-gaspi du Frigo (Membre 2) restent inchangés ; on les réutilise sans modifier leur code.

## 1. Décisions

- **Recettes : livre local, hors ligne.** Les 12 recettes de Membre 2 (`fridge/domain/recipes.dart`) + 16 recettes ajoutées dans `recipes/domain/extra_recipes.dart` = **28 recettes**. Aucune API externe, aucun nouveau paquet.
- Le *matching* frigo ↔ recette réutilise `suggestRecipes` / `RecipeMatch` de Membre 2.
- Favoris stockés dans Firestore : `users/{uid}/saved_recipes/{recipeId}`.
- Les statistiques ne sont **jamais stockées** : elles sont recalculées à partir de `fridge_history` (Membre 2), des dons (`donations/`) et des favoris. Même principe que les alertes de péremption.

## 2. Formules de calcul (`statistics/domain/impact.dart`)

### 2.1 Nourriture sauvée
Un aliment est **sauvé** quand il est :
1. consommé avant d'être jeté (événement `consumed` de `fridge_history`, y compris « I cooked it » d'une recette), ou
2. donné et **récupéré** (don au statut `collected`).

Un aliment **gaspillé** = événement `wasted` (« Throw away »).

### 2.2 Poids (kg)
| Unité | Poids |
| --- | --- |
| `kg` / `L` | quantité |
| `g` / `ml` | quantité / 1000 |
| `pcs` / `pack` / autre | quantité × poids moyen d'une pièce selon la catégorie |

Poids moyen d'une pièce (kg) : Fruits 0,15 · Vegetables 0,25 · Dairy 0,2 · Meat & Fish 0,3 · Bakery 0,4 · Pantry 0,5 · Beverages 1,0 · Frozen 0,4 · Leftovers 0,3 · Other / catégorie perso 0,25.

### 2.3 Repas sauvés
`repas sauvés = arrondi(kg sauvés / 0,4)` — un repas ≈ 400 g de nourriture (estimation). Le résultat vaut au moins 1 dès qu'un aliment a été sauvé.

### 2.4 Impact environnemental
`CO₂ évité (kg) = Σ kg sauvés × facteur de la catégorie`

Facteurs (kg CO₂e par kg d'aliment, valeurs simplifiées d'après Poore & Nemecek 2018 / Our World in Data) :
Fruits 0,7 · Vegetables 0,8 · Dairy 4 · Meat & Fish 15 · Bakery 1,6 · Pantry 2,5 · Beverages 1 · Frozen 4 · Leftovers 3 · Other 2,5.

- Équivalent voiture : `km = CO₂ / 0,12` (voiture moyenne ≈ 120 g CO₂/km).
- CO₂ perdu : même calcul appliqué aux aliments gaspillés.

### 2.5 Score anti-gaspillage
`score = aliments sauvés / (sauvés + gaspillés) × 100`. Pas de score tant qu'il n'y a pas d'historique. Affiché comme « Impact » sur le Profil.

### 2.6 Périodes
`This week` = 7 derniers jours (aujourd'hui compris) · `This month` = 30 derniers jours · `All time`.

## 3. Modèle de données

| Chemin Firestore | Contenu | Code |
| --- | --- | --- |
| `users/{userId}/saved_recipes/{recipeId}` | `savedAt` (Timestamp) | `recipes/data/saved_recipes_firestore.dart` |

- Déjà couvert par la règle `users/{userId}/{collection}/{document=**}` de `firestore.rules` : pas de nouvelle règle, mais un test émulateur est ajouté.
- Ajouté à `UserProfileFirestore.userCollections` pour être supprimé avec le compte.
- `SessionBinder` vide les favoris à la déconnexion et les recharge pour le rôle `user`.

## 4. Architecture

```
lib/features/recipes/
├── domain/
│   ├── extra_recipes.dart        # 16 recettes de plus + allRecipes (28)
│   ├── recipe_search.dart        # RecipeFilter, matchRecipe, searchRecipes
│   └── saved_recipe.dart         # SavedRecipe(recipeId, savedAt)
├── data/
│   ├── saved_recipes_repository.dart   # ChangeNotifier, instance, connect/clear
│   └── saved_recipes_firestore.dart    # + savedRecipeToMap / savedRecipeFromMap
└── presentation/
    ├── recipe_book_screen.dart          # écran « Recipes »
    ├── saved_recipes_screen.dart        # écran « Saved Recipes »
    ├── recipe_view_screen.dart          # détails d'une recette (toutes les 28)
    └── widgets/recipe_tile.dart         # carte recette + bouton cœur

lib/features/statistics/
├── domain/
│   ├── impact.dart               # foodWeightKg, ImpactStats, StatsPeriod
│   └── activity.dart             # ActivityEntry, buildActivity
└── presentation/
    ├── statistics_screen.dart    # écran « Statistics »
    └── activity_history_screen.dart

lib/features/home/presentation/home_screen.dart   # Home Dashboard branché sur les vraies données
```

Conventions de l'équipe respectées : `domain/` sans Firebase ni widgets ; repository `ChangeNotifier` avec `remote` nullable et `clock` injectable ; écrans avec paramètres optionnels (`fridge`, `savedRecipes`, …) qui valent `.instance` par défaut ; `ListenableBuilder` ; navigation `MaterialPageRoute` ; textes UI en anglais ; couleurs du thème existant.

## 5. Écrans

### 5.1 Recipes (`RecipeBookScreen`)
- Titre « Recipes », bouton cœur en haut → Saved Recipes.
- Champ de recherche (`recipes-search-field`) : nom de la recette **ou** nom d'un ingrédient, insensible aux majuscules et aux accents.
- Filtres (`ChoiceChip`) : **All** · **Ready to cook** (aucun ingrédient manquant) · **Uses my fridge** (au moins un aliment du frigo) · **Quick** (≤ 15 min).
- Section « Suggested for you » (sans recherche ni filtre) : 3 meilleures suggestions, celles qui sauvent les aliments proches de la péremption d'abord.
- Liste : carte avec icône, nom, temps, aliments du frigo utilisés, tags (« Saves N expiring », « Ready to cook » / « N missing »), % de couverture, bouton cœur (`recipe-save-<id>`).
- Aucun résultat → `EmptyCard`.

### 5.2 Recipe details (`RecipeViewScreen`)
- Temps, couverture, cœur.
- Ingrédients : ✓ avec l'aliment du frigo utilisé (et sa péremption) ou ✗ manquant ; optionnels signalés.
- Étapes numérotées.
- **Add missing to shopping list** (liste sélectionnée de Membre 4, sinon nouvelle liste « Recipe ingredients »).
- **I cooked it** (si au moins un aliment du frigo est utilisé) : `FridgeRepository.cookRecipe` avec les quantités par défaut, donc compté comme repas sauvé dans les stats.

### 5.3 Saved Recipes (`SavedRecipesScreen`)
- Favoris, du plus récent au plus ancien, avec l'état du frigo (prête / N manquants).
- Retirer : cœur ou glisser à gauche, avec **Undo**.
- Vide → message + bouton « Browse recipes ».

### 5.4 Statistics (`StatisticsScreen`)
- `SegmentedButton` : This week / This month / All time.
- Carte principale : **N meals saved**.
- Tuiles : Food saved (kg) · CO₂ avoided (kg, « ≈ X km by car ») · Anti-waste score (%) · Food wasted (aliments, kg CO₂ perdus).
- Graphique 7 derniers jours (sauvés / gaspillés), fait à la main comme le reste de l'app.
- Répartition : Eaten · Cooked in recipes · Donated.
- Activité récente (5 dernières) → **See all** → Activity history.
- Bloc « How is this calculated? » (formules de §2).

### 5.5 Activity history (`ActivityHistoryScreen`)
- Toutes les actions, groupées par jour (Today, Yesterday, date), avec filtres : All · Eaten · Cooked · Wasted · Donations · Recipes.
- Types : aliment consommé · recette cuisinée (événements d'une même recette regroupés) · aliment jeté · don publié · don récupéré · recette ajoutée aux favoris.

### 5.6 Home Dashboard (`FoodSaverHomePage`)
- En-tête : « Good morning / afternoon / evening, » + prénom du profil (au lieu de « Maya » écrit en dur).
- Carte verte : **N meals saved this week** + « X kg of food · Y kg CO₂ avoided » (ou message d'encouragement si 0) → Statistics.
- Actions rapides : Fridge (« N items », ouvre le Frigo) · Recipes (« N ready to cook » / « N ideas », ouvre Recipes) · Donations · Assistant.
- Carte « Your impact » : score, CO₂, repas sauvés en tout → Statistics.
- « Expiring soon » inchangé ; nouvelle carte « Cook before it expires » avec la meilleure suggestion.
- Clés conservées (`home-notifications-button`, `home-expiring-view-all`) ; nouvelles clés `home-recipes-card`, `home-impact-card`, `home-saved-card`.

### 5.7 Profil (remplacement des valeurs en dur)
- « 128 Meals saved » → repas sauvés réels (all time).
- « 92% Impact » → score anti-gaspi (« — » sans historique).
- « Saved recipes · 18 favorites » → nombre réel, ouvre Saved Recipes.

## 6. Tests
- `test/features/recipes/` : recherche et filtres, `matchRecipe`, repository (favoris, ordre, undo, clear, fake Firestore), mapping Firestore, écrans Recipes / Saved / Details.
- `test/features/statistics/` : poids par unité, repas, CO₂, score, périodes, historique d'activité, écran Statistics.
- `test/features/home/` : dashboard avec données réelles et navigation.
- `firestore-tests/rules.test.js` : `saved_recipes` privé au propriétaire.
- Critère : `flutter analyze` propre, `flutter test` 100 % vert.

## 7. Documentation
Mettre à jour `TODO.md` (section Membre 5), `README.md` (section Membre 5 + table Firestore), `PROJECT_OVERVIEW.md` et `CLAUDE.md`.

## 8. Bonus : Healthy lifestyle (suggéré par le professeur)

### 8.1 Calories et macros par recette (`recipes/domain/nutrition.dart`)
- `recipeHealth` : pour chacune des 28 recettes, valeurs approximatives **par portion** : kcal, protéines, glucides, lipides (g), végétarien, sans gluten.
- Niveau : **Light** < 400 kcal ≤ **Balanced** < 500 kcal ≤ **Rich**.
- Répartition de l'énergie : protéines × 4, glucides × 4, lipides × 9 kcal/g.
- Affiché dans le détail d'une recette (carte « Nutrition » : kcal, niveau, barre des macros, tags) et sur chaque carte (« 390 kcal »).

### 8.2 Tags santé et filtres
- Tags : *Vegetarian* et *Gluten free* (selon les ingrédients), *Low calorie* (< 400 kcal) et *High protein* (≥ 20 g), calculés à partir des chiffres.
- Nouveaux filtres de l'écran Recipes : Vegetarian, High protein, Low calorie, Gluten free.

### 8.3 Objectif santé (`recipes/domain/health_goal.dart`)
| Objectif | Recettes adaptées |
| --- | --- |
| No goal | aucune (classement uniquement par le frigo) |
| Lose weight | < 400 kcal |
| Stay balanced | 300–600 kcal et ≥ 12 g de protéines |
| Build muscle | ≥ 20 g de protéines |
- Choisi dans Profile → *Health goal*, depuis la bannière de l'écran Recipes ou depuis Statistics.
- Les recettes adaptées passent en premier dans « Suggested for you » (`rankForGoal`, ordre conservé sinon) et portent le badge « Fits your goal ».
- Stocké dans `users/{uid}/health/profile` : `goal` (nom de l'enum), `updatedAt`. Repository : `HealthProfileRepository` (instance, `connect`/`clear` via `SessionBinder`, rôle user seulement). `health` est ajouté à `UserProfileFirestore.userCollections`.

### 8.4 Suivi dans Statistics (`statistics/domain/nutrition_stats.dart`)
- Un repas cuisiné = un « I cooked it » : les événements du frigo d'une même recette à moins d'1 minute d'écart forment **un** repas (1 portion). La recette est retrouvée par son nom (`recipeByName`).
- Sur la période choisie : kcal totales, nombre de repas, kcal moyennes par repas, barre et total des macros, nombre de repas adaptés à l'objectif.
- Jamais stocké : recalculé à partir de `fridge_history`.

### 8.5 Défis healthy de la semaine (`statistics/domain/challenges.dart`)
Calculés sur les 7 derniers jours, jamais stockés :
| Défi | Objectif |
| --- | --- |
| Veggie week | cuisiner 3 recettes végétariennes |
| Protein power | cuisiner 2 recettes riches en protéines |
| Light & tasty | cuisiner 3 repas < 400 kcal |
| Home chef | cuisiner 5 recettes |
| Zero waste | sauver 5 aliments sans rien jeter (remis à 0 dès qu'un aliment est jeté) |
- Affichés dans Statistics → *Weekly challenges* avec barre de progression, trophée et compteur « x/5 done ».

### 8.6 Tests
- `test/features/recipes/nutrition_test.dart`, `health_profile_repository_test.dart`, `health_screens_test.dart`.
- `test/features/statistics/nutrition_stats_test.dart` (repas, totaux, périodes, défis).
- `session_binder_test.dart` : la déconnexion oublie l'objectif. `firestore-tests/rules.test.js` : `health/profile` privé au propriétaire.
