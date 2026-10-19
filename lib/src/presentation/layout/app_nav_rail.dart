import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';

/// One tab of the main navigation (same assets as the phone pill).
class NavDestination {
  final String label;
  final String icon;
  final String activeIcon;
  final Size size;

  const NavDestination({required this.label, required this.icon, required this.activeIcon, required this.size});
}

/// Left navigation for medium (icon-only rail, 76 wide) and expanded
/// (labelled sidebar, 220 wide) windows. The active item is solid lime.
class AppNavRail extends StatelessWidget {
  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  static const railWidth = 76.0;
  static const sidebarWidth = 220.0;

  const AppNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? sidebarWidth : railWidth,
      decoration: BoxDecoration(
        color: AppColors.figmaSurface,
        border: Border(right: BorderSide(color: AppColors.dividerSubtle)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 10, vertical: 20),
          child: Column(
            crossAxisAlignment: extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(left: extended ? 10 : 0, bottom: 28, top: 4),
                child: Row(
                  mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    const AppLogoMark(),
                    if (extended) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Fourpages',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.fg),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (var i = 0; i < destinations.length; i++) ...[
                _item(i),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final d = destinations[i];
    final active = i == selectedIndex;
    final ink = AppColors.figmaBackground;
    final icon = FigmaIcon(
      active ? d.activeIcon : d.icon,
      width: d.size.width * 0.86,
      height: d.size.height * 0.86,
      color: active ? ink : null,
    );
    return Tooltip(
      message: extended ? '' : d.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            key: ValueKey('nav-item-$i'),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 48,
            width: extended ? null : 56,
            padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0),
            decoration: BoxDecoration(
              color: active ? AppColors.figmaLime : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: extended
                ? Row(
                    children: [
                      SizedBox(width: 24, child: Center(child: icon)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? ink : AppColors.figmaTextFaint,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: icon),
          ),
        ),
      ),
    );
  }
}
