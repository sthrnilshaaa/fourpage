/// Turns usage history into short, honest suggestions (no made-up numbers:
/// every suggestion is derived from the reader's own data).
library;

import '../../data/repositories/usage_repository.dart';

enum InsightKind { continueBook, timeLeft, streak, belowAverageToday, finishOne, startReading }

class Insight {
  final InsightKind kind;
  final String? bookTitle;
  final int? value; // percent, minutes, days - depends on kind
  const Insight(this.kind, {this.bookTitle, this.value});
}

class BookProgressInfo {
  final String publicationId;
  final String title;
  final double progress; // 0..1
  final int wordCount; // 0 if unknown (e.g. PDF)
  const BookProgressInfo(this.publicationId, this.title, this.progress, this.wordCount);
}

List<Insight> readingInsights(UsageSummary summary, List<BookProgressInfo> books) {
  final insights = <Insight>[];
  if (summary.readingTotal == 0) {
    return [const Insight(InsightKind.startReading)];
  }

  // Most recently read unfinished book.
  final byId = {for (final b in books) b.publicationId: b};
  final current = summary.books
      .map((u) => byId[u.publicationId])
      .whereType<BookProgressInfo>()
      .where((b) => b.progress > 0.01 && b.progress < 0.97)
      .firstOrNull;
  if (current != null) {
    insights.add(Insight(InsightKind.continueBook, bookTitle: current.title, value: (current.progress * 100).round()));
    final wpm = summary.wordsPerMinute;
    if (wpm != null && wpm > 0 && current.wordCount > 0) {
      final minutesLeft = ((1 - current.progress) * current.wordCount / wpm).round();
      if (minutesLeft > 0) insights.add(Insight(InsightKind.timeLeft, bookTitle: current.title, value: minutesLeft));
    }
  }

  if (summary.streakDays >= 2) insights.add(Insight(InsightKind.streak, value: summary.streakDays));

  final avgMinutes = summary.averagePerReadingDay ~/ 60;
  if (avgMinutes >= 5 && summary.readingToday < summary.averagePerReadingDay ~/ 2) {
    insights.add(Insight(InsightKind.belowAverageToday, value: avgMinutes));
  }

  final started = books.where((b) => b.progress > 0.01 && b.progress < 0.97).length;
  if (started >= 3) insights.add(Insight(InsightKind.finishOne, value: started));

  return insights.take(4).toList();
}
