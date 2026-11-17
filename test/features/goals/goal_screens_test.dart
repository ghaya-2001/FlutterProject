import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/core/session/current_user.dart';
import 'package:foodsaver/features/auth/data/auth_repository.dart';
import 'package:foodsaver/features/donations/data/donation_repository.dart';
import 'package:foodsaver/features/donations/presentation/donations_screen.dart';
import 'package:foodsaver/features/fridge/data/fridge_repository.dart';
import 'package:foodsaver/features/fridge/domain/food_category.dart';
import 'package:foodsaver/features/fridge/domain/food_item.dart';
import 'package:foodsaver/features/fridge/presentation/food_details_screen.dart';
import 'package:foodsaver/features/goals/data/goal_repository.dart';
import 'package:foodsaver/features/goals/domain/donation_goal.dart';
import 'package:foodsaver/features/goals/presentation/donation_goals_screen.dart';
import 'package:foodsaver/features/goals/presentation/restaurant_goals_tab.dart';
import 'package:foodsaver/features/profile/data/user_profile_repository.dart';
import 'package:foodsaver/features/profile/domain/user_role.dart';
import 'package:foodsaver/features/roles/presentation/role_home.dart';

void main() {
  final today = DateTime(2026, 11, 17, 10);
  final dairy = defaultFoodCategories.firstWhere((c) => c.name == 'Dairy');

  late FridgeRepository fridge;
  late GoalRepository goals;
  late DonationGoal milkGoal;

  setUp(() {
    fridge = FridgeRepository(clock: () => today);
    goals = GoalRepository(fridge: fridge, seed: false);
    // A charity published a goal; the donor (demo-user) has 1 L of milk.
    CurrentUser.bind('charity');
    milkGoal = goals.createGoal(
      restaurantName: 'Restos du Cœur',
      title: "Milk for the children's breakfast",
      foodName: 'Milk',
      category: dairy,
      target: 3,
      unit: 'L',
    );
    CurrentUser.bind(null);
  });

  FoodItem milk() => fridge.items.firstWhere((item) => item.name == 'Milk');

  Future<void> openGoalsScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: DonationGoalsScreen(repository: goals)),
    );
  }

  testWidgets('a user sees the goal with its progress and their fridge food', (
    tester,
  ) async {
    await openGoalsScreen(tester);

    expect(find.byKey(ValueKey('goal-${milkGoal.id}')), findsOneWidget);
    expect(find.text("Milk for the children's breakfast"), findsOneWidget);
    expect(find.text('0 / 3 L'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(
      find.byKey(ValueKey('goal-in-fridge-${milkGoal.id}')),
      findsOneWidget,
    );
  });

  testWidgets('giving from the fridge moves the progress bar', (tester) async {
    await openGoalsScreen(tester);

    await tester.tap(find.byKey(ValueKey('goal-${milkGoal.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goal-hero')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('give-to-goal-button')));
    await tester.pumpAndSettle();

    // The fridge milk is chosen and the quantity is all of it (1 L).
    final chip = tester.widget<ChoiceChip>(
      find.byKey(ValueKey('goal-source-${milk().id}')),
    );
    expect(chip.selected, isTrue);
    final milkId = milk().id;
    await tester.tap(find.byKey(const ValueKey('goal-quantity-minus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-quantity-minus')));
    await tester.pump();
    // 1 - 0.5 - 0.5 = 0 is refused...
    await tester.tap(find.byKey(const ValueKey('confirm-contribution-button')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('goal-contribution-error')),
      findsOneWidget,
    );
    // ...0.5 L is accepted.
    await tester.tap(find.byKey(const ValueKey('goal-quantity-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-contribution-button')));
    await tester.pumpAndSettle();

    expect(goals.goalById(milkGoal.id)!.collected, 0.5);
    expect(fridge.itemById(milkId)!.quantity, 0.5);
    expect(find.text('16%'), findsOneWidget);
    expect(find.text('0.5 / 3 L'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-my-contribution')), findsOneWidget);
    expect(find.text('+0.5 L'), findsOneWidget);
    expect(find.textContaining('You gave 0.5 L'), findsWidgets);
  });

  testWidgets('the gift that reaches the target ends the goal', (tester) async {
    // Two other donors already gave 2.5 L.
    CurrentUser.bind('someone');
    goals.contribute(milkGoal.id, quantity: 2.5, donorName: 'Sami');
    CurrentUser.bind(null);
    await openGoalsScreen(tester);

    await tester.tap(find.byKey(ValueKey('goal-${milkGoal.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('give-to-goal-button')));
    await tester.pumpAndSettle();
    // Capped at what is still needed: 0.5 L, not the whole litre.
    expect(find.text('Give 0.5 L'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-contribution-button')));
    await tester.pumpAndSettle();

    expect(goals.goalById(milkGoal.id)!.isReached, isTrue);
    expect(find.textContaining('Goal reached thanks to you'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byKey(const ValueKey('give-to-goal-button')), findsNothing);
  });

  testWidgets('food not in the fridge can be given too', (tester) async {
    await openGoalsScreen(tester);
    await tester.tap(find.byKey(ValueKey('goal-${milkGoal.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('give-to-goal-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-source-other')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('goal-quantity-field')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-contribution-button')));
    await tester.pumpAndSettle();

    expect(goals.goalById(milkGoal.id)!.collected, 2);
    expect(milk().quantity, 1); // the fridge is untouched
  });

  testWidgets('the fridge food details show who needs this food', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDetailsScreen(
          repository: fridge,
          foodId: milk().id,
          goalRepository: goals,
        ),
      ),
    );

    expect(
      find.byKey(ValueKey('food-needed-by-${milkGoal.id}')),
      findsOneWidget,
    );
    expect(find.text('Restos du Cœur needs milk'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('give-food-to-${milkGoal.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-contribution-button')));
    await tester.pumpAndSettle();

    // All the milk was given: it left the fridge.
    expect(goals.goalById(milkGoal.id)!.collected, 1);
    expect(fridge.items.any((item) => item.name == 'Milk'), isFalse);
  });

  testWidgets('restaurants do not see the banner on their own stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FoodDetailsScreen(
          repository: fridge,
          foodId: milk().id,
          goalRepository: goals,
          canDonate: false,
        ),
      ),
    );
    expect(find.byKey(ValueKey('food-needed-by-${milkGoal.id}')), findsNothing);
  });

  testWidgets('the Donations screen shows the open goals', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: DonationsScreen(
          repository: DonationRepository(fridge: fridge, seed: false),
          goals: goals,
        ),
      ),
    );

    expect(
      find.byKey(ValueKey('donations-goal-${milkGoal.id}')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('see-all-goals-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DonationGoalsScreen), findsOneWidget);
  });

  group('restaurant and admin', () {
    late AuthRepository auth;
    late UserProfileRepository profiles;

    Future<void> signUp(UserRole role) async {
      auth = AuthRepository();
      profiles = UserProfileRepository(auth: auth);
      profiles.prepareSignUp(role: role, businessName: 'Le Jardin');
      await auth.signUp(
        displayName: 'Sam',
        email: 'sam@example.com',
        password: 'secret12',
      );
    }

    Future<void> pumpShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: RoleHome(
            profiles: profiles,
            auth: auth,
            fridge: FridgeRepository(seed: false, clock: () => today),
            donations: DonationRepository(fridge: fridge, seed: false),
            goals: goals,
          ),
        ),
      );
      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();
    }

    testWidgets('a restaurant publishes a goal and follows it', (tester) async {
      await signUp(UserRole.restaurant);
      CurrentUser.bind(profiles.profile!.uid);
      addTearDown(() => CurrentUser.bind(null));
      await pumpShell(tester);

      // The charity's goal belongs to someone else.
      expect(find.byKey(ValueKey('my-goal-${milkGoal.id}')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('new-goal-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-goal-button')));
      await tester.pump();
      expect(find.text('Enter the food you need'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('goal-food-field')),
        'Rice',
      );
      await tester.enterText(
        find.byKey(const ValueKey('goal-target-field')),
        '10',
      );
      await tester.tap(find.byKey(const ValueKey('save-goal-button')));
      await tester.pumpAndSettle();

      final mine = goals.myGoals.single;
      expect(mine.title, 'Rice needed');
      expect(mine.restaurantName, 'Le Jardin');
      expect(mine.target, 10);
      expect(mine.unit, 'kg');
      expect(find.byKey(ValueKey('my-goal-${mine.id}')), findsOneWidget);
      expect(find.text('0 / 10 kg'), findsOneWidget);

      // A donor gives: the restaurant's list follows.
      CurrentUser.bind('donor');
      goals.contribute(mine.id, quantity: 4, donorName: 'Maya');
      CurrentUser.bind(profiles.profile!.uid);
      await tester.pumpAndSettle();
      expect(find.text('4 / 10 kg'), findsOneWidget);
      expect(find.textContaining('Maya gave 4 kg of rice'), findsOneWidget);

      // The restaurant cannot give to its own goal, but can close it.
      await tester.tap(find.byKey(ValueKey('my-goal-${mine.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('give-to-goal-button')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('close-goal-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-close-goal-button')));
      await tester.pumpAndSettle();
      expect(goals.goalById(mine.id)!.status(today), GoalStatus.closed);
    });

    testWidgets('the admin follows every goal without publishing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RestaurantGoalsTab(
              title: 'Donation goals',
              forAdmin: true,
              repository: goals,
            ),
          ),
        ),
      );

      expect(find.byKey(ValueKey('my-goal-${milkGoal.id}')), findsOneWidget);
      expect(find.text('Restos du Cœur'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-goal-button')), findsNothing);
    });
  });
}
