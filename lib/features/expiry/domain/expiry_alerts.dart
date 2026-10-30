import 'package:flutter/material.dart';

import '../../fridge/domain/food_item.dart';

/// Foods expiring within this many days appear in "Expiring soon".
const expiringSoonDays = 7;

/// Days before the expiry date on which an alert is sent (7 days, 3 days and
/// on the expiry day itself).
const expiryAlertDays = <int>[7, priorityThresholdDays, 0];

/// Hour of the day at which phone notifications are delivered.
const expiryAlertHour = 9;

enum ExpiryAlertLevel { sevenDays, threeDays, today, expired }

/// The most urgent alert for one fridge food.
///
/// Alerts are always computed from [FoodItem.expiryDate], so the fridge stays
/// the single source of truth for expiry dates.
class ExpiryAlert {
  const ExpiryAlert({
    required this.item,
    required this.level,
    required this.daysLeft,
  });

  final FoodItem item;
  final ExpiryAlertLevel level;
  final int daysLeft;

  /// Stable id, e.g. "expiry-food-12-threeDays" (used for the read state).
  String get id => 'expiry-${item.id}-${level.name}';

  String get title => expiryAlertTitle(item.name, level);

  String get message => expiryAlertMessage(daysLeft);
}

/// Alert level for [item] on [now], or null when it is not close to expiry.
ExpiryAlertLevel? alertLevelFor(FoodItem item, DateTime now) {
  final days = item.daysLeft(now);
  if (days < 0) return ExpiryAlertLevel.expired;
  if (days == 0) return ExpiryAlertLevel.today;
  if (days <= priorityThresholdDays) return ExpiryAlertLevel.threeDays;
  if (days <= expiringSoonDays) return ExpiryAlertLevel.sevenDays;
  return null;
}

/// One alert per food that is expired or expires within [expiringSoonDays],
/// most urgent first.
List<ExpiryAlert> expiryAlerts(Iterable<FoodItem> items, DateTime now) {
  final alerts = <ExpiryAlert>[];
  for (final item in items) {
    final level = alertLevelFor(item, now);
    if (level != null) {
      alerts.add(
        ExpiryAlert(item: item, level: level, daysLeft: item.daysLeft(now)),
      );
    }
  }
  alerts.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return alerts;
}

/// Foods that are not expired yet but expire within [expiringSoonDays],
/// sorted by expiry date.
List<FoodItem> expiringSoon(Iterable<FoodItem> items, DateTime now) {
  final result = items.where((item) {
    final days = item.daysLeft(now);
    return days >= 0 && days <= expiringSoonDays;
  }).toList();
  result.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  return result;
}

/// Moments at which a phone notification should be sent for [item]: 9:00 on
/// the days listed in [expiryAlertDays]. Moments already in the past are
/// skipped.
List<DateTime> alertMomentsFor(FoodItem item, DateTime now) {
  final moments = <DateTime>[];
  for (final days in expiryAlertDays) {
    final moment = DateTime(
      item.expiryDate.year,
      item.expiryDate.month,
      item.expiryDate.day - days,
      expiryAlertHour,
    );
    if (moment.isAfter(now)) {
      moments.add(moment);
    }
  }
  return moments;
}

String expiryAlertTitle(String foodName, ExpiryAlertLevel level) {
  switch (level) {
    case ExpiryAlertLevel.expired:
      return '$foodName has expired';
    case ExpiryAlertLevel.today:
      return '$foodName expires today';
    case ExpiryAlertLevel.threeDays:
      return '$foodName expires in 3 days or less';
    case ExpiryAlertLevel.sevenDays:
      return '$foodName expires this week';
  }
}

String expiryAlertMessage(int daysLeft) {
  if (daysLeft < 0) {
    final ago = -daysLeft;
    return 'Expired $ago ${ago == 1 ? 'day' : 'days'} ago · '
        'check it before eating, or add it to your shopping list.';
  }
  if (daysLeft == 0) {
    return 'Eat it today, or donate it if you can\'t.';
  }
  final days = daysLeft == 1 ? '1 day' : '$daysLeft days';
  return '$days left · plan a meal with it or donate it.';
}

Color alertLevelColor(ExpiryAlertLevel level) {
  switch (level) {
    case ExpiryAlertLevel.expired:
      return const Color(0xFFC62828);
    case ExpiryAlertLevel.today:
      return const Color(0xFFE65100);
    case ExpiryAlertLevel.threeDays:
      return const Color(0xFFF9A825);
    case ExpiryAlertLevel.sevenDays:
      return const Color(0xFF2E7D32);
  }
}

Color alertLevelBackground(ExpiryAlertLevel level) {
  switch (level) {
    case ExpiryAlertLevel.expired:
      return const Color(0xFFFFEBEE);
    case ExpiryAlertLevel.today:
      return const Color(0xFFFFF3E0);
    case ExpiryAlertLevel.threeDays:
      return const Color(0xFFFFF8E1);
    case ExpiryAlertLevel.sevenDays:
      return const Color(0xFFE8F5E9);
  }
}
