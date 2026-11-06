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

/// The `yyyy-MM-dd` key workouts are stored under in Firestore.
String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// e.g. "Oct 28"
String formatShortDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}';

/// e.g. "Oct 28, 2026"
String formatLongDate(DateTime date) =>
    '${formatShortDate(date)}, ${date.year}';
