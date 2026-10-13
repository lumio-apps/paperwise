/// Small text helpers for sizes, dates and counts.
library;

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today, 14:05", "Yesterday" or "10 Oct".
String formatDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = startOfToday.difference(day).inDays;
  String two(int v) => v.toString().padLeft(2, '0');
  if (diff == 0) return 'Today, ${two(date.hour)}:${two(date.minute)}';
  if (diff == 1) return 'Yesterday';
  final base = '${date.day} ${_months[date.month - 1]}';
  return date.year == today.year ? base : '$base ${date.year}';
}

/// "1 page" or "12 pages".
String pageCountLabel(int count) => count == 1 ? '1 page' : '$count pages';

/// "1 file" or "3 files".
String fileCountLabel(int count) => count == 1 ? '1 file' : '$count files';
