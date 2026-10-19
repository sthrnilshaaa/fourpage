import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../aread.dart';
import '../theme/app_colors.dart';

class ReaderCustomizationSheet extends StatefulWidget {
  final ReaderPreferences preferences;
  final ValueChanged<ReaderPreferences> onChanged;

  const ReaderCustomizationSheet({
    super.key,
    required this.preferences,
    required this.onChanged,
  });

  @override
  State<ReaderCustomizationSheet> createState() => _ReaderCustomizationSheetState();
}

class _ReaderCustomizationSheetState extends State<ReaderCustomizationSheet> {
  late ReaderPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferences;
  }

  void _update(ReaderPreferences newPrefs) {
    setState(() => _prefs = newPrefs);
    widget.onChanged(newPrefs);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: UIConstants.dragHandleWidth,
              height: UIConstants.dragHandleHeight,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.fg.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Title & Circular Close Button (opened_theme.png)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.themingCustomization,
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.fg,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: UIConstants.popupCloseButtonSize,
                  height: UIConstants.popupCloseButtonSize,
                  decoration: BoxDecoration(
                    color: AppColors.fg.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.fg),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 1. Screen Mode Colors (Light, Dark, Publisher, Sepia, High Contrast)
          Text(l10n.screenMode, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fgSubtle)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildColorBox(
                color: const Color(0xFFFFFFFF),
                theme: ReaderTheme.light,
              ),
              _buildColorBox(
                color: const Color(0xFF0A0B0E),
                theme: ReaderTheme.dark,
              ),
              _buildColorBox(
                color: const Color(0xFF121A15),
                borderColor: AppColors.figmaLime,
                theme: ReaderTheme.publisher,
              ),
              _buildColorBox(
                color: const Color(0xFFEAE6DF),
                theme: ReaderTheme.sepia,
              ),
              _buildColorBox(
                color: Colors.black,
                borderColor: Colors.yellow,
                theme: ReaderTheme.highContrast,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 2. Font Style Option Chips (A, A, A, A, +)
          Text(l10n.fontStyle, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fgSubtle)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFontChip('Merriweather', 'A', fontStyle: FontStyle.normal),
              _buildFontChip('Sora', 'A'),
              _buildFontChip('JetBrains Mono', 'A', fontStyle: FontStyle.italic),
              _buildFontChip('Inter', 'A'),
            ],
          ),

          const SizedBox(height: 22),

          // 3. Text Size Stepper (< 21 >)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.textSize, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fgSubtle)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: AppColors.fgMuted, size: 22),
                    onPressed: () {
                      if (_prefs.fontSize > 10) {
                        _update(_prefs.copyWith(fontSize: _prefs.fontSize - 1));
                      }
                    },
                  ),
                  Text(
                    '${_prefs.fontSize.round()}',
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.fg, decoration: TextDecoration.underline),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: AppColors.fgMuted, size: 22),
                    onPressed: () {
                      if (_prefs.fontSize < 36) {
                        _update(_prefs.copyWith(fontSize: _prefs.fontSize + 1));
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.rotate_left_rounded, color: AppColors.fgSubtle, size: 20),
                    onPressed: () => _update(_prefs.copyWith(fontSize: 16.0)),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 4. Alignment Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.alignment, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fgSubtle)),
              Row(
                children: [
                  _buildAlignBtn(Icons.format_align_left_rounded, 'left'),
                  _buildAlignBtn(Icons.format_align_center_rounded, 'center'),
                  _buildAlignBtn(Icons.format_align_right_rounded, 'right'),
                  _buildAlignBtn(Icons.format_align_justify_rounded, 'justify'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 5. Line Spacing Stepper (< 02 >)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.lineSpacing, style: GoogleFonts.sora(fontSize: 14, color: AppColors.fgSubtle)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: AppColors.fgMuted, size: 22),
                    onPressed: () {
                      if (_prefs.lineHeight > 1.0) {
                        _update(_prefs.copyWith(lineHeight: _prefs.lineHeight - 0.25));
                      }
                    },
                  ),
                  Text(
                    _prefs.lineHeight.toStringAsFixed(2),
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.fg, decoration: TextDecoration.underline),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: AppColors.fgMuted, size: 22),
                    onPressed: () {
                      if (_prefs.lineHeight < 3.0) {
                        _update(_prefs.copyWith(lineHeight: _prefs.lineHeight + 0.25));
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.rotate_left_rounded, color: AppColors.fgSubtle, size: 20),
                    onPressed: () => _update(_prefs.copyWith(lineHeight: 1.5)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorBox({required Color color, Color? borderColor, required ReaderTheme theme}) {
    final isSelected = _prefs.theme == theme;

    return GestureDetector(
      onTap: () => _update(_prefs.copyWith(theme: theme)),
      child: Container(
        width: 48,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? (borderColor ?? AppColors.figmaLime) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildFontChip(String fontName, String label, {bool isSelected = false, FontStyle fontStyle = FontStyle.normal}) {
    final selected = _prefs.fontFamily == fontName || isSelected;

    return GestureDetector(
      onTap: () => _update(_prefs.copyWith(fontFamily: fontName)),
      child: Container(
        width: 48,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.figmaLime : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontStyle: fontStyle,
            color: AppColors.fg,
          ),
        ),
      ),
    );
  }

  Widget _buildAlignBtn(IconData icon, String alignName) {
    final isSelected = _prefs.textAlignment == alignName;

    return IconButton(
      icon: Icon(icon, color: isSelected ? AppColors.figmaLime : AppColors.fgSubtle, size: 20),
      onPressed: () => _update(_prefs.copyWith(textAlignment: alignName)),
    );
  }
}
