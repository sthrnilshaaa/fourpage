import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/book_import_actions.dart';

/// "+" → Import books: choose files (every supported format) or scan a
/// folder. Formats other than EPUB/PDF are converted to EPUB on import.
class AddBookDialog extends StatefulWidget {
  const AddBookDialog({super.key});

  @override
  State<AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends State<AddBookDialog> {
  bool _busy = false;

  Future<void> _run(Future<ImportOutcome> Function(BuildContext) action) async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final outcome = await action(context);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome.imported > 0) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.importBooks2,
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                BookImportActions.supportedFormatsLabel,
                style: GoogleFonts.sora(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  _ImportButton(
                    primary: true,
                    icon: Icons.file_upload_outlined,
                    label: _busy ? l10n.importing : l10n.chooseFiles,
                    busy: _busy,
                    onPressed: _busy ? null : () => _run(BookImportActions.pickFiles),
                  ),
                  const SizedBox(height: 10),
                  _ImportButton(
                    icon: Icons.folder_open_rounded,
                    label: l10n.scanAFolder,
                    onPressed: _busy ? null : () => _run(BookImportActions.scanFolder),
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

class _ImportButton extends StatelessWidget {
  final bool primary;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _ImportButton({this.primary = false, this.busy = false, required this.icon, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.black : AppColors.accentLime;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        busy
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            : Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.bold, color: fg)),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: primary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentLime, shape: shape),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.accentLime), shape: shape),
              child: child,
            ),
    );
  }
}
