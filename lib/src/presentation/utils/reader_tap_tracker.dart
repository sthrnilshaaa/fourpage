/// Classifies the WebView's normalized touch callbacks as a short tap.
///
/// A tap must begin and end within a small part of the viewport and finish
/// promptly. Requiring one matching down/up pair also ignores duplicate up
/// callbacks from nested WebView documents.
class ReaderTapTracker {
  ReaderTapTracker({
    this.maxDistance = 0.02,
    this.maxDuration = const Duration(milliseconds: 450),
  });

  final double maxDistance;
  final Duration maxDuration;

  double? _startX;
  double? _startY;
  DateTime? _startedAt;

  void start(double x, double y, {DateTime? at}) {
    _startX = x;
    _startY = y;
    _startedAt = at ?? DateTime.now();
  }

  bool finish(double x, double y, {DateTime? at}) {
    final startX = _startX;
    final startY = _startY;
    final startedAt = _startedAt;
    reset();
    if (startX == null || startY == null || startedAt == null) return false;

    final elapsed = (at ?? DateTime.now()).difference(startedAt);
    final distance = (x - startX).abs() + (y - startY).abs();
    return elapsed >= Duration.zero &&
        elapsed <= maxDuration &&
        distance < maxDistance;
  }

  void reset() {
    _startX = null;
    _startY = null;
    _startedAt = null;
  }
}
