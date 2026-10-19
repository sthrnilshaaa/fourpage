import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/app_chrome.dart';
import '../widgets/update_dialog.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  static MainNavigationShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationShellState>();

  @override
  State<MainNavigationShell> createState() => MainNavigationShellState();
}

class MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  bool _searchOpen = false;

  Timer? _updateCheck;

  @override
  void initState() {
    super.initState();
    // Once a day, a few seconds after start so it doesn't compete with
    // the library loading.
    _updateCheck = Timer(const Duration(seconds: 4), () {
      if (mounted) autoCheckForUpdates(context);
    });
  }

  @override
  void dispose() {
    _updateCheck?.cancel();
    super.dispose();
  }

  /// Shows search over the current tab, keeping the bottom nav in place.
  void openSearch() => setState(() => _searchOpen = true);

  void closeSearch() => setState(() => _searchOpen = false);

  void _selectTab(int index) => setState(() {
    _currentIndex = index;
    _searchOpen = false;
  });

  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    SavedScreen(),
    SettingsScreen(),
  ];

  // Icons exported from the Figma nav ("Frame 707"); Settings has no lime
  // variant in the file, so its active state is the same glyph tinted lime.
  final List<({String label, String icon, String activeIcon, Size size})>
  _tabs = [
    (
      label: l10n.home,
      icon: AssetConstants.navHome,
      activeIcon: AssetConstants.navHomeActive,
      size: Size(25.3, 25.3),
    ),
    (
      label: l10n.library,
      icon: AssetConstants.navLibrary,
      activeIcon: AssetConstants.navLibraryActive,
      size: Size(24.9, 24.9),
    ),
    (
      label: l10n.saved,
      icon: AssetConstants.navSaved,
      activeIcon: AssetConstants.navSavedActive,
      size: Size(22.1, 24.9),
    ),
    (
      label: l10n.settings,
      icon: AssetConstants.navSettings,
      activeIcon: AssetConstants.navSettings,
      size: Size(22.1, 24.9),
    ),
  ];

  // Figma: 252x68 pill, 8pt inner padding, four 55x54 slots 5pt apart, and a
  // 25pt label pill 6pt above it, the whole thing 36pt off the bottom edge
  // over a 170pt fade to the page background.
  static const _pillWidth = 252.0;
  static const _pillHeight = 68.0;
  static const _pillPadding = 8.0;
  static const _slotWidth = 55.0;
  static const _slotHeight = 54.0;
  static const _slotGap = 5.0;
  static const _labelHeight = 25.0;
  static const _labelGap = 6.0;
  static const _bottomInset = 36.0;
  static const _animationDuration = Duration(milliseconds: 260);

  double _slotCenter(int index) =>
      _pillPadding + index * (_slotWidth + _slotGap) + _slotWidth / 2;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Keep the design's 36pt gap on phones without a gesture inset, but don't
    // stack it on top of a large system inset either.
    final bottom = bottomPadding > _bottomInset ? bottomPadding : _bottomInset;

    return PopScope(
      canPop: !_searchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _searchOpen) closeSearch();
      },
      child: Scaffold(
        backgroundColor: AppColors.figmaBackground,
        // Let the keyboard cover the floating nav (Search) instead of
        // shoving it up over the results.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _screens),

            // Search sits over the tab content (not pushed as a route) so the
            // nav bar stays visible, matching the Figma Search_page.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _searchOpen
                    ? SearchScreen(
                        key: const ValueKey('search'),
                        onClose: closeSearch,
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Bottom fade so list content dissolves under the floating nav.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 170 + (bottom - _bottomInset),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.figmaBackground, AppColors.figmaBackground.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: bottom,
              child: Center(
                child: SizedBox(
                  width: _pillWidth,
                  height: _pillHeight + _labelGap + _labelHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Floating label pill - slides to sit above the active tab.
                      AnimatedPositioned(
                        duration: _animationDuration,
                        curve: Curves.easeOutCubic,
                        top: 0,
                        left: _slotCenter(_currentIndex) - 50,
                        width: 100,
                        height: _labelHeight,
                        child: Center(
                          child: _FrostedPill(
                            radius: 25,
                            hug: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              // widthFactor 1: hug the label (67pt for "Home")
                              // instead of filling the 100pt slot.
                              child: Center(
                                widthFactor: 1,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    _tabs[_currentIndex].label,
                                    key: ValueKey(_currentIndex),
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      height: 1,
                                      letterSpacing: -0.26,
                                      color: AppColors.figmaTextFaint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _pillHeight,
                        child: _FrostedPill(
                          radius: 25,
                          borderColor: Colors.black.withValues(alpha: 0.1),
                          child: Stack(
                            children: [
                              // Active slot highlight (lime @10%, 20pt radius).
                              AnimatedPositioned(
                                duration: _animationDuration,
                                curve: Curves.easeOutCubic,
                                left:
                                    _pillPadding -
                                    1 +
                                    _currentIndex * (_slotWidth + _slotGap),
                                top: (_pillHeight - 2 - _slotHeight) / 2,
                                width: _slotWidth,
                                height: _slotHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.figmaLime.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              for (var i = 0; i < _tabs.length; i++)
                                Positioned(
                                  left:
                                      _pillPadding -
                                      1 +
                                      i * (_slotWidth + _slotGap),
                                  top: (_pillHeight - 2 - _slotHeight) / 2,
                                  width: _slotWidth,
                                  height: _slotHeight,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _selectTab(i),
                                    child: Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: FigmaIcon(
                                          i == _currentIndex
                                              ? _tabs[i].activeIcon
                                              : _tabs[i].icon,
                                          key: ValueKey(
                                            '${i}_${i == _currentIndex}',
                                          ),
                                          width: _tabs[i].size.width,
                                          height: _tabs[i].size.height,
                                          color: i == _currentIndex && i == 3
                                              ? AppColors.figmaLime
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// #161616 pill with the design's 30pt backdrop blur.
class _FrostedPill extends StatelessWidget {
  final double radius;
  final Color? borderColor;
  final Widget child;

  /// Size to the child instead of filling the parent (the tab label pill).
  final bool hug;

  const _FrostedPill({
    required this.radius,
    required this.child,
    this.borderColor,
    this.hug = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          alignment: hug ? null : Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.figmaSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ??
                  (AppThemeController.instance.isLight ? AppColors.fgHairline : Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
