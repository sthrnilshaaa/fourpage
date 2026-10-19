import 'package:aread/src/data/repositories/usage_repository.dart';
import 'package:aread/src/presentation/utils/reading_insights.dart';
import 'package:flutter_test/flutter_test.dart';

UsageSummary summary({
  int today = 0,
  int total = 0,
  int? wpm,
  int streak = 0,
  int avgPerDay = 0,
  List<BookUsage> books = const [],
}) =>
    UsageSummary(
      readingToday: today,
      readingThisWeek: total,
      readingTotal: total,
      appToday: 0,
      appTotal: 0,
      wordsPerMinute: wpm,
      streakDays: streak,
      averagePerReadingDay: avgPerDay,
      books: books,
    );

void main() {
  test('no history suggests starting', () {
    expect(readingInsights(summary(), const []).single.kind, InsightKind.startReading);
  });

  test('continue + time left uses the reader\'s own speed', () {
    final s = summary(total: 3600, wpm: 250, books: [BookUsage('a', 3600, 3, DateTime(2026, 10, 17))]);
    final insights = readingInsights(s, const [BookProgressInfo('a', 'Stoner', 0.6, 90000)]);
    expect(insights[0].kind, InsightKind.continueBook);
    expect(insights[0].value, 60);
    expect(insights[1].kind, InsightKind.timeLeft);
    expect(insights[1].value, 144); // 40% of 90k words at 250 wpm
  });

  test('finished books are not suggested to continue', () {
    final s = summary(total: 600, books: [BookUsage('a', 600, 1, DateTime(2026, 10, 17))]);
    final insights = readingInsights(s, const [BookProgressInfo('a', 'Done', 0.99, 1000)]);
    expect(insights.where((i) => i.kind == InsightKind.continueBook), isEmpty);
  });

  test('streak and below-average nudges', () {
    final s = summary(today: 60, total: 36000, streak: 4, avgPerDay: 1800);
    final kinds = readingInsights(s, const []).map((i) => i.kind);
    expect(kinds, containsAll([InsightKind.streak, InsightKind.belowAverageToday]));
  });

  test('many open books suggests finishing one', () {
    final s = summary(total: 100);
    final books = [for (var i = 0; i < 4; i++) BookProgressInfo('b$i', 'B$i', 0.3, 0)];
    expect(readingInsights(s, books).map((i) => i.kind), contains(InsightKind.finishOne));
  });
}
