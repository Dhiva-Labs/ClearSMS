const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _time(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'am' : 'pm';
  return '$h12:${d.minute.toString().padLeft(2, '0')} $ampm';
}

/// Compact stamp for the conversation list: time today, weekday this week,
/// date otherwise.
String listTimestamp(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return _time(d);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return _weekdays[d.weekday - 1];
  if (d.year == now.year) return '${d.day} ${_months[d.month - 1]}';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// Full stamp for message bubbles.
String bubbleTimestamp(DateTime d) => _time(d);

/// Section header inside a thread.
String dayHeader(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final year = d.year == now.year ? '' : ' ${d.year}';
  return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}$year';
}
