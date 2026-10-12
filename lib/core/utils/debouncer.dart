import 'dart:async';

/// Delays callback execution until the caller stops invoking [run] for
/// [duration]. Useful for search-as-you-type to avoid firing a new query
/// on every keystroke.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 400)});
  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
