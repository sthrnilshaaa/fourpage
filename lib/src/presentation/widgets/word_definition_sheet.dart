import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../../data/dictionary/dictionary_service.dart';
import '../theme/app_colors.dart';

/// Bottom sheet that looks up the selected word and shows its meanings.
class WordDefinitionSheet extends StatefulWidget {
  final String word;

  /// Opens in-book search for the word (offered when there's no definition).
  final VoidCallback? onSearchInBook;

  const WordDefinitionSheet({super.key, required this.word, this.onSearchInBook});

  @override
  State<WordDefinitionSheet> createState() => _WordDefinitionSheetState();
}

class _WordDefinitionSheetState extends State<WordDefinitionSheet> {
  late Future<WordDefinition> _lookup;

  @override
  void initState() {
    super.initState();
    _lookup = DictionaryService.instance.define(widget.word);
  }

  void _retry() => setState(() => _lookup = DictionaryService.instance.define(widget.word));

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.figmaSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 11),
              Center(
                child: Container(
                  width: 75,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.figmaTextGhost,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Flexible(
                child: FutureBuilder<WordDefinition>(
                  future: _lookup,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return _header(
                        widget.word,
                        null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentLime),
                            ),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      final offline = snapshot.error is DictionaryException &&
                          (snapshot.error as DictionaryException).failure == DictionaryFailure.offline;
                      return _header(widget.word, null, child: _failure(offline));
                    }
                    return _definition(snapshot.data!);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String word, String? phonetic, {required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(word, style: GoogleFonts.sora(fontSize: 24, color: AppColors.fg, fontWeight: FontWeight.w600)),
          if (phonetic != null) ...[
            const SizedBox(height: 4),
            Text(phonetic, style: GoogleFonts.sora(fontSize: 14, color: AppColors.figmaTextFaint)),
          ],
          child,
        ],
      ),
    );
  }

  Widget _failure(bool offline) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offline ? l10n.dictionaryOffline : l10n.noDefinitionFound,
            style: GoogleFonts.sora(fontSize: 14, height: 1.5, color: AppColors.fgMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (offline) TextButton(onPressed: _retry, child: Text(l10n.tryAgain)),
              if (widget.onSearchInBook != null)
                TextButton(onPressed: widget.onSearchInBook, child: Text(l10n.searchInBook)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _definition(WordDefinition def) {
    return _header(
      def.word,
      def.phonetic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final sense in def.senses) ...[
            const SizedBox(height: 18),
            if (sense.partOfSpeech.isNotEmpty)
              Text(
                sense.partOfSpeech,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.accentLime,
                ),
              ),
            for (final (i, d) in sense.definitions.take(4).indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${i + 1}. $d',
                  style: GoogleFonts.sora(fontSize: 15, height: 1.5, color: AppColors.fg),
                ),
              ),
            if (sense.examples.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '“${sense.examples.first}”',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.figmaTextFaint,
                  ),
                ),
              ),
            if (sense.synonyms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${l10n.synonyms}: ${sense.synonyms.take(6).join(', ')}',
                  style: GoogleFonts.sora(fontSize: 13, height: 1.5, color: AppColors.fgMuted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Compact definition card shown over the page as soon as a single word is
/// selected (like Play Books). Scrolls inside; [onExpand] opens the full
/// sheet.
class WordDefinitionCard extends StatelessWidget {
  final String word;

  /// The lookup, held by the caller so rebuilds don't start a new request.
  final Future<WordDefinition> lookup;
  final VoidCallback? onExpand;

  const WordDefinitionCard({super.key, required this.word, required this.lookup, this.onExpand});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.32;
    return Material(
      color: AppColors.figmaSurface,
      elevation: 8,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, minWidth: double.infinity),
        child: FutureBuilder<WordDefinition>(
          future: lookup,
          builder: (context, snapshot) {
            final def = snapshot.data;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              def?.word ?? word,
                              style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.fg),
                            ),
                            if (def?.phonetic != null)
                              Text(
                                def!.phonetic!,
                                style: GoogleFonts.sora(fontSize: 12, color: AppColors.figmaTextFaint),
                              ),
                          ],
                        ),
                      ),
                      if (onExpand != null && def != null)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onExpand,
                          icon: Icon(Icons.open_in_full_rounded, size: 18, color: AppColors.fgSubtle),
                        ),
                    ],
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentLime),
                      ),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: Text(
                        snapshot.error is DictionaryException &&
                                (snapshot.error as DictionaryException).failure == DictionaryFailure.offline
                            ? l10n.dictionaryOffline
                            : l10n.noDefinitionFound,
                        style: GoogleFonts.sora(fontSize: 13, height: 1.45, color: AppColors.fgMuted),
                      ),
                    )
                  else
                    for (final sense in def!.senses.take(3)) ...[
                      const SizedBox(height: 10),
                      if (sense.partOfSpeech.isNotEmpty)
                        Text(
                          sense.partOfSpeech,
                          style: GoogleFonts.sora(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.accentLime),
                        ),
                      for (final (i, d) in sense.definitions.take(3).indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 8),
                          child: Text(
                            '${i + 1}: $d',
                            style: GoogleFonts.sora(fontSize: 13, height: 1.45, color: AppColors.fg),
                          ),
                        ),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
