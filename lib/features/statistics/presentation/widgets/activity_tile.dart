import 'package:flutter/material.dart';

import '../../domain/activity.dart';

const _styles = <ActivityType, (IconData, Color)>{
  ActivityType.eaten: (Icons.lunch_dining_rounded, Color(0xFFC8E6C9)),
  ActivityType.cooked: (Icons.restaurant_menu_rounded, Color(0xFFFFE082)),
  ActivityType.wasted: (Icons.delete_outline_rounded, Color(0xFFFFCDD2)),
  ActivityType.donated: (Icons.volunteer_activism_rounded, Color(0xFFB2DFDB)),
  ActivityType.donationCollected: (
    Icons.check_circle_outline_rounded,
    Color(0xFFB2DFDB),
  ),
  ActivityType.recipeSaved: (Icons.favorite_rounded, Color(0xFFFFCCBC)),
};

/// One line of the activity history.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry, required this.now});

  final ActivityEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _styles[entry.type]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF1B1B1B), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo(entry.at, now),
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

/// e.g. "now", "5 min", "3 h", "2 d", "4 w".
String timeAgo(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes} min';
  if (diff.inDays < 1) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return '${diff.inDays ~/ 7} w';
}
