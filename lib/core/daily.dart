/// 7-day daily reward calendar. Pure Dart.
///
/// Streak: claiming on consecutive days grows 1..7, then wraps. Missing a
/// day resets to 1. Claiming twice the same day is rejected.
library;

class DailyReward {
  final int day; // 1..7
  final String kind; // 'coins' | 'treats'
  final double amount;

  const DailyReward(this.day, this.kind, this.amount);
}

const List<DailyReward> kWeekRewards = [
  DailyReward(1, 'coins', 500),
  DailyReward(2, 'treats', 3),
  DailyReward(3, 'coins', 2500),
  DailyReward(4, 'treats', 6),
  DailyReward(5, 'coins', 12000),
  DailyReward(6, 'treats', 10),
  DailyReward(7, 'treats', 30),
];

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class DailyState {
  String? lastClaim; // yyyy-MM-dd
  int streak; // 0 = never claimed

  DailyState({this.lastClaim, this.streak = 0});
}

/// True when a reward can be claimed right now.
bool dailyClaimable(DailyState s, DateTime now) =>
    s.lastClaim != dateKey(now);

/// Claims today's reward. Returns the reward, or null when already claimed.
DailyReward? claimDaily(DailyState s, DateTime now) {
  final today = dateKey(now);
  if (s.lastClaim == today) return null;
  final yesterday = dateKey(now.subtract(const Duration(days: 1)));
  s.streak = (s.lastClaim == yesterday) ? (s.streak % 7) + 1 : 1;
  s.lastClaim = today;
  return kWeekRewards[s.streak - 1];
}

/// The reward that *would* be claimed today (for the dialog preview).
DailyReward previewDaily(DailyState s, DateTime now) {
  final yesterday = dateKey(now.subtract(const Duration(days: 1)));
  final streak = (s.lastClaim == yesterday) ? (s.streak % 7) + 1 : 1;
  return kWeekRewards[streak - 1];
}
