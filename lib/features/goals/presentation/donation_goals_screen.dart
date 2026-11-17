import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../profile/data/user_profile_repository.dart';
import '../data/goal_repository.dart';
import '../domain/donation_goal.dart';
import 'goal_details_screen.dart';
import 'widgets/goal_widgets.dart';

/// Goals published by restaurants and charities, for users who want to help.
class DonationGoalsScreen extends StatelessWidget {
  const DonationGoalsScreen({super.key, this.repository, this.profiles});

  /// Defaults to [GoalRepository.instance]; injectable for tests.
  final GoalRepository? repository;
  final UserProfileRepository? profiles;

  GoalRepository get _repository => repository ?? GoalRepository.instance;

  Future<void> _open(BuildContext context, DonationGoal goal) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => GoalDetailsScreen(
          goalId: goal.id,
          repository: _repository,
          profiles: profiles,
        ),
      ),
    );
    if (message != null && context.mounted) {
      showAppSnackBar(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_repository, _repository.fridge]),
          builder: (context, _) {
            final open = _repository.openGoals;
            final finished = _repository.finishedGoals;
            final now = _repository.now;
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              children: [
                const ScreenHeader(title: 'Donation goals'),
                const SizedBox(height: 18),
                _Intro(
                  openCount: open.length,
                  supportedCount: _repository.supportedGoals.length,
                ),
                const SectionTitle('Need your help'),
                if (_repository.isLoading && open.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (open.isEmpty)
                  const EmptyCard(
                    icon: Icons.flag_outlined,
                    message:
                        'No open goal right now. Restaurants and charities '
                        'publish what they need here.',
                  )
                else
                  for (final goal in open)
                    _OpenGoal(
                      goal: goal,
                      now: now,
                      fromFridge: _repository.fridgeFoodsFor(goal).isNotEmpty,
                      onTap: () => _open(context, goal),
                    ),
                if (finished.isNotEmpty) ...[
                  const SectionTitle('Finished'),
                  for (final goal in finished)
                    GoalCard(
                      key: ValueKey('goal-${goal.id}'),
                      goal: goal,
                      now: now,
                      onTap: () => _open(context, goal),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpenGoal extends StatelessWidget {
  const _OpenGoal({
    required this.goal,
    required this.now,
    required this.fromFridge,
    required this.onTap,
  });

  final DonationGoal goal;
  final DateTime now;

  /// The user has this food in the fridge.
  final bool fromFridge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fromFridge)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.kitchen_rounded,
                  size: 15,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(width: 5),
                Text(
                  'You have ${goal.foodName.toLowerCase()} in your fridge',
                  key: ValueKey('goal-in-fridge-${goal.id}'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
        GoalCard(
          key: ValueKey('goal-${goal.id}'),
          goal: goal,
          now: now,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.openCount, required this.supportedCount});

  final int openCount;
  final int supportedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$openCount open ${openCount == 1 ? 'goal' : 'goals'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  supportedCount == 0
                      ? 'Give what you have, every gift moves the bar.'
                      : 'You helped $supportedCount '
                            '${supportedCount == 1 ? 'goal' : 'goals'}. '
                            'Thank you!',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}
