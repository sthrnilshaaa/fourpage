import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../aread.dart';
import '../theme/app_colors.dart';

class ReaderSearchSheet extends StatefulWidget {
  final ReadingSession session;
  final ValueChanged<Locator> onNavigate;

  const ReaderSearchSheet({
    super.key,
    required this.session,
    required this.onNavigate,
  });

  @override
  State<ReaderSearchSheet> createState() => _ReaderSearchSheetState();
}

class _ReaderSearchSheetState extends State<ReaderSearchSheet> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<SearchMatch> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.session.state.searchResults;
  }

  void _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    await widget.session.dispatchCommand(ExecuteSearchCommand(query));
    if (mounted) {
      setState(() {
        _isSearching = false;
        _results = widget.session.state.searchResults;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: UIConstants.dragHandleWidth,
                height: UIConstants.dragHandleHeight,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.fg.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: GoogleFonts.sora(fontSize: 16, color: AppColors.fg),
                      onChanged: (val) {
                        if (val.length >= 3) {
                          _runSearch(val);
                        }
                      },
                      onSubmitted: _runSearch,
                      decoration: InputDecoration(
                        hintText: l10n.searchInBook,
                        hintStyle: GoogleFonts.sora(fontSize: 16, color: AppColors.textFaint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.fgMuted, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = []);
                      },
                    ),
                ],
              ),
            ),

            Divider(color: AppColors.dividerSubtle, height: 1, thickness: 1),

            // Result count label
            if (_searchController.text.isNotEmpty && !_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  l10n.searchResultsCount(_results.length),
                  style: GoogleFonts.sora(fontSize: 13, color: AppColors.textFaint),
                ),
              ),

            // Search Content
            if (_isSearching)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accentLime),
                ),
              )
            else if (_results.isEmpty && _searchController.text.isNotEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.noResultsFor(_searchController.text),
                    style: GoogleFonts.sora(color: AppColors.textFaint),
                  ),
                ),
              )
            else if (_results.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.typeAWordOrSentenceTo,
                    style: GoogleFonts.sora(color: AppColors.textFaint),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final match = _results[index];
                    final chapterNum = match.spineIndex + 1;

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onNavigate(match.locator);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.chapterN(chapterNum),
                              style: GoogleFonts.ptSerif(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.fg,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: match.snippetBefore,
                                    style: GoogleFonts.ptSerif(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: AppColors.fgMuted,
                                    ),
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E6091),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        match.matchedText,
                                        style: GoogleFonts.ptSerif(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.fg,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    text: match.snippetAfter,
                                    style: GoogleFonts.ptSerif(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: AppColors.fgMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
