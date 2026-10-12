/// Compact number + duration formatting for the UI. Pure Dart.
library;

/// 999 -> "999", 1500 -> "1.5K", 2_500_000 -> "2.5M", 1.2e9 -> "1.2B".
String formatCompact(double n) {
  if (n < 1000) {
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
  }
  const units = ['', 'K', 'M', 'B', 'T', 'Q'];
  var value = n;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final str = value >= 100
      ? value.toStringAsFixed(0)
      : value >= 10
          ? value.toStringAsFixed(1)
          : value.toStringAsFixed(2);
  // trim trailing zeros: "1.50" -> "1.5", "2.00" -> "2"
  final trimmed = str.contains('.')
      ? str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : str;
  return '$trimmed${units[unit]}';
}

/// Duration -> "2h 5m", "45m 10s", "30s".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
