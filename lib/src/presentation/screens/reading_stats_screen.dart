import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../../data/repositories/usage_repository.dart';
import '../state/library_controller.dart';
import '../state/usage_tracker.dart';
import '../theme/app_colors.dart';
import '../utils/reading_insights.dart';

/// Settings → Reading stats: reading and screen time, speed, streak, per-book
/// time and suggestions - all from this device's own history.
class ReadingStatsScreen extends StatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  State<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends State<ReadingStatsScreen> {
  late Future<UsageSummary> _summary = UsageTracker.instance.summary();

  static String duration(int seconds) {
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
    if (h > 0) return l10n.durationHoursMinutes(h, m);
    if (m > 0) return l10n.durationMinutes(m);
    return seconds > 0 ? l10n.durationUnderAMinute : l10n.durationMinutes(0);
  }

  String _insightText(Insight i) => switch (i.kind) {
        InsightKind.startReading => l10n.insightStartReading,
        InsightKind.continueBook => l10n.insightContinueBook(i.bookTitle ?? '', i.value ?? 0),
        InsightKind.timeLeft => l10n.insightTimeLeft(i.bookTitle ?? '', duration((i.value ?? 0) * 60)),
        InsightKind.streak => l10n.insightStreak(i.value ?? 0),
        InsightKind.belowAverageToday => l10n.insightBelowAverage(i.value ?? 0),
        InsightKind.finishOne => l10n.insightFinishOne(i.value ?? 0),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.figmaBackground,
      appBar: AppBar(
        backgroundColor: AppColors.figmaBackground,
        foregroundColor: AppColors.fg,
        title: Text(l10n.readingStats, style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: AppColors.fg)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _summary = UsageTracker.instance.summary()),
        child: FutureBuilder<UsageSummary>(
          future: _summary,
          builder: (context, snap) {
            if (!snap.hasData) return Center(child: CircularProgressIndicator(color: AppColors.accentLime));
            final s = snap.data!;
            final books = LibraryController.instance.books;
            final byId = {for (final b in books) b.publication.id: b};
            final insights = readingInsights(s, [
              for (final b in books)
                BookProgressInfo(b.publication.id, b.publication.metadata.title, b.progress,
                    b.session.state.publication?.derivedStatistics.wordCount ?? 0),
            ]);
            final finished = books.where((b) => b.progress >= 0.97).length;
            final started = books.where((b) => b.progress > 0.01).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _Grid(children: [
                  _Stat(l10n.statToday, duration(s.readingToday)),
                  _Stat(l10n.statThisWeek, duration(s.readingThisWeek)),
                  _Stat(l10n.statTotalReading, duration(s.readingTotal)),
                  _Stat(l10n.statStreak, l10n.daysCount(s.streakDays)),
                  _Stat(l10n.statSpeed, s.wordsPerMinute == null ? '—' : l10n.wordsPerMinute(s.wordsPerMinute!)),
                  _Stat(l10n.statBooks, l10n.booksStartedFinished(started, finished)),
                  _Stat(l10n.statScreenTimeToday, duration(s.appToday)),
                  _Stat(l10n.statScreenTimeTotal, duration(s.appTotal)),
                ]),
                const SizedBox(height: 24),
                _Header(l10n.suggestions),
                for (final insight in insights)
                  _Card(
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentLime, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_insightText(insight),
                              style: GoogleFonts.sora(fontSize: 14, height: 1.4, color: AppColors.fg)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                _Header(l10n.timePerBook),
                if (s.books.isEmpty)
                  Text(l10n.noReadingYet, style: GoogleFonts.sora(fontSize: 13, color: AppColors.fgSubtle))
                else
                  for (final usage in s.books)
                    _Card(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(byId[usage.publicationId]?.publication.metadata.title ?? l10n.removedBook,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sora(fontSize: 14, color: AppColors.fg)),
                                const SizedBox(height: 4),
                                Text(l10n.sessionsCount(usage.sessions),
                                    style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgSubtle)),
                              ],
                            ),
                          ),
                          Text(duration(usage.seconds), style: GoogleFonts.sora(fontSize: 14, color: AppColors.accentLime)),
                        ],
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.9,
        children: children,
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => _Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgSubtle)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.fg)),
            ),
          ],
        ),
      );
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.sora(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: AppColors.accentLime)),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  const _Card({required this.child, this.margin = const EdgeInsets.only(bottom: 10)});

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.figmaSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fgHairline),
        ),
        child: child,
      );
}
