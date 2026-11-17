import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../profile/data/user_profile_repository.dart';
import '../data/goal_repository.dart';
import '../domain/donation_goal.dart';
import 'widgets/contribute_sheet.dart';
import 'widgets/goal_widgets.dart';

/// Everything about one goal: progress, who gave what, and the actions
/// (give for users; close or delete for the restaurant that published it).
class GoalDetailsScreen extends StatelessWidget {
  const GoalDetailsScreen({
    super.key,
    required this.goalId,
    this.repository,
    this.profiles,
    this.canContribute = true,
  });

  final String goalId;

  /// Defaults to [GoalRepository.instance]; injectable for tests.
  final GoalRepository? repository;
  final UserProfileRepository? profiles;

  /// False for restaurants and the admin: only users give.
  final bool canContribute;

  GoalRepository get _repository => repository ?? GoalRepository.instance;

  Future<void> _give(BuildContext context, DonationGoal goal) async {
    final message = await showContributeSheet(
      context,
      repository: _repository,
      goal: goal,
      profiles: profiles,
    );
    if (message != null && context.mounted) {
      showAppSnackBar(context, message);
    }
  }

  Future<void> _close(BuildContext context, DonationGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this goal?'),
        content: Text(
          'Donors will no longer be able to give. '
          '${formatQuantity(goal.collected)} ${goal.unit} were collected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-close-goal-button'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Close goal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    _repository.closeGoal(goal.id);
    showAppSnackBar(context, 'Goal closed');
  }

  void _delete(BuildContext context, DonationGoal goal) {
    _repository.deleteGoal(goal.id);
    Navigator.of(context).pop('Goal deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _repository,
          builder: (context, _) {
            final goal = _repository.goalById(goalId);
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              children: [
                const ScreenHeader(title: 'Donation goal'),
                const SizedBox(height: 18),
                if (goal == null)
                  const EmptyCard(
                    icon: Icons.search_off_rounded,
                    message: 'This goal no longer exists.',
                  )
                else
                  ..._buildGoal(context, goal),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildGoal(BuildContext context, DonationGoal goal) {
    final now = _repository.now;
    final status = goal.status(now);
    final isOwner = goal.restaurantId == _repository.userId;
    final given = _repository.givenBy(goal);
    return [
      _Hero(goal: goal, now: now),
      if (goal.description.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote_rounded, color: Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal.description,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
      if (given > 0) ...[
        const SizedBox(height: 14),
        _Card(
          key: const ValueKey('goal-my-contribution'),
          color: const Color(0xFFE8F5E9),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You gave ${formatQuantity(given)} ${goal.unit} to this '
                  'goal. Thank you!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      if (status == GoalStatus.open && canContribute && !isOwner)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            key: const ValueKey('give-to-goal-button'),
            onPressed: () => _give(context, goal),
            icon: const Icon(Icons.volunteer_activism_rounded),
            label: Text(
              given > 0 ? 'Give more' : 'Give ${goal.foodName.toLowerCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      if (isOwner && status == GoalStatus.open)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const ValueKey('close-goal-button'),
                  onPressed: () => _close(context, goal),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text(
                    'Close goal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
            if (goal.contributions.isEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    key: const ValueKey('delete-goal-button'),
                    onPressed: () => _delete(context, goal),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFC62828)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      SectionTitle(
        'Donors',
        trailing: Text(
          '${goal.donorCount}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
      ),
      if (goal.contributions.isEmpty)
        const EmptyCard(
          icon: Icons.volunteer_activism_outlined,
          message: 'Nobody gave yet. Be the first one!',
        )
      else
        for (final contribution in goal.latestContributions)
          _ContributionTile(
            contribution: contribution,
            unit: goal.unit,
            now: now,
            isMe: contribution.donorId == _repository.userId,
          ),
    ];
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.goal, required this.now});

  final DonationGoal goal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = goal.status(now);
    return Container(
      key: const ValueKey('goal-hero'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: goal.isReached
              ? const [Color(0xFF0D47A1), Color(0xFF42A5F5)]
              : const [Color(0xFF1B5E20), Color(0xFF4CAF50)],
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
              Icon(goal.category.icon, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  goal.restaurantName,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              if (status != GoalStatus.open) GoalStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goal.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${goal.percent}%',
                key: const ValueKey('goal-percent'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goalProgressLabel(goal),
                  key: const ValueKey('goal-progress-label'),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GoalProgressBar(goal: goal, height: 14, onDark: true),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                goal.isReached
                    ? 'Reached on ${formatDate(goal.reachedAt!)}'
                    : goal.deadline == null
                    ? 'No deadline'
                    : 'Until ${formatDate(goal.deadline!)} · '
                          '${goalDeadlineLabel(goal, now)}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              if (!goal.isReached)
                Text(
                  '${formatQuantity(goal.remaining)} ${goal.unit} to go',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({
    required this.contribution,
    required this.unit,
    required this.now,
    required this.isMe,
  });

  final GoalContribution contribution;
  final String unit;
  final DateTime now;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = isMe ? 'You' : contribution.donorName;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isMe
                ? const Color(0xFFC8E6C9)
                : const Color(0xFFB2DFDB),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${_ago(contribution.createdAt, now)}'
                  '${contribution.fromFridge ? ' · from the fridge' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            '+${formatQuantity(contribution.quantity)} $unit',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.color = Colors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

String _ago(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays} days ago';
}
