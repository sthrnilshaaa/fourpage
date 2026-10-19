import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../state/app_preferences.dart';
import '../theme/app_colors.dart';
import 'window_class.dart';

/// Whether the reader shows its side panes (expanded windows only).
bool readerUsesPanes(BuildContext context) => context.windowClass.isExpanded;

/// Reader frame on expanded windows: contents pane | book | settings pane,
/// with a toolbar above and a progress bar below. On smaller windows, or in
/// focus mode, only the book is shown (callers keep their overlay bars).
///
/// The book keeps the same element across every mode, so its scroll and
/// reading position survive resizes and focus toggles.
class ReaderPaneLayout extends StatefulWidget {
  final Widget book;
  final Widget? contents;
  final Widget? settings;
  final Widget? topBar;
  final Widget? bottomBar;
  final bool focusMode;
  final bool contentsOpen;
  final bool settingsOpen;
  final Color background;

  static const contentsWidth = 300.0;
  static const settingsWidth = 320.0;

  const ReaderPaneLayout({
    super.key,
    required this.book,
    this.contents,
    this.settings,
    this.topBar,
    this.bottomBar,
    required this.focusMode,
    required this.contentsOpen,
    required this.settingsOpen,
    required this.background,
  });

  @override
  State<ReaderPaneLayout> createState() => _ReaderPaneLayoutState();
}

class _ReaderPaneLayoutState extends State<ReaderPaneLayout> {
  final _bookKey = GlobalKey();

  Widget _pane(Widget child, double width, {required bool left}) {
    final side = BorderSide(color: AppColors.dividerSubtle);
    return Container(
      width: width,
      color: AppColors.sheetSurface,
      // Painted on top so the hairline doesn't eat into the pane's width.
      foregroundDecoration: BoxDecoration(border: left ? Border(right: side) : Border(left: side)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final chrome = readerUsesPanes(context) && !w.focusMode;
    final book = KeyedSubtree(key: _bookKey, child: w.book);
    return ColoredBox(
      color: w.background,
      child: Column(
        children: [
          if (chrome && w.topBar != null) w.topBar!,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chrome && w.contentsOpen && w.contents != null)
                  _pane(w.contents!, ReaderPaneLayout.contentsWidth, left: true),
                Expanded(child: book),
                if (chrome && w.settingsOpen && w.settings != null)
                  _pane(w.settings!, ReaderPaneLayout.settingsWidth, left: false),
              ],
            ),
          ),
          if (chrome && w.bottomBar != null) w.bottomBar!,
        ],
      ),
    );
  }
}

/// Toolbar buttons that show/hide the two reader panes (remembered).
class ReaderPaneToggles extends StatelessWidget {
  final Color color;

  const ReaderPaneToggles({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: prefs.readerContentsPaneOpen ? l10n.hideContents : l10n.showContents,
            icon: Icon(prefs.readerContentsPaneOpen ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                color: color, size: 22),
            onPressed: () => prefs.setReaderContentsPaneOpen(!prefs.readerContentsPaneOpen),
          ),
          IconButton(
            tooltip: prefs.readerSettingsPaneOpen ? l10n.hideSettingsPane : l10n.showSettingsPane,
            icon: Icon(prefs.readerSettingsPaneOpen ? Icons.tune_rounded : Icons.tune_outlined, color: color, size: 22),
            onPressed: () => prefs.setReaderSettingsPaneOpen(!prefs.readerSettingsPaneOpen),
          ),
        ],
      ),
    );
  }
}
