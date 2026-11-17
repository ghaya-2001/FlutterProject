import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../profile/data/user_profile_repository.dart';
import '../data/goal_repository.dart';
import '../domain/donation_goal.dart';
import 'create_goal_screen.dart';
import 'goal_details_screen.dart';
import 'widgets/goal_widgets.dart';

/// Goals tab of [RoleShell].
///
/// Restaurants and charities see their own goals with the progress made by
/// donors and publish new ones; the admin ([forAdmin]) follows every goal.
class RestaurantGoalsTab extends StatelessWidget {
  const RestaurantGoalsTab({
    super.key,
    required this.title,
    this.forAdmin = false,
    this.repository,
    this.profiles,
  });

  final String title;
  final bool forAdmin;

  /// Default to the app-wide instances; injectable for tests.
  final GoalRepository? repository;
  final UserProfileRepository? profiles;

  GoalRepository get _repository => repository ?? GoalRepository.instance;
  UserProfileRepository get _profiles =>
      profiles ?? UserProfileRepository.instance;

  String get _restaurantName {
    final profile = _profiles.profile;
    final business = profile?.businessName.trim() ?? '';
    if (business.isNotEmpty) {
      return business;
    }
    final name = profile?.displayName.trim() ?? '';
    return name.isNotEmpty ? name : 'Restaurant';
  }

  Future<void> _create(BuildContext context) async {
    final title = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CreateGoalScreen(
          restaurantName: _restaurantName,
          repository: _repository,
        ),
      ),
    );
    if (title != null && context.mounted) {
      showAppSnackBar(context, '"$title" published');
    }
  }

  Future<void> _open(BuildContext context, DonationGoal goal) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => GoalDetailsScreen(
          goalId: goal.id,
          repository: _repository,
          profiles: _profiles,
          canContribute: false,
        ),
      ),
    );
    if (message != null && context.mounted) {
      showAppSnackBar(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repository,
      builder: (context, _) {
        final goals = forAdmin ? _repository.goals : _repository.myGoals;
        final now = _repository.now;
        final open = goals.where((goal) => goal.isOpen(now)).toList();
        final finished = goals.where((goal) => !goal.isOpen(now)).toList();
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ),
                if (!forAdmin)
                  HeaderIconButton(
                    key: const ValueKey('new-goal-button'),
                    icon: Icons.add_rounded,
                    tooltip: 'New goal',
                    onPressed: () => _create(context),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _Summary(goals: goals, now: now),
            const SectionTitle('In progress'),
            if (_repository.isLoading && goals.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (open.isEmpty)
              EmptyCard(
                icon: Icons.flag_outlined,
                message: forAdmin
                    ? 'Goals published by restaurants and charities will '
                          'appear here.'
                    : 'Publish what you need (e.g. 10 kg of rice) and follow '
                          'the progress as users give.',
              )
            else
              for (final goal in open)
                GoalCard(
                  key: ValueKey('my-goal-${goal.id}'),
                  goal: goal,
                  now: now,
                  showOwner: forAdmin,
                  onTap: () => _open(context, goal),
                ),
            if (finished.isNotEmpty) ...[
              const SectionTitle('Finished'),
              for (final goal in finished)
                GoalCard(
                  key: ValueKey('my-goal-${goal.id}'),
                  goal: goal,
                  now: now,
                  showOwner: forAdmin,
                  onTap: () => _open(context, goal),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.goals, required this.now});

  final List<DonationGoal> goals;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final reached = goals.where((goal) => goal.isReached).length;
    final open = goals.where((goal) => goal.isOpen(now)).length;
    final gifts = goals.fold<int>(0, (sum, g) => sum + g.contributions.length);
    final latest =
        [
          for (final goal in goals)
            for (final c in goal.contributions) (goal: goal, contribution: c),
        ]..sort(
          (a, b) =>
              b.contribution.createdAt.compareTo(a.contribution.createdAt),
        );
    return Container(
      key: const ValueKey('goals-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stat(value: '$open', label: 'open'),
              _Stat(value: '$reached', label: 'reached'),
              _Stat(value: '$gifts', label: gifts == 1 ? 'gift' : 'gifts'),
            ],
          ),
          if (latest.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Latest: ${latest.first.contribution.donorName} gave '
              '${formatQuantity(latest.first.contribution.quantity)} '
              '${latest.first.goal.unit} of ${latest.first.goal.foodName.toLowerCase()}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

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
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
