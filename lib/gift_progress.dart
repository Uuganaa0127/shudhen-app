class GiftProgress {
  final Set<String> dates;
  final int target;
  final DateTime now;
  GiftProgress(this.dates, this.target, this.now);
  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int get streak {
    var d = DateTime(now.year, now.month, now.day);
    if (!dates.contains(key(d))) d = DateTime(d.year, d.month, d.day - 1);
    int n = 0;
    while (dates.contains(key(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  int get remaining => streak >= target ? 0 : target - streak;
}
