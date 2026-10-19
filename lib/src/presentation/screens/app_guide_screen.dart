import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Settings › (i): every feature in the app and how to reach it.
class AppGuideScreen extends StatelessWidget {
  const AppGuideScreen({super.key});

  static List<(IconData, String, List<String>)> get _sections => [
        (Icons.file_download_outlined, l10n.guideAddingBooks, [
          l10n.guideImportFiles,
          l10n.guideScanFolder,
          l10n.guideFolderAccess,
        ]),
        (Icons.home_outlined, l10n.guideHomeTitle, [
          l10n.guideRecent,
          l10n.guideSearchBooks,
        ]),
        (Icons.local_library_outlined, l10n.guideLibraryTitle, [
          l10n.guideLibraryTabs,
          l10n.guideSort,
          l10n.guideFolders,
        ]),
        (Icons.shelves, l10n.guideShelvesTitle, [
          l10n.guideNewShelf,
          l10n.guideDragBook,
          l10n.guideShelfMenu,
          l10n.guideShelfOpen,
          l10n.guideLongPressList,
          l10n.guideReorderShelves,
        ]),
        (Icons.menu_book_outlined, l10n.guideReaderTitle, [
          l10n.guideTapControls,
          l10n.guideTurnPages,
          l10n.guideScrolledMode,
          l10n.guideZoomStrip,
          l10n.guideScrubber,
          l10n.guideCustomize,
          l10n.guideBookmark,
          l10n.guideSearchInBook,
        ]),
        (Icons.format_quote_outlined, l10n.guideSelectionTitle, [
          l10n.guideSelectText,
          l10n.guideSelectionMenu,
          l10n.guideTapHighlight,
          l10n.guideSavedTab,
        ]),
        (Icons.picture_as_pdf_outlined, l10n.guidePdfTitle, [l10n.guidePdf]),
        (Icons.tune_rounded, l10n.guideSettingsTitle, [
          l10n.guideAppearance,
          l10n.guideReadingDefaults,
          l10n.guideDynamicBackground,
          l10n.guideReminders,
          l10n.guideHaptics,
          l10n.guideLibrarySettings,
        ]),
        (Icons.favorite_outline_rounded, l10n.guideUpdatesTitle, [
          l10n.guideUpdates,
          l10n.guideSupport,
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return Scaffold(
      backgroundColor: AppColors.figmaBackground,
      appBar: AppBar(
        backgroundColor: AppColors.figmaBackground,
        foregroundColor: AppColors.fg,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.appGuide, style: GoogleFonts.sora(fontSize: 18, color: AppColors.fg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(l10n.appGuideIntro, style: GoogleFonts.sora(fontSize: 13, height: 1.45, color: AppColors.fgSubtle)),
          const SizedBox(height: 16),
          for (final (i, (icon, title, items)) in sections.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.figmaSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.fgHairline),
                ),
                child: Theme(
                  // No divider lines from ExpansionTile.
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: i == 0,
                    shape: const RoundedRectangleBorder(),
                    collapsedShape: const RoundedRectangleBorder(),
                    iconColor: AppColors.accentLime,
                    collapsedIconColor: AppColors.fgMuted,
                    leading: Icon(icon, color: AppColors.accentLime),
                    title: Text(title, style: GoogleFonts.sora(fontSize: 15, color: AppColors.fg, fontWeight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 7, right: 10),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(color: AppColors.accentLime, shape: BoxShape.circle),
                                ),
                              ),
                              Expanded(
                                child: Text(item, style: GoogleFonts.sora(fontSize: 13, height: 1.5, color: AppColors.fgMuted)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
