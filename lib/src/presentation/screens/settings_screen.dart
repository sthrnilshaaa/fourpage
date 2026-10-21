import 'package:flutter/foundation.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/reader_preferences.dart';
import '../state/app_preferences.dart';
import '../state/library_controller.dart';
import '../layout/browse_insets.dart';
import '../layout/master_detail.dart';
import '../layout/window_class.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_controller.dart';
import '../platform/app_haptics.dart';
import '../platform/app_updater.dart';
import '../platform/folder_tree.dart';
import '../platform/system_bridge.dart';
import '../state/shelves.dart';
import '../widgets/shelf_dialogs.dart';
import '../widgets/update_dialog.dart';
import 'app_guide_screen.dart';
import '../state/usage_tracker.dart';
import '../utils/book_import_actions.dart';
import '../utils/library_sort.dart';
import 'reading_stats_screen.dart';
import '../utils/folder_scanner.dart';
import '../utils/storage_access.dart';

/// App settings: appearance, reading defaults for new books, library &
/// storage, about. Everything here is real and persisted (app_settings).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool? _folderAccess;

  /// Medium/expanded: the section shown in the detail pane, and the pane's
  /// own navigator so sub-screens (Reading stats) open inside it.
  int _section = 0;
  final _detailNav = GlobalKey<NavigatorState>();

  List<(String, Widget Function())> get _sections => [
        (l10n.appearance, _appearanceSection),
        (l10n.reading, _readingSection),
        (l10n.remindersAndNotifications, _remindersSection),
        (l10n.haptics, _hapticsSection),
        (l10n.libraryStorage, _librarySection),
        (l10n.shelves, _shelvesSection),
        (l10n.about, _aboutSection),
        (l10n.appGuide, () => const AppGuideScreen()),
      ];

  void _push(Widget screen) {
    final nav = context.windowClass.isCompact ? Navigator.of(context) : _detailNav.currentState;
    nav?.push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildMasterDetail() {
    final sections = _sections;
    final index = _section.clamp(0, sections.length - 1);
    final isGuide = index == sections.length - 1;
    return Scaffold(
      backgroundColor: AppColors.figmaBackground,
      body: MasterDetail(
        header: Text(l10n.settings, style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.fg)),
        titles: [for (final s in sections) s.$1],
        selected: index,
        onSelected: (i) => setState(() => _section = i),
        detail: Navigator(
          key: _detailNav,
          pages: [
            MaterialPage(
              key: ValueKey('settings-section-$index'),
              child: isGuide
                  ? sections[index].$2()
                  : Scaffold(
                      backgroundColor: AppColors.figmaBackground,
                      body: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        children: [sections[index].$2()],
                      ),
                    ),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );
  }

  static const _lineHeights = [1.2, 1.35, 1.5, 1.75, 2.0];
  static final _bookThemes = [
    (ReaderTheme.light, l10n.paper, Color(0xFFFFFCEF), Color(0xFF1A1A1A)),
    (ReaderTheme.sepia, l10n.sepia, Color(0xFFC2BAA5), Color(0xFF2B2620)),
    (ReaderTheme.dark, l10n.night, Color(0xFF121211), Colors.white),
    (ReaderTheme.publisher, l10n.forest, Color(0xFF121A15), Colors.white),
    (ReaderTheme.highContrast, l10n.black, Color(0xFF000000), Colors.white),
  ];

  AppBuildInfo? _build;
  bool _checkingUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAccess();
    AppUpdater.instance.info().then((info) {
      if (mounted) setState(() => _build = info);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system "All files access" screen.
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  Future<void> _refreshAccess() async {
    final granted = await StorageAccess.hasFolderAccess();
    if (mounted) setState(() => _folderAccess = granted);
  }

  ReaderPreferences get _defaults => AppPreferences.instance.readerDefaults;

  // Page-margin value while the slider is being dragged (saved on release).
  double? _paddingDrag;
  void _setDefaults(ReaderPreferences prefs) => AppPreferences.instance.setReaderDefaults(prefs);

  Future<void> _applyToAllBooks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        title: Text(l10n.applyToAllBooks, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
        content: Text(
          l10n.everyBookInYourLibraryWill,
          style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.apply)),
        ],
      ),
    );
    if (confirm != true) return;
    await LibraryController.instance.applyPreferencesToAllBooks(_defaults);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.readingSettingsAppliedToAllBooks)));
    }
  }

  static const _storeUrl = 'https://play.google.com/store/apps/details?id=com.fourpages.reader';

  Future<void> _rate() async {
    if (!await SystemBridge.openUrl('market://details?id=com.fourpages.reader') &&
        !await SystemBridge.openUrl(_storeUrl) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.storeUnavailable)));
    }
  }

  Future<void> _share() => SharePlus.instance.share(ShareParams(text: l10n.shareMessage(_storeUrl)));

  Future<void> _rescan(String folder) async {
    final lib = LibraryController.instance;
    if (lib.isScanning(folder)) return;
    if (!FolderTree.isTreeUri(folder) && !await StorageAccess.ensureFolderAccess(context)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final int count;
    try {
      count = await lib.scanAndImportFolder(folder);
    } on FolderScanPermissionException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.thisFolderCanTBeRead)));
      return;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.folderScanError('$e'))));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(count == 0 ? l10n.noNewBooksInFolder : l10n.importedBooks(count))));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppPreferences.instance, AppThemeController.instance, LibraryController.instance]),
      builder: (context, _) => !context.windowClass.isCompact ? _buildMasterDetail() : Scaffold(
        backgroundColor: AppColors.figmaBackground,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, browseBottomPadding(context, compact: 150)),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.settings,
                        style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.fg)),
                  ),
                  IconButton(
                    tooltip: l10n.appGuide,
                    icon: Icon(Icons.info_outline_rounded, color: AppColors.accentLime),
                    onPressed: () => _push(const AppGuideScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _appearanceSection(),
              _readingSection(),
              _remindersSection(),
              _hapticsSection(),
              _librarySection(),
              _shelvesSection(),
              _aboutSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- sections -------------------------------------------------------------

  Widget _appearanceSection() {
    final pref = AppThemeController.instance.preference;
    return _Section(
      title: l10n.appearance,
      children: [
        _Row(
          label: l10n.appTheme,
          below: _Segmented<AppThemePreference>(
            values: AppThemePreference.values,
            selected: pref,
            labelOf: (p) => switch (p) {
              AppThemePreference.system => l10n.system,
              AppThemePreference.light => l10n.light,
              AppThemePreference.dark => l10n.dark,
            },
            onChanged: AppThemeController.instance.setPreference,
          ),
        ),
        _Row(
          label: l10n.language,
          caption: l10n.moreLanguagesSoon,
          below: _Segmented<String>(
            values: [for (final l in AppLocalizations.supportedLocales) l.languageCode],
            selected: AppPreferences.instance.language,
            labelOf: (code) => switch (code) { 'en' => 'English', _ => code },
            onChanged: AppPreferences.instance.setLanguage,
          ),
        ),
      ],
    );
  }

  Widget _readingSection() {
    final d = _defaults;
    final lineStep = _lineHeights.indexWhere((h) => (h - d.lineHeight).abs() < 0.01);
    return _Section(
      title: l10n.reading,
      subtitle: l10n.defaultsForBooksYouHavenT,
      children: [
        _Row(
          label: l10n.bookTheme,
          below: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (theme, name, bg, fgColor) in _bookThemes)
                _ThemeSwatch(
                  name: name,
                  background: bg,
                  foreground: fgColor,
                  selected: d.theme == theme,
                  onTap: () => _setDefaults(d.copyWith(theme: theme)),
                ),
            ],
          ),
        ),
        _SwitchRow(
          label: l10n.dynamicBookBackground,
          value: AppPreferences.instance.dynamicBookBackground,
          onChanged: (v) async {
            await AppPreferences.instance.setDynamicBookBackground(v);
            if (mounted) setState(() {});
          },
        ),
        _Row(
          label: l10n.textSize2,
          trailing: _Stepper(
            value: '${d.fontSize.round()}',
            onDecrease: d.fontSize > 10 ? () => _setDefaults(d.copyWith(fontSize: d.fontSize - 1)) : null,
            onIncrease: d.fontSize < 36 ? () => _setDefaults(d.copyWith(fontSize: d.fontSize + 1)) : null,
          ),
        ),
        _Row(
          label: l10n.lineSpacing,
          trailing: _Stepper(
            value: d.lineHeight.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), ''),
            onDecrease: lineStep > 0 ? () => _setDefaults(d.copyWith(lineHeight: _lineHeights[lineStep - 1])) : null,
            onIncrease: lineStep >= 0 && lineStep < _lineHeights.length - 1
                ? () => _setDefaults(d.copyWith(lineHeight: _lineHeights[lineStep + 1]))
                : (lineStep < 0 ? () => _setDefaults(d.copyWith(lineHeight: 1.5)) : null),
          ),
        ),
        _Row(
          label: l10n.alignment,
          below: _Segmented<String>(
            values: const ['left', 'justify', 'center'],
            selected: d.textAlignment,
            labelOf: (a) => switch (a) { 'justify' => l10n.justified, 'center' => l10n.centered, _ => l10n.left },
            onChanged: (a) => _setDefaults(d.copyWith(textAlignment: a)),
          ),
        ),
        _Row(
          label: l10n.readingMode,
          below: _Segmented<ScrollMode>(
            values: const [ScrollMode.continuous, ScrollMode.paginated],
            selected: d.scrollMode,
            labelOf: (m) => m == ScrollMode.continuous ? l10n.scrollChapter : l10n.pages,
            onChanged: (m) => _setDefaults(d.copyWith(scrollMode: m)),
          ),
        ),
        _paddingRow(),
        _ActionRow(label: l10n.applyToAllBooks2, icon: Icons.done_all_rounded, onTap: _applyToAllBooks),
      ],
    );
  }

  /// One slider for both the left and right padding of the book text.
  Widget _paddingRow() {
    final value = _paddingDrag ?? AppPreferences.instance.readerPadding;
    return _Row(
      label: l10n.contentPadding,
      caption: l10n.contentPaddingCaption,
      trailing: _Value('${value.round()} px'),
      below: Row(
        children: [
          Icon(Icons.format_indent_decrease_rounded, size: 18, color: AppColors.fgSubtle),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accentLime,
                thumbColor: AppColors.accentLime,
                inactiveTrackColor: AppColors.fg.withValues(alpha: 0.12),
                overlayColor: AppColors.accentLime.withValues(alpha: 0.15),
              ),
              child: Slider(
                min: AppPreferences.minReaderPadding,
                max: AppPreferences.maxReaderPadding,
                divisions: (AppPreferences.maxReaderPadding - AppPreferences.minReaderPadding).round() ~/ 2,
                value: value.clamp(AppPreferences.minReaderPadding, AppPreferences.maxReaderPadding),
                onChanged: (v) => setState(() => _paddingDrag = v),
                onChangeEnd: (v) {
                  setState(() => _paddingDrag = null);
                  AppPreferences.instance.setReaderPadding(v);
                },
              ),
            ),
          ),
          Icon(Icons.format_indent_increase_rounded, size: 18, color: AppColors.fgSubtle),
        ],
      ),
    );
  }

  Widget _remindersSection() {
    final prefs = AppPreferences.instance;
    String soundLabel() => switch (prefs.notificationSound) {
          'default' => l10n.soundDefault,
          'silent' => l10n.soundSilent,
          _ => prefs.notificationSoundName ?? l10n.soundCustom,
        };
    final reminder = prefs.dailyReminder;
    return _Section(
      title: l10n.remindersAndNotifications,
      children: [
        _Row(
          label: l10n.breakReminder,
          caption: l10n.breakReminderCaption,
          below: _Segmented<int>(
            values: const [0, 20, 30, 45, 60],
            selected: prefs.breakMinutes,
            labelOf: (m) => m == 0 ? l10n.off : l10n.durationMinutes(m),
            onChanged: prefs.setBreakMinutes,
          ),
        ),
        if (SystemBridge.isSupported) ...[
          _Row(
            label: l10n.dailyReadingReminder,
            caption: l10n.dailyReadingReminderCaption,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reminder >= 0)
                  TextButton(
                    onPressed: _pickReminderTime,
                    child: Text(TimeOfDay(hour: reminder ~/ 60, minute: reminder % 60).format(context)),
                  ),
                Switch(
                  value: reminder >= 0,
                  activeTrackColor: AppColors.accentLime,
                  onChanged: (on) => on ? _pickReminderTime() : _setReminder(-1),
                ),
              ],
            ),
          ),
          _Row(
            label: l10n.notificationSound,
            caption: soundLabel(),
            below: _Segmented<String>(
              values: const ['default', 'silent', 'pick'],
              selected: prefs.notificationSound == 'default' || prefs.notificationSound == 'silent' ? prefs.notificationSound : 'pick',
              labelOf: (v) => switch (v) { 'default' => l10n.soundDefault, 'silent' => l10n.soundSilent, _ => l10n.soundChoose },
              onChanged: _setSound,
            ),
          ),
          _ActionRow(label: l10n.sendTestNotification, icon: Icons.notifications_active_outlined, onTap: _testNotification),
        ],
      ],
    );
  }

  Future<void> _pickReminderTime() async {
    final current = AppPreferences.instance.dailyReminder;
    final picked = await showTimePicker(
      context: context,
      initialTime: current >= 0 ? TimeOfDay(hour: current ~/ 60, minute: current % 60) : const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked == null) return;
    if (!await SystemBridge.ensureNotificationPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.notificationsBlocked)));
      return;
    }
    await _setReminder(picked.hour * 60 + picked.minute);
  }

  Future<void> _setReminder(int minutes) async {
    await AppPreferences.instance.setDailyReminder(minutes);
    await UsageTracker.instance.applyReminderSettings();
  }

  Future<void> _setSound(String value) async {
    final prefs = AppPreferences.instance;
    if (value == 'pick') {
      final picked = await SystemBridge.pickNotificationSound(prefs.notificationSound);
      if (picked == null) return;
      await prefs.setNotificationSound(picked.$1, name: picked.$2);
    } else {
      await prefs.setNotificationSound(value);
    }
    await UsageTracker.instance.applyReminderSettings();
  }

  Future<void> _testNotification() async {
    if (!await SystemBridge.ensureNotificationPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.notificationsBlocked)));
      return;
    }
    await SystemBridge.notifyNow(
      title: l10n.reminderContinueTitle,
      body: l10n.testNotificationBody,
      sound: AppPreferences.instance.notificationSound,
    );
  }

  Widget _hapticsSection() {
    final prefs = AppPreferences.instance;
    return _Section(
      title: l10n.haptics,
      children: [
        _SwitchRow(label: l10n.vibrationFeedback, value: prefs.hapticsEnabled, onChanged: prefs.setHapticsEnabled),
        if (prefs.hapticsEnabled) ...[
          _Row(
            label: l10n.vibrationStrength,
            below: _Segmented<HapticStrength>(
              values: HapticStrength.values,
              selected: prefs.hapticStrength,
              labelOf: (s) => switch (s) {
                HapticStrength.light => l10n.strengthLight,
                HapticStrength.medium => l10n.strengthMedium,
                HapticStrength.heavy => l10n.strengthHeavy,
              },
              onChanged: (s) async {
                await prefs.setHapticStrength(s);
                AppHaptics.confirm(); // preview
              },
            ),
          ),
          _SwitchRow(label: l10n.hapticsOnChapterSwipe, value: prefs.swipeHaptics, onChanged: prefs.setSwipeHaptics),
        ],
      ],
    );
  }

  Future<void> _resetLibrary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        title: Text(l10n.resetLibraryTitle, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
        content: Text(l10n.resetLibraryBody, style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(l10n.resetLibraryConfirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await LibraryController.instance.resetLibrary();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.libraryResetDone)));
  }

  Widget _librarySection() {
    final lib = LibraryController.instance;
    final folders = lib.scannedFolders;
    // Play build: folders come from the system picker; no "All files access".
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !FolderTree.isUsed;
    return _Section(
      title: l10n.libraryStorage,
      children: [
        _Row(label: l10n.books, trailing: _Value('${lib.books.length}')),
        _Row(
          label: l10n.defaultSort,
          below: _Segmented<LibrarySort>(
            values: LibrarySort.values,
            selected: AppPreferences.instance.librarySort,
            labelOf: librarySortLabel,
            onChanged: AppPreferences.instance.setLibrarySort,
          ),
        ),
        if (isAndroid)
          _Row(
            label: l10n.folderAccess,
            caption: l10n.neededToFindBooksInsideFolders,
            trailing: _folderAccess == true
                ? _Value(l10n.allowed, color: AppColors.accentLime)
                : TextButton(
                    onPressed: () async {
                      await StorageAccess.ensureFolderAccess(context);
                      _refreshAccess();
                    },
                    child: Text(l10n.allow),
                  ),
          ),
        if (folders.isEmpty)
          _Row(label: l10n.scannedFolders, caption: l10n.noneYetAddOneFromThe)
        else
          for (final folder in folders)
            _Row(
              label: folderSegments(folder).lastOrNull ?? folder,
              caption: FolderTree.isTreeUri(folder) ? FolderTree.displayPath(folder) : folder,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lib.isScanning(folder))
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentLime),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: l10n.scanAgain,
                      icon: Icon(Icons.refresh_rounded, color: AppColors.fgMuted),
                      onPressed: () => _rescan(folder),
                    ),
                  IconButton(
                    tooltip: l10n.stopTrackingFolder,
                    icon: Icon(Icons.close_rounded, color: AppColors.fgMuted),
                    onPressed: lib.isScanning(folder) ? null : () => lib.removeScannedFolder(folder),
                  ),
                ],
              ),
            ),
        _ActionRow(
          label: l10n.readingStats,
          icon: Icons.insights_rounded,
          onTap: () => _push(const ReadingStatsScreen()),
        ),
        _ActionRow(label: l10n.resetLibrary, icon: Icons.delete_sweep_outlined, onTap: _resetLibrary, danger: true),
      ],
    );
  }

  Future<void> _openLink(String url) async {
    if (!await SystemBridge.openUrl(url) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.linkUnavailable)));
    }
  }

  Future<void> _checkUpdates() async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);
    await checkForUpdatesNow(context);
    if (mounted) setState(() => _checkingUpdates = false);
  }

  /// Shelves: create, rename, reorder (drag the handle) and delete. Moving
  /// books between shelves happens on Library › Shelves.
  Widget _shelvesSection() {
    final lib = LibraryController.instance;
    final shelves = lib.shelves;
    return _Section(
      title: l10n.shelves,
      subtitle: l10n.manageShelvesCaption,
      children: [
        if (shelves.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            proxyDecorator: (child, _, _) => Material(color: AppColors.figmaSurface, elevation: 6, child: child),
            onReorderItem: lib.reorderShelf,
            children: [
              for (final (i, shelf) in shelves.indexed) _shelfRow(i, shelf, lib.booksOnShelf(shelf).length),
            ],
          ),
        _ActionRow(label: l10n.newShelf, icon: Icons.add_rounded, onTap: () => showCreateShelfDialog(context)),
      ],
    );
  }

  Widget _shelfRow(int index, Shelf shelf, int count) {
    return Padding(
      key: ValueKey(shelf.id),
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.drag_indicator_rounded, color: AppColors.fgSubtle, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shelf.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(fontSize: 15, color: AppColors.fg)),
                const SizedBox(height: 2),
                Text(l10n.shelfBookCount(count), style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgSubtle)),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.addBooks,
            icon: Icon(Icons.library_add_outlined, color: AppColors.fgMuted, size: 20),
            onPressed: () => showAddBooksToShelfSheet(context, shelf),
          ),
          IconButton(
            tooltip: l10n.renameShelf,
            icon: Icon(Icons.drive_file_rename_outline_rounded, color: AppColors.fgMuted, size: 20),
            onPressed: () => showRenameShelfDialog(context, shelf),
          ),
          IconButton(
            tooltip: l10n.deleteShelf,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
            onPressed: () => confirmDeleteShelf(context, shelf),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection() {
    final build = _build;
    return _Section(
      title: l10n.about,
      children: [
        _Row(
          label: AppConstants.appName,
          caption: switch (build?.channel) {
            UpdateChannel.github => l10n.buildGithub,
            UpdateChannel.playstore => l10n.buildPlaystore,
            _ => null,
          },
          trailing: _Value('v${build?.versionName ?? AppConstants.appVersion}'),
        ),
        if (build != null && build.channel != UpdateChannel.none)
          InkWell(
            onTap: _checkUpdates,
            child: _Row(
              label: l10n.checkForUpdates,
              trailing: _checkingUpdates
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentLime),
                    )
                  : Icon(Icons.system_update_rounded, color: AppColors.accentLime, size: 20),
            ),
          ),
        _Row(
          label: l10n.privateByDesign,
          caption: l10n.booksNotesAndProgressAreStored,
        ),
        _Row(label: l10n.formats, caption: BookImportActions.supportedFormatsLabel),
        _ActionRow(
          label: l10n.supportOnKofi,
          caption: l10n.supportOnKofiCaption,
          icon: Icons.coffee_rounded,
          onTap: () => _openLink(AppConstants.kofiUrl),
        ),
        _ActionRow(
          label: l10n.starOnGithub,
          caption: l10n.starOnGithubCaption,
          icon: Icons.star_border_rounded,
          onTap: () => _openLink(AppConstants.githubUrl),
        ),
        _ActionRow(label: l10n.rateFourpage, icon: Icons.star_outline_rounded, onTap: _rate),
        _ActionRow(label: l10n.shareFourpage, icon: Icons.ios_share_rounded, onTap: _share),
      ],
    );
  }
}

// --- building blocks (shared look for every settings row) --------------------

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _Section({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: GoogleFonts.sora(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: AppColors.accentLime)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: GoogleFonts.sora(fontSize: 12, color: AppColors.fgSubtle)),
          ],
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.figmaSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.fgHairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.fgHairline, indent: 16, endIndent: 16),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? caption;
  final Widget? trailing;
  final Widget? below;
  const _Row({required this.label, this.caption, this.trailing, this.below});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.sora(fontSize: 15, color: AppColors.fg)),
                    if (caption != null) ...[
                      const SizedBox(height: 3),
                      Text(caption!, style: GoogleFonts.sora(fontSize: 12, height: 1.4, color: AppColors.fgSubtle)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  final String text;
  final Color? color;
  const _Value(this.text, {this.color});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: GoogleFonts.sora(fontSize: 14, color: color ?? AppColors.fgSubtle));
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Row(
        label: label,
        trailing: Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.accentLime),
      );
}

class _ActionRow extends StatelessWidget {
  final String label;
  final String? caption;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _ActionRow({required this.label, this.caption, required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: _Row(
          label: label,
          caption: caption,
          trailing: Icon(icon, color: danger ? Colors.redAccent : AppColors.accentLime, size: 20),
        ),
      );
}

class _Stepper extends StatelessWidget {
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  const _Stepper({required this.value, this.onDecrease, this.onIncrease});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap) => IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 20, color: onTap == null ? AppColors.fgFaint : AppColors.fg),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, onDecrease),
        SizedBox(
          width: 40,
          child: Text(value, textAlign: TextAlign.center, style: GoogleFonts.sora(fontSize: 15, color: AppColors.fg)),
        ),
        button(Icons.add_rounded, onIncrease),
      ],
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  const _Segmented({required this.values, required this.selected, required this.labelOf, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: v == selected ? AppColors.accentLime : AppColors.pillSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: v == selected ? AppColors.accentLime : AppColors.fgHairline),
              ),
              child: Text(
                labelOf(v),
                style: GoogleFonts.sora(fontSize: 13, color: v == selected ? Colors.black : AppColors.fg),
              ),
            ),
          ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final String name;
  final Color background;
  final Color foreground;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeSwatch({
    required this.name,
    required this.background,
    required this.foreground,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppColors.accentLime : AppColors.fgHairline, width: selected ? 2.5 : 1),
            ),
            child: Text(l10n.fontSampleGlyph, style: GoogleFonts.literata(fontSize: 18, color: foreground)),
          ),
          const SizedBox(height: 6),
          Text(name, style: GoogleFonts.sora(fontSize: 11, color: AppColors.fgSubtle)),
        ],
      ),
    );
  }
}
