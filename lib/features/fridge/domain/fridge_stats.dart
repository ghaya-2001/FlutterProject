import 'package:flutter/material.dart';

import 'food_category.dart';
import 'fridge_event.dart';

/// Consumed and wasted foods of one calendar day.
class DayStats {
  const DayStats({
    required this.date,
    required this.consumed,
    required this.wasted,
  });

  final DateTime date;
  final int consumed;
  final int wasted;

  int get total => consumed + wasted;
}

/// Anti-waste statistics computed from the fridge history.
///
/// Foods are counted, not quantities: units cannot be added together
/// (1 kg of tomatoes + 6 eggs).
class FridgeStats {
  FridgeStats(List<FridgeEvent> history, DateTime now, {this.days = 7})
    : _history = history,
      _today = DateUtils.dateOnly(now);

  final List<FridgeEvent> _history;
  final DateTime _today;

  /// Number of days shown in [lastDays].
  final int days;

  bool get isEmpty => _history.isEmpty;

  int get consumedCount => _history.where((event) => !event.isWaste).length;

  int get wastedCount => _history.where((event) => event.isWaste).length;

  /// Share of foods eaten instead of thrown away, from 0 to 100.
  /// Null while there is no history yet.
  int? get score {
    final total = _history.length;
    if (total == 0) {
      return null;
    }
    return (consumedCount * 100 / total).round();
  }

  /// One entry per day for the last [days] days, oldest first.
  List<DayStats> get lastDays {
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        _dayStats(DateUtils.addDaysToDate(_today, -offset)),
    ];
  }

  DayStats _dayStats(DateTime date) {
    var consumed = 0;
    var wasted = 0;
    for (final event in _history) {
      if (DateUtils.isSameDay(event.at, date)) {
        event.isWaste ? wasted++ : consumed++;
      }
    }
    return DayStats(date: date, consumed: consumed, wasted: wasted);
  }

  /// Categories of the thrown away foods, most wasted first.
  List<MapEntry<FoodCategory, int>> get wastedByCategory {
    final counts = <FoodCategory, int>{};
    for (final event in _history.where((event) => event.isWaste)) {
      counts[event.category] = (counts[event.category] ?? 0) + 1;
    }
    return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Days since the last thrown away food, or since the first event when
  /// nothing was ever wasted. Null while there is no history yet.
  int? get daysWithoutWaste {
    if (_history.isEmpty) {
      return null;
    }
    final wasted = _history.where((event) => event.isWaste);
    final DateTime since;
    if (wasted.isEmpty) {
      since = _history.map((e) => e.at).reduce((a, b) => a.isBefore(b) ? a : b);
    } else {
      since = wasted.map((e) => e.at).reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final from = DateUtils.dateOnly(since);
    return DateTime.utc(
      _today.year,
      _today.month,
      _today.day,
    ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  }
}
