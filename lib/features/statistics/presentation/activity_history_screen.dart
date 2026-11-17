import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/data/donation_repository.dart';
import '../../fridge/data/fridge_repository.dart';
import '../../fridge/domain/fridge_formatters.dart';
import '../../recipes/data/saved_recipes_repository.dart';
import '../domain/activity.dart';
import 'widgets/activity_tile.dart';

/// Every action of the user (Membre 5: "Historique des actions"), grouped
/// by day and filterable by type.
class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({
    super.key,
    this.fridge,
    this.donations,
    this.savedRecipes,
  });

  /// Default to the app-wide instances; injectable for tests.
  final FridgeRepository? fridge;
  final DonationRepository? donations;
  final SavedRecipesRepository? savedRecipes;

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  ActivityFilter _filter = ActivityFilter.all;

  FridgeRepository get _fridge => widget.fridge ?? FridgeRepository.instance;
  DonationRepository get _donations =>
      widget.donations ?? DonationRepository.instance;
  SavedRecipesRepository get _saved =>
      widget.savedRecipes ?? SavedRecipesRepository.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_fridge, _donations, _saved]),
          builder: (context, _) {
            final now = _fridge.now;
            final entries = buildActivity(
              history: _fridge.history,
              donations: _donations.donations,
              savedRecipes: _saved.saved,
            ).where(_filter.accepts).toList();

            final children = <Widget>[];
            String? currentDay;
            for (final entry in entries) {
              final day = dayLabel(entry.at, now);
              if (day != currentDay) {
                currentDay = day;
                children.add(SectionTitle(day));
              }
              children.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ActivityTile(entry: entry, now: now),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              children: [
                const ScreenHeader(title: 'Activity history'),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in ActivityFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('activity-filter-${filter.name}'),
                            label: Text(filter.label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                            selectedColor: const Color(0xFFC8E6C9),
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (entries.isEmpty) ...[
                  const SizedBox(height: 18),
                  const EmptyCard(
                    icon: Icons.history_rounded,
                    message: 'Nothing here yet.',
                  ),
                ],
                ...children,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Today", "Yesterday" or a date such as "24 Oct 2026".
String dayLabel(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatDate(day);
}
