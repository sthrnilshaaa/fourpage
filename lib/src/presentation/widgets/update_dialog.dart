/// "Update available" dialog: GitHub builds download and install the APK
/// right here; Play builds hand over to Google Play's update screen.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n.dart';
import '../platform/app_updater.dart';
import '../theme/app_colors.dart';

/// Settings › Check for updates: checks now and says what it found.
Future<void> checkForUpdatesNow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  AvailableUpdate? update;
  try {
    update = await AppUpdater.instance.check();
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.updateCheckFailed)));
    return;
  }
  if (!context.mounted) return;
  if (update == null) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.upToDate)));
    return;
  }
  await showUpdateDialog(context, update, offerSkip: false);
}

/// Startup: the once-a-day check, quiet unless there's something new.
Future<void> autoCheckForUpdates(BuildContext context) async {
  final update = await AppUpdater.instance.autoCheck();
  if (update != null && context.mounted) await showUpdateDialog(context, update);
}

Future<void> showUpdateDialog(BuildContext context, AvailableUpdate update, {bool offerSkip = true}) async {
  if (update.channel == UpdateChannel.playstore) {
    // Play shows its own screen with notes and progress.
    await AppUpdater.instance.startPlayUpdate();
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _GithubUpdateDialog(update: update, offerSkip: offerSkip),
  );
}

enum _Stage { ready, downloading, downloaded }

class _GithubUpdateDialog extends StatefulWidget {
  final AvailableUpdate update;
  final bool offerSkip;
  const _GithubUpdateDialog({required this.update, required this.offerSkip});

  @override
  State<_GithubUpdateDialog> createState() => _GithubUpdateDialogState();
}

class _GithubUpdateDialogState extends State<_GithubUpdateDialog> {
  _Stage _stage = _Stage.ready;
  double? _progress;
  File? _apk;
  String? _message;

  Future<void> _download() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
      _message = null;
      _cancelled = false;
    });
    try {
      final apk = await AppUpdater.instance.downloadApk(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _apk = apk;
        _stage = _Stage.downloaded;
      });
      await _install();
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _Stage.ready;
          _message = _cancelled ? null : l10n.updateDownloadFailed;
        });
      }
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;
    final started = await AppUpdater.instance.installApk(apk);
    if (mounted) setState(() => _message = started ? null : l10n.allowInstallsHint);
  }

  bool _cancelled = false;

  void _cancel() {
    _cancelled = true;
    AppUpdater.instance.cancelDownload();
  }

  @override
  void dispose() {
    if (_stage == _Stage.downloading) AppUpdater.instance.cancelDownload();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.update.notes;
    final percent = ((_progress ?? 0) * 100).round();
    return PopScope(
      // Back while downloading cancels the download first.
      canPop: _stage != _Stage.downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: AlertDialog(
        backgroundColor: AppColors.sheetSurface,
        title: Text(l10n.updateAvailableTitle, style: GoogleFonts.sora(color: AppColors.fg, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.updateAvailableBody(widget.update.version),
                style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 14, height: 1.45),
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  l10n.whatsNew,
                  style: GoogleFonts.sora(color: AppColors.fg, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(notes, style: GoogleFonts.sora(color: AppColors.fgMuted, fontSize: 12, height: 1.45)),
                  ),
                ),
              ],
              if (_stage == _Stage.downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  color: AppColors.accentLime,
                  backgroundColor: AppColors.fg.withValues(alpha: 0.1),
                ),
                const SizedBox(height: 6),
                Text(l10n.downloadingUpdate(percent), style: GoogleFonts.sora(color: AppColors.fgSubtle, fontSize: 12)),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: GoogleFonts.sora(color: AppColors.accentLime, fontSize: 12, height: 1.4)),
              ],
            ],
          ),
        ),
        actions: [
          if (_stage != _Stage.downloading) ...[
            if (widget.offerSkip && _stage == _Stage.ready)
              TextButton(
                onPressed: () {
                  AppUpdater.instance.skip(widget.update);
                  Navigator.of(context).pop();
                },
                child: Text(l10n.skipThisVersion),
              ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.later)),
            if (_stage == _Stage.ready) TextButton(onPressed: _download, child: Text(l10n.updateNow)),
            if (_stage == _Stage.downloaded) TextButton(onPressed: _install, child: Text(l10n.installUpdate)),
          ],
          if (_stage == _Stage.downloading) TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
        ],
      ),
    );
  }
}
