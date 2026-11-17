import 'package:flutter/material.dart';

import '../../../fridge/domain/fridge_formatters.dart';
import '../../domain/donation_goal.dart';

/// "6.5 / 10 kg".
String goalProgressLabel(DonationGoal goal) =>
    '${formatQuantity(goal.collected)} / ${formatQuantity(goal.target)} '
    '${goal.unit}';

/// "3 days left", "Last day", "Ended 2 days ago" or "No deadline".
String goalDeadlineLabel(DonationGoal goal, DateTime now) {
  final days = goal.daysLeft(now);
  if (days == null) {
    return 'No deadline';
  }
  if (days < 0) {
    final ago = -days;
    return 'Ended $ago ${ago == 1 ? 'day' : 'days'} ago';
  }
  if (days == 0) {
    return 'Last day';
  }
  return '$days ${days == 1 ? 'day' : 'days'} left';
}

/// Rounded progress bar of a goal, animated when a donor gives.
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.goal,
    this.height = 12,
    this.onDark = false,
  });

  final DonationGoal goal;
  final double height;

  /// White on the green hero card, green on white cards.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fill = onDark
        ? Colors.white
        : goal.isReached
        ? const Color(0xFF1565C0)
        : const Color(0xFF2E7D32);
    final track = onDark
        ? Colors.white.withValues(alpha: 0.25)
        : const Color(0xFFE8F5E9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: goal.progress),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: height,
          color: fill,
          backgroundColor: track,
        ),
      ),
    );
  }
}

/// Small coloured label: "Open", "Goal reached", "Closed" or "Ended".
class GoalStatusChip extends StatelessWidget {
  const GoalStatusChip({super.key, required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: goalStatusBackground(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        goalStatusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: goalStatusColor(status),
        ),
      ),
    );
  }
}

/// One goal in a list: who needs what, the progress bar and what is left.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.now,
    required this.onTap,
    this.showOwner = true,
  });

  final DonationGoal goal;
  final DateTime now;
  final VoidCallback onTap;

  /// False in the restaurant's own list (they know it is theirs).
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final status = goal.status(now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: goal.category.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      goal.category.icon,
                      color: const Color(0xFF1B1B1B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          showOwner
                              ? goal.restaurantName
                              : '${goal.donorCount} '
                                    '${goal.donorCount == 1 ? 'donor' : 'donors'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (status == GoalStatus.open)
                    Text(
                      '${goal.percent}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    )
                  else
                    GoalStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 14),
              GoalProgressBar(goal: goal),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    goalProgressLabel(goal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    status == GoalStatus.open
                        ? goalDeadlineLabel(goal, now)
                        : status == GoalStatus.reached
                        ? 'Thank you, donors!'
                        : goalStatusLabel(status),
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          status == GoalStatus.open &&
                              (goal.daysLeft(now) ?? 99) <= 1
                          ? const Color(0xFFE65100)
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
