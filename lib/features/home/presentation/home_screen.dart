import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../../chatbot/presentation/chatbot_screen.dart';
import '../../donations/data/donation_repository.dart';
import '../../donations/presentation/donations_screen.dart';
import '../../expiry/domain/expiry_alerts.dart';
import '../../expiry/presentation/expiring_soon_screen.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../fridge/domain/recipes.dart';
import '../../fridge/presentation/food_details_screen.dart';
import '../../fridge/presentation/fridge_screen.dart';
import '../../list/presentation/list_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../recipes/data/saved_recipes_repository.dart';
import '../../recipes/domain/recipe_search.dart';
import '../../recipes/presentation/recipe_book_screen.dart';
import '../../recipes/presentation/recipe_view_screen.dart';
import '../../recipes/presentation/saved_recipes_screen.dart';
import '../../statistics/domain/impact.dart';
import '../../statistics/presentation/statistics_screen.dart';

const _green = Color(0xFF2E7D32);
const _dark = Color(0xFF1B1B1B);

/// Home dashboard (Membre 5): greeting, meals saved this week, quick
/// actions, environmental impact, expiring foods and a recipe idea.
class FoodSaverHomePage extends StatefulWidget {
  const FoodSaverHomePage({
    super.key,
    this.fridge,
    this.donations,
    this.savedRecipes,
    this.profiles,
    this.auth,
  });

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final DonationRepository? donations;
  final SavedRecipesRepository? savedRecipes;
  final UserProfileRepository? profiles;
  final AuthRepository? auth;

  @override
  State<FoodSaverHomePage> createState() => _FoodSaverHomePageState();
}

class _FoodSaverHomePageState extends State<FoodSaverHomePage> {
  int _selectedIndex = 0;

  FridgeRepository get _fridge => widget.fridge ?? FridgeRepository.instance;
  DonationRepository get _donations =>
      widget.donations ?? DonationRepository.instance;
  SavedRecipesRepository get _saved =>
      widget.savedRecipes ?? SavedRecipesRepository.instance;
  UserProfileRepository get _profiles =>
      widget.profiles ?? UserProfileRepository.instance;
  AuthRepository get _auth => widget.auth ?? AuthRepository.instance;

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  void _openStatistics() => _open(
    StatisticsScreen(
      fridge: _fridge,
      donations: _donations,
      savedRecipes: _saved,
    ),
  );

  void _openRecipes() =>
      _open(RecipeBookScreen(fridge: _fridge, savedRecipes: _saved));

  /// First name of the signed-in user, or null when unknown.
  String? get _firstName {
    final name =
        _profiles.profile?.displayName ??
        _auth.currentUser?.displayName ??
        '';
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? null : first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _fridge,
            _donations,
            _saved,
            _profiles,
            _auth,
          ]),
          builder: (context, _) => _buildBody(context),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const FridgeScreen()),
            );
          }

          if (index == 2) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (context) => const ListScreen()));
          }

          if (index == 3) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            label: 'Fridge',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            label: 'List',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final fridge = _fridge;
    final now = fridge.now;
    final week = ImpactStats.from(
      history: fridge.history,
      donations: _donations.donations,
      now: now,
      period: StatsPeriod.week,
    );
    final allTime = ImpactStats.from(
      history: fridge.history,
      donations: _donations.donations,
      now: now,
    );
    final matches = matchAllRecipes(fridge.items, now);
    final ready = matches.where(isReadyToCook).length;
    final ideas = matches.where(usesFridge).toList();
    final soon = expiringSoon(fridge.items, now);
    final firstName = _firstName;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName == null
                            ? greetingFor(now)
                            : '${greetingFor(now)},',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        firstName ?? 'Welcome back',
                        key: const ValueKey('home-greeting-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  key: const ValueKey('home-notifications-button'),
                  onTap: () => _open(const NotificationsScreen()),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListenableBuilder(
                      listenable: NotificationRepository.instance,
                      builder: (context, _) {
                        final unread =
                            NotificationRepository.instance.unreadCount;
                        return Badge(
                          isLabelVisible: unread > 0,
                          label: Text('$unread'),
                          backgroundColor: const Color(0xFFE65100),
                          child: const Icon(
                            Icons.notifications_none,
                            color: _green,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MealsCard(stats: week, onTap: _openStatistics),
            const SizedBox(height: 26),
            const Text(
              'Quick actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _dark,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    key: const ValueKey('home-fridge-card'),
                    title: 'Fridge',
                    subtitle:
                        '${fridge.totalCount} '
                        '${fridge.totalCount == 1 ? 'item' : 'items'}',
                    icon: Icons.kitchen,
                    color: const Color(0xFFB2DFDB),
                    onTap: () => _open(const FridgeScreen()),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ActionCard(
                    key: const ValueKey('home-recipes-card'),
                    title: 'Recipes',
                    subtitle: ready > 0
                        ? '$ready ready to cook'
                        : '${ideas.length} '
                              '${ideas.length == 1 ? 'idea' : 'ideas'}',
                    icon: Icons.restaurant_menu,
                    color: const Color(0xFFFFE082),
                    onTap: _openRecipes,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Donations',
                    subtitle: _donations.pendingRequestCount == 0
                        ? 'Share your food'
                        : '${_donations.pendingRequestCount} new '
                              '${_donations.pendingRequestCount == 1 ? 'request' : 'requests'}',
                    icon: Icons.volunteer_activism_rounded,
                    color: const Color(0xFFC8E6C9),
                    onTap: () => _open(const DonationsScreen()),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ActionCard(
                    title: 'Assistant',
                    subtitle: 'Ask a question',
                    icon: Icons.chat_bubble_outline_rounded,
                    color: const Color(0xFFBBDEFB),
                    onTap: () => _open(const ChatbotScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _ImpactCard(
              stats: allTime,
              savedCount: _saved.count,
              onTap: _openStatistics,
              onSavedTap: () => _open(
                SavedRecipesScreen(fridge: _fridge, savedRecipes: _saved),
              ),
            ),
            const SizedBox(height: 22),
            _WhiteCard(
              // Live data from the fridge (Membre 3: Expiring soon).
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Expiring soon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('home-expiring-view-all'),
                        onPressed: () => _open(const ExpiringSoonScreen()),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (soon.isEmpty)
                    const Text(
                      'Nothing expires in the next 7 days.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  for (final item in soon.take(3)) ...[
                    _FoodItemRow(
                      name: item.name,
                      detail: daysLeftLabel(item, now),
                      color: statusColor(item.status(now)),
                      onPressed: () => _open(
                        FoodDetailsScreen(repository: fridge, foodId: item.id),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            if (ideas.isNotEmpty) ...[
              const SizedBox(height: 22),
              _RecipeIdeaCard(
                match: ideas.first,
                onTap: () => _open(
                  RecipeViewScreen(
                    recipeId: ideas.first.recipe.id,
                    fridge: _fridge,
                    savedRecipes: _saved,
                  ),
                ),
                onSeeAll: _openRecipes,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Good morning" before noon, "Good afternoon" until 18:00, then
/// "Good evening".
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MealsCard extends StatelessWidget {
  const _MealsCard({required this.stats, required this.onTap});

  final ImpactStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meals = stats.mealsSaved;
    return InkWell(
      key: const ValueKey('home-meals-card'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F2E7D32),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Food saved',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meals == 0
                        ? 'No meals saved yet this week'
                        : '$meals ${meals == 1 ? 'meal' : 'meals'} '
                              'saved this week',
                    key: const ValueKey('home-meals-saved'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    meals == 0
                        ? 'Eat or cook the food that expires soon to start '
                              'saving meals.'
                        : '${formatAmount(stats.savedKg)} kg of food · '
                              '${formatAmount(stats.co2AvoidedKg)} kg CO₂ '
                              'avoided',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.eco_outlined,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.stats,
    required this.savedCount,
    required this.onTap,
    required this.onSavedTap,
  });

  final ImpactStats stats;
  final int savedCount;
  final VoidCallback onTap;
  final VoidCallback onSavedTap;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your impact',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('home-impact-card'),
                onPressed: onTap,
                child: const Text(
                  'Statistics',
                  style: TextStyle(color: _green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ImpactValue(value: '${stats.mealsSaved}', label: 'meals saved'),
              _ImpactValue(
                value: '${formatAmount(stats.co2AvoidedKg)} kg',
                label: 'CO₂ avoided',
              ),
              _ImpactValue(
                value: stats.score == null ? '—' : '${stats.score}%',
                label: 'anti-waste',
              ),
            ],
          ),
          const Divider(height: 28),
          InkWell(
            key: const ValueKey('home-saved-card'),
            onTap: onSavedTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFE53935)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    savedCount == 0
                        ? 'No saved recipes yet'
                        : '$savedCount saved '
                              '${savedCount == 1 ? 'recipe' : 'recipes'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactValue extends StatelessWidget {
  const _ImpactValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _green,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _RecipeIdeaCard extends StatelessWidget {
  const _RecipeIdeaCard({
    required this.match,
    required this.onTap,
    required this.onSeeAll,
  });

  final RecipeMatch match;
  final VoidCallback onTap;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cook before it expires',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'All recipes',
                  style: TextStyle(color: _green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey('home-recipe-idea'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(recipe.icon, color: const Color(0xFFE65100)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recipe.minutes} min · uses '
                        '${match.used.values.map((f) => f.name).join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _dark),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodItemRow extends StatelessWidget {
  const _FoodItemRow({
    required this.name,
    required this.detail,
    required this.color,
    this.onPressed,
  });

  final String name;
  final String detail;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onPressed ?? () {},
          child: const Text(
            'Use now',
            style: TextStyle(color: _green, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
