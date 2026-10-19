import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/asset_constants.dart';
import '../../data/engine/sakura_fonts.dart';
import '../../domain/entities/reader_preferences.dart';
import '../theme/app_colors.dart';
import 'app_chrome.dart';

/// Appearance controls for the sakura_epub-backed reader, laid out like the
/// Figma "opened_theme" sheet. Every control is wired to something the
/// engine really renders: theme colours, its bundled fonts, size, paragraph
/// alignment + line height (as custom CSS), reading flow, and an in-app
/// dimming overlay for brightness.
class SakuraCustomizationSheet extends StatefulWidget {
  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onChanged;

  /// 0..1 - 1 is full brightness (no dimming).
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;

  const SakuraCustomizationSheet({
    super.key,
    required this.preferences,
    required this.onChanged,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  @override
  State<SakuraCustomizationSheet> createState() => _SakuraCustomizationSheetState();
}

class _SakuraCustomizationSheetState extends State<SakuraCustomizationSheet> {
  late ReaderPreferences _prefs;
  late double _brightness;

  static Color get _sheetColor => AppColors.figmaSurface;
  static Color get _boxColor => AppColors.figmaReaderBackground;
  static Color get _trackColor => AppColors.figmaTextGhost;
  static const _defaults = ReaderPreferences();

  // Line spacing steps shown as 01..05 in the sheet.
  static const _lineHeights = [1.2, 1.35, 1.5, 1.75, 2.0];

  // Figma "Screen mode" swatches, left to right; the last "+" box is the
  // book's own publisher styling.
  static const _swatches = [
    (ReaderTheme.light, Color(0xFFFFFCEF)),
    (ReaderTheme.highContrast, Color(0xFF000000)),
    (ReaderTheme.dark, Color(0xFF121211)),
    (ReaderTheme.sepia, Color(0xFFC2BAA5)),
  ];

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferences;
    _brightness = widget.brightness;
  }

  void _update(ReaderPreferences newPrefs) {
    setState(() => _prefs = newPrefs);
    widget.onChanged(newPrefs);
  }

  // The engine falls back to its default font for families it doesn't bundle (e.g.
  // the app-wide 'Merriweather' default), so highlight what's really shown.
  String get _activeFont => SakuraFonts.byFamily(_prefs.fontFamily).flutterFontFamily;

  int get _lineStep {
    var best = 0;
    for (var i = 0; i < _lineHeights.length; i++) {
      if ((_lineHeights[i] - _prefs.lineHeight).abs() < (_lineHeights[best] - _prefs.lineHeight).abs()) best = i;
    }
    return best;
  }

  TextStyle get _label => GoogleFonts.sora(fontSize: 17, height: 14 / 17, letterSpacing: -0.34, color: AppColors.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _sheetColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 11, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 75,
                  height: 6,
                  decoration: BoxDecoration(color: _trackColor, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.themingCustomization,
                      style: GoogleFonts.sora(fontSize: 20, letterSpacing: -0.4, color: AppColors.fg),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const FigmaIcon(AssetConstants.iconCloseCircle, width: 48, height: 48),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Screen mode
              Text(l10n.screenMode, style: _label),
              const SizedBox(height: 15),
              _boxRow([
                for (final (theme, color) in _swatches)
                  _box(
                    selected: _prefs.theme == theme,
                    color: color,
                    onTap: () => _update(_prefs.copyWith(theme: theme)),
                  ),
                _plusBox(
                  selected: _prefs.theme == ReaderTheme.publisher,
                  onTap: () => _update(_prefs.copyWith(theme: ReaderTheme.publisher)),
                ),
              ]),
              _divider(top: 21),

              // Font Style
              Text(l10n.fontStyle, style: _label),
              const SizedBox(height: 13),
              _boxRow([
                for (final font in SakuraFonts.options.take(4))
                  _box(
                    selected: _activeFont == font.flutterFontFamily,
                    color: _boxColor,
                    onTap: () => _update(_prefs.copyWith(fontFamily: font.flutterFontFamily)),
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontFamily: font.flutterFontFamily,
                        package: SakuraFonts.package,
                        fontSize: 18,
                        color: AppColors.fg,
                      ),
                    ),
                  ),
                _plusBox(
                  selected: SakuraFonts.options.skip(4).any((f) => f.flutterFontFamily == _activeFont),
                  onTap: _pickMoreFonts,
                ),
              ]),
              _divider(top: 21),

              _stepperRow(
                label: l10n.textSize,
                value: _prefs.fontSize.round().toString(),
                onDecrease: _prefs.fontSize > 10 ? () => _update(_prefs.copyWith(fontSize: _prefs.fontSize - 1)) : null,
                onIncrease: _prefs.fontSize < 36 ? () => _update(_prefs.copyWith(fontSize: _prefs.fontSize + 1)) : null,
                isDefault: _prefs.fontSize == _defaults.fontSize,
                onReset: () => _update(_prefs.copyWith(fontSize: _defaults.fontSize)),
              ),
              _divider(),

              // Alignment
              SizedBox(
                height: 57,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.alignment, style: _label)),
                    // Figma only exports a right-aligned glyph and mirrors it
                    // for "left".
                    for (final (value, asset, mirrored) in const [
                      ('left', AssetConstants.iconAlignRight, true),
                      ('right', AssetConstants.iconAlignRight, false),
                      ('center', AssetConstants.iconAlignCenter, false),
                      ('justify', AssetConstants.iconAlignJustify, false),
                    ])
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _update(_prefs.copyWith(textAlignment: value)),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Transform.flip(
                            flipX: mirrored,
                            child: FigmaIcon(
                              asset,
                              width: 22,
                              height: 22,
                              color: _prefs.textAlignment == value ? AppColors.fg : AppColors.figmaTextFaint,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _divider(top: 0),

              _stepperRow(
                label: l10n.lineSpacing,
                value: (_lineStep + 1).toString().padLeft(2, '0'),
                onDecrease: _lineStep > 0 ? () => _update(_prefs.copyWith(lineHeight: _lineHeights[_lineStep - 1])) : null,
                onIncrease: _lineStep < _lineHeights.length - 1
                    ? () => _update(_prefs.copyWith(lineHeight: _lineHeights[_lineStep + 1]))
                    : null,
                isDefault: _prefs.lineHeight == _defaults.lineHeight,
                onReset: () => _update(_prefs.copyWith(lineHeight: _defaults.lineHeight)),
              ),
              _divider(),

              // Reading mode (not in the Figma sheet, but the engine supports
              // it and it was already a working setting - kept, same style).
              SizedBox(
                height: 57,
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.readingMode, style: _label)),
                    _flowChip(l10n.paginated, ScrollMode.paginated),
                    const SizedBox(width: 8),
                    _flowChip(l10n.scrolled, ScrollMode.continuous),
                  ],
                ),
              ),
              _divider(top: 0),

              // Brightness
              Text(l10n.brightness, style: _label),
              const SizedBox(height: 20),
              _BrightnessSlider(
                value: _brightness,
                trackColor: _trackColor,
                onChanged: (v) {
                  setState(() => _brightness = v);
                  widget.onBrightnessChanged(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider({double top = 0}) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 18),
        child: Divider(height: 1, thickness: 1, color: AppColors.figmaDivider),
      );

  /// Five 67x33 boxes spread across the sheet (14pt gaps at the design width).
  Widget _boxRow(List<Widget> boxes) {
    return Row(
      children: [
        for (var i = 0; i < boxes.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: boxes[i]),
        ],
      ],
    );
  }

  Widget _box({required bool selected, required Color color, required VoidCallback onTap, Widget? child}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 33,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppColors.figmaLime : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _plusBox({required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 33,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppColors.figmaLime : AppColors.fg.withValues(alpha: 0.6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text('+', style: GoogleFonts.sora(fontSize: 13, height: 1, color: AppColors.fg)),
      ),
    );
  }

  Widget _stepperRow({
    required String label,
    required String value,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
    required bool isDefault,
    required VoidCallback onReset,
  }) {
    Widget triangle({required bool left, VoidCallback? onTap}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: RotatedBox(
              quarterTurns: left ? 1 : 3,
              child: FigmaIcon(
                AssetConstants.iconTriangleDown,
                width: 15,
                height: 9,
                color: onTap == null ? AppColors.figmaTextFaint : AppColors.fg,
              ),
            ),
          ),
        );

    return SizedBox(
      height: 39,
      child: Row(
        children: [
          Expanded(child: Text(label, style: _label)),
          triangle(left: true, onTap: onDecrease),
          SizedBox(
            width: 40,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 17,
                height: 14 / 17,
                color: AppColors.figmaTextFaint,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.figmaTextFaint,
              ),
            ),
          ),
          triangle(left: false, onTap: onIncrease),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: isDefault ? null : onReset,
            child: FigmaIcon(
              AssetConstants.iconReset,
              width: 18,
              height: 18,
              color: isDefault ? AppColors.figmaTextFaint : AppColors.fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowChip(String label, ScrollMode mode) {
    final selected = _prefs.scrollMode == mode;
    return GestureDetector(
      onTap: () => _update(_prefs.copyWith(scrollMode: mode)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _boxColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? AppColors.figmaLime : Colors.transparent, width: 1.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(fontSize: 13, color: selected ? AppColors.fg : AppColors.figmaTextFaint),
        ),
      ),
    );
  }

  /// "+" in Font Style: the rest of the engine's bundled fonts.
  Future<void> _pickMoreFonts() async {
    final picked = await showModalBottomSheet<SakuraFontOption>(
      context: context,
      backgroundColor: _sheetColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final font in SakuraFonts.options)
              ListTile(
                onTap: () => Navigator.of(context).pop(font),
                title: Text(
                  font.displayName,
                  style: TextStyle(
                    fontFamily: font.flutterFontFamily,
                    package: SakuraFonts.package,
                    fontSize: 17,
                    color: AppColors.fg,
                  ),
                ),
                trailing: _activeFont == font.flutterFontFamily
                    ? Icon(Icons.check_rounded, color: AppColors.figmaLime)
                    : null,
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null) _update(_prefs.copyWith(fontFamily: picked.flutterFontFamily));
  }
}

/// Figma brightness control: white filled track, a 6x19 white handle, and a
/// #474746 remainder, all 13pt tall.
class _BrightnessSlider extends StatelessWidget {
  final double value;
  final Color trackColor;
  final ValueChanged<double> onChanged;

  const _BrightnessSlider({required this.value, required this.trackColor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const handle = 6.0;
        const gap = 5.0;
        void set(double dx) => onChanged(((dx) / width).clamp(0.2, 1.0));
        final x = (width - handle) * value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => set(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
          child: SizedBox(
            height: 25,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  width: (x - gap).clamp(0.0, width),
                  height: 13,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.fg, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Positioned(
                  left: (x + handle + gap).clamp(0.0, width),
                  right: 0,
                  height: 13,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Positioned(
                  left: x,
                  width: handle,
                  height: 19,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.fg, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
