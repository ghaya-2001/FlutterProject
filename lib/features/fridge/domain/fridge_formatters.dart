import 'package:flutter/material.dart';

import 'food_item.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// e.g. "24 Oct 2026".
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// e.g. 2 -> "2", 0.5 -> "0.5", 1.25 -> "1.25".
String formatQuantity(double quantity) {
  if (quantity == quantity.roundToDouble()) {
    return quantity.toInt().toString();
  }
  return quantity
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String quantityLabel(FoodItem item) =>
    '${formatQuantity(item.quantity)} ${item.unit}';

/// Short remaining time label, e.g. "Today", "2 days left", "Expired 1 day ago".
String daysLeftLabel(FoodItem item, DateTime now) {
  final days = item.daysLeft(now);
  if (days < 0) {
    final ago = -days;
    return 'Expired $ago ${ago == 1 ? 'day' : 'days'} ago';
  }
  if (days == 0) return 'Today';
  if (days == 1) return '1 day left';
  if (days < 14) return '$days days left';
  final weeks = days ~/ 7;
  return '$weeks weeks left';
}

Color statusColor(ExpiryStatus status) {
  switch (status) {
    case ExpiryStatus.expired:
      return const Color(0xFFC62828);
    case ExpiryStatus.today:
      return const Color(0xFFE65100);
    case ExpiryStatus.soon:
      return const Color(0xFFF9A825);
    case ExpiryStatus.fresh:
      return const Color(0xFF2E7D32);
  }
}

Color statusBackground(ExpiryStatus status) {
  switch (status) {
    case ExpiryStatus.expired:
      return const Color(0xFFFFEBEE);
    case ExpiryStatus.today:
      return const Color(0xFFFFF3E0);
    case ExpiryStatus.soon:
      return const Color(0xFFFFF8E1);
    case ExpiryStatus.fresh:
      return const Color(0xFFE8F5E9);
  }
}

String statusTitle(ExpiryStatus status) {
  switch (status) {
    case ExpiryStatus.expired:
      return 'Expired';
    case ExpiryStatus.today:
      return 'Expires today';
    case ExpiryStatus.soon:
      return 'Eat soon';
    case ExpiryStatus.fresh:
      return 'Fresh';
  }
}
