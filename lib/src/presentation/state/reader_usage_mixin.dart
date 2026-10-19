/// Shared by every reader screen: times the reading session and shows the
/// break reminder when it's due.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../platform/app_haptics.dart';
import '../theme/app_colors.dart';
import 'app_preferences.dart';
import 'library_controller.dart';
import 'usage_tracker.dart';

mixin ReaderUsageMixin<T extends StatefulWidget> on State<T> {
  /// The book this reader shows.
  BookItem get usageBook;

  bool _breakDialogOpen = false;

  @override
  void initState() {
    super.initState();
    UsageTracker.instance.startReading(usageBook);
    UsageTracker.instance.breakDue.addListener(_onBreakDue);
  }

  @override
  void dispose() {
    UsageTracker.instance.breakDue.removeListener(_onBreakDue);
    UsageTracker.instance.stopReading();
    super.dispose();
  }

  Future<void> _onBreakDue() async {
    if (!UsageTracker.instance.breakDue.value || _breakDialogOpen || !mounted) return;
    _breakDialogOpen = true;
    AppHaptics.confirm();
    final minutes = AppPreferences.instance.breakMinutes;
    final takeBreak = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        icon: Icon(Icons.self_improvement_rounded, color: AppColors.accentLime, size: 32),
        title: Text(l10n.breakReminderTitle, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
        content: Text(l10n.breakReminderBody(minutes),
            style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.keepReading)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.takeABreak)),
        ],
      ),
    );
    _breakDialogOpen = false;
    UsageTracker.instance.acknowledgeBreak();
    if (takeBreak == true && mounted) Navigator.of(context).maybePop();
  }
}
