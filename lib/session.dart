class BrushingSession {
  final List<Duration?> times = List.filled(4, null);
  final List<Stopwatch> _watches = List.generate(4, (_) => Stopwatch());
  int section = 0;
  Duration elapsedAt(int index) => times[index] ?? _watches[index].elapsed;
  Stopwatch get watch => _watches[section];
  bool get complete => times.every((time) => time != null);
  int get completedCount => times.where((time) => time != null).length;
  Duration get total =>
      times.fold(Duration.zero, (a, b) => a + (b ?? Duration.zero));
  void start() {
    if (!complete && times[section] == null) watch.start();
  }

  void pause() => watch.stop();
  bool select(int index) {
    if (index < 0 || index > 3 || complete || times[index] != null) {
      return false;
    }
    if (index == section) return true;
    watch.stop();
    section = index;
    return true;
  }

  bool finishSection() {
    if (complete || watch.elapsed < const Duration(seconds: 1)) return false;
    times[section] = watch.elapsed;
    watch
      ..stop()
      ..reset();
    if (!complete) section = times.indexWhere((time) => time == null);
    return true;
  }
}
