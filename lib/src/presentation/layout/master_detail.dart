import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'max_width.dart';

/// A list of section titles on the left and the chosen section on the right
/// (Settings on medium/expanded windows).
class MasterDetail extends StatelessWidget {
  final List<String> titles;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget detail;
  final Widget? header;
  final double masterWidth;

  const MasterDetail({
    super.key,
    required this.titles,
    required this.selected,
    required this.onSelected,
    required this.detail,
    this.header,
    this.masterWidth = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: masterWidth,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.dividerSubtle))),
          child: SafeArea(
            right: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
              children: [
                if (header != null) Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 18), child: header),
                for (var i = 0; i < titles.length; i++) _item(i),
              ],
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            left: false,
            child: MaxWidth(maxWidth: 720, child: detail),
          ),
        ),
      ],
    );
  }

  Widget _item(int i) {
    final active = i == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? AppColors.figmaLime.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Text(
              titles[i],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.figmaLime : AppColors.fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
