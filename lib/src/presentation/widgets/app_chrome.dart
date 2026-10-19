import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_controller.dart';

/// Shared building blocks for the Figma "book reader" screens (Home, Search,
/// Library, Saved, reader header). Measurements are taken straight from the
/// 440pt-wide Figma frames so every screen lines up the same way.

/// Renders one of the Figma-exported SVG icons, optionally re-tinted.
class FigmaIcon extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final Color? color;

  const FigmaIcon(this.asset, {super.key, this.width, this.height, this.color});

  // Icons drawn in lime in the Figma export; every other icon is white.
  static const _limeAssets = {
    AssetConstants.iconAddBook,
    AssetConstants.navHomeActive,
    AssetConstants.navLibraryActive,
    AssetConstants.navSavedActive,
  };

  @override
  Widget build(BuildContext context) {
    // The exports are white/lime for the dark design. In light mode re-tint
    // them (white -> ink, lime -> the deeper light-mode lime) so they stay
    // visible; dark mode keeps the original artwork.
    final tint = color ??
        (AppThemeController.instance.isLight
            ? (_limeAssets.contains(asset) ? AppColors.figmaLime : AppColors.fg)
            : null);
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      colorFilter: tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}

/// The header area behind the top bar: a #151515 -> transparent fade with a
/// hairline bottom edge ("Group 67608", 139pt tall incl. the status bar).
class AppHeader extends StatelessWidget {
  final Widget child;

  const AppHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.figmaHeaderTop, AppColors.figmaHeaderTop.withValues(alpha: 0)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 15, 17),
          child: child,
        ),
      ),
    );
  }
}

/// The three-segment bar (56 | flexible | 56, 3pt gaps, 20pt outer radius,
/// 57pt tall) used as the search bar and the reader header.
class SegmentedTopBar extends StatelessWidget {
  final Widget leading;
  final Widget middle;
  final Widget trailing;
  final VoidCallback? onLeadingTap;
  final VoidCallback? onMiddleTap;
  final VoidCallback? onTrailingTap;

  static double height = 57;
  static double _sideWidth = 56;
  static double _gap = 3;
  static Radius _radius = Radius.circular(20);

  const SegmentedTopBar({
    super.key,
    required this.leading,
    required this.middle,
    required this.trailing,
    this.onLeadingTap,
    this.onMiddleTap,
    this.onTrailingTap,
  });

  Widget _segment({
    required Widget child,
    required BorderRadius radius,
    VoidCallback? onTap,
    double? width,
    AlignmentGeometry alignment = Alignment.center,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.figmaSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          // White segments on the off-white light page need an edge.
          side: AppThemeController.instance.isLight ? BorderSide(color: AppColors.fgHairline) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Align(alignment: alignment, child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _segment(
          width: _sideWidth,
          radius: BorderRadius.only(
            topLeft: _radius,
            bottomLeft: _radius,
          ),
          onTap: onLeadingTap,
          child: leading,
        ),
        SizedBox(width: _gap),
        Expanded(
          child: _segment(
            radius: BorderRadius.zero,
            onTap: onMiddleTap,
            alignment: Alignment.centerLeft,
            child: middle,
          ),
        ),
        SizedBox(width: _gap),
        _segment(
          width: _sideWidth,
          radius: BorderRadius.only(
            topRight: _radius,
            bottomRight: _radius,
          ),
          onTap: onTrailingTap,
          child: trailing,
        ),
      ],
    );
  }
}

/// The lime open-book mark in the bar's left segment.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AssetConstants.logoBook,
      width: 27,
      height: 17,
      fit: BoxFit.contain,
    );
  }
}

/// Search bar as shown on Home/Library/Saved: logo | "Search books" | add.
class BrowseTopBar extends StatelessWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onAddTap;

  const BrowseTopBar({
    super.key,
    required this.onSearchTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppHeader(
      child: SegmentedTopBar(
        leading: AppLogoMark(),
        middle: Padding(
          padding: EdgeInsets.only(left: 32),
          child: Text(l10n.searchBooks, style: AppText.searchPlaceholder),
        ),
        trailing: FigmaIcon(
          AssetConstants.iconAddBook,
          width: 17,
          height: 18,
        ),
        onMiddleTap: onSearchTap,
        onTrailingTap: onAddTap,
      ),
    );
  }
}

/// Text styles that recur across the Figma screens.
class AppText {
  AppText._();

  static TextStyle get searchPlaceholder => GoogleFonts.sora(
    fontSize: 17,
    height: 18 / 17,
    letterSpacing: -0.34,
    color: AppColors.figmaTextGhost,
  );

  static TextStyle get searchInput =>
      searchPlaceholder.copyWith(color: AppColors.fg);

  static TextStyle get sectionTitle =>
      GoogleFonts.sora(fontSize: 20, letterSpacing: -0.4, color: AppColors.fg);

  static TextStyle get sectionSubtitle => GoogleFonts.sora(
    fontSize: 14,
    height: 18 / 14,
    letterSpacing: -0.28,
    color: AppColors.figmaTextFaint,
  );

  static TextStyle get listTitle =>
      GoogleFonts.sora(fontSize: 15, height: 23 / 15, color: AppColors.fg);

  static TextStyle get listAuthor => GoogleFonts.sora(
    fontSize: 15,
    height: 14 / 15,
    color: AppColors.figmaTextMuted,
  );

  static TextStyle get listPercent => GoogleFonts.sora(
    fontSize: 10,
    height: 14 / 10,
    color: AppColors.figmaTextMuted,
  );
}

/// Three evenly-spaced text tabs with a 127pt underline under the active one
/// and a chevron after its label ("Group 563" on Library/Saved).
class UnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Tapping the already-selected tab (the one showing the arrow), e.g. to
  /// open sort options for it.
  final ValueChanged<int>? onSelectedTap;

  static const _duration = Duration(milliseconds: 240);

  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.onSelectedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 13),
      child: SizedBox(
        height: 37,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / labels.length;
            final underline = slot < 127 ? slot : 127.0;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 1, color: AppColors.figmaDivider),
                ),
                AnimatedPositioned(
                  duration: _duration,
                  curve: Curves.easeOutCubic,
                  left: slot * selectedIndex + (slot - underline) / 2,
                  bottom: 1,
                  width: underline,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.fg,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(labels.length, (i) {
                    final selected = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => selected && onSelectedTap != null ? onSelectedTap!(i) : onSelected(i),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: _duration,
                                style: GoogleFonts.sora(
                                  fontSize: 17,
                                  height: 14 / 17,
                                  letterSpacing: -0.34,
                                  fontWeight: selected
                                      ? FontWeight.w400
                                      : FontWeight.w300,
                                  color: selected
                                      ? AppColors.fg
                                      : AppColors.figmaTextFaint,
                                ),
                                child: Text(labels[i]),
                              ),
                              AnimatedSize(
                                duration: _duration,
                                curve: Curves.easeOutCubic,
                                child: selected
                                    ? Padding(
                                        padding: EdgeInsets.only(left: 10),
                                        child: FigmaIcon(
                                          AssetConstants.iconChevronDown,
                                          width: 11,
                                          height: 7,
                                          color: AppColors.fg,
                                        ),
                                      )
                                    : SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The dog-eared file glyph with "EPUB"/"PDF" inside (17x23).
class FormatBadge extends StatelessWidget {
  final String format;

  /// Colour of the outline, fold and label.
  final Color color;

  /// Label colour, when it differs from [color] (Search's faint variant).
  final Color? labelColor;

  /// Dark fill behind the glyph - used when it sits on top of a cover.
  final bool filled;

  const FormatBadge({
    super.key,
    required this.format,
    this.color = const Color(0xFF404040),
    this.labelColor,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16.87,
      height: 23,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (filled)
            Positioned(
              left: 0,
              top: 1,
              child: FigmaIcon(
                AssetConstants.formatFileFill,
                width: 16.5,
                height: 21,
              ),
            ),
          Positioned.fill(
            child: FigmaIcon(AssetConstants.formatFileOutline, color: color),
          ),
          Positioned(
            left: 8.38,
            top: 0.36,
            child: FigmaIcon(
              AssetConstants.formatFileFold,
              width: 8.0,
              height: 7.14,
              color: color,
            ),
          ),
          Positioned(
            left: -6,
            right: -6,
            top: 11,
            child: Text(
              format.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 7,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.14,
                color: labelColor ?? color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3pt progress bar: white-30% track (or white-5% on Home) with a lime fill.
class ThinProgressBar extends StatelessWidget {
  final double value;
  final Color? trackColor;
  final Color? fillColor;

  const ThinProgressBar({
    super.key,
    required this.value,
    this.trackColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final v = value.clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: trackColor ?? AppColors.figmaTrack,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * v,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fillColor ?? AppColors.figmaLime,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A book row as used on Library > All Books and Search: 76x114 cover,
/// title/author, full-width progress bar with the percentage (or a checkbox
/// once finished) at its right, and the format glyph top-right.
class BookListRow extends StatelessWidget {
  final Widget cover;
  final String title;
  final String author;
  final String format;
  final double progress; // 0..1
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Lime in the library; Search's result rows use a white fill.
  final Color? progressColor;

  /// Overrides the default dark format glyph.
  final Widget? badge;

  const BookListRow({
    super.key,
    required this.cover,
    required this.title,
    required this.author,
    required this.format,
    required this.progress,
    this.onTap,
    this.onLongPress,
    this.progressColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final finished = progress >= 0.995;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: 114,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(width: 76, child: cover),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 46,
                    top: 7,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.listTitle,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 46,
                    top: 67,
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.listAuthor,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 29,
                    top: 100,
                    child: ThinProgressBar(
                      value: progress,
                      fillColor: progressColor ?? AppColors.figmaLime,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    top: finished ? 95 : 93,
                    child: finished
                        ? const FigmaIcon(
                            AssetConstants.iconCheckboxChecked,
                            width: 13,
                            height: 13,
                          )
                        : Text(
                            '${(progress * 100).round().toString().padLeft(2, '0')}%',
                            style: AppText.listPercent,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    top: 1,
                    child: badge ?? FormatBadge(format: format),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state text used by the list tabs.
class EmptyHint extends StatelessWidget {
  final String text;

  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            color: AppColors.figmaTextMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
