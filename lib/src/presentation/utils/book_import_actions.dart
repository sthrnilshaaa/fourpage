/// The two ways to add books - pick files, scan a folder - shared by the
/// Import dialog and onboarding so both behave (and report) identically.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

import '../../data/importers/document_converter.dart';
import '../platform/folder_tree.dart';
import '../state/library_controller.dart';
import '../theme/app_colors.dart';
import 'folder_scanner.dart';
import 'storage_access.dart';

class ImportOutcome {
  final int imported;
  final int failed;
  final String? lastTitle;
  final bool cancelled;
  const ImportOutcome({this.imported = 0, this.failed = 0, this.lastTitle, this.cancelled = false});
}

class BookImportActions {
  BookImportActions._();

  /// Human-readable list of what this device can import, e.g. "EPUB, PDF, ...".
  static String get supportedFormatsLabel {
    final exts = LibraryController.importableExtensions;
    final names = <String>[
      'EPUB',
      if (exts.contains('pdf')) 'PDF',
      l10n.wordDocx,
      l10n.text,
      l10n.markdown,
      'HTML',
    ];
    return names.join(' · ');
  }

  /// Opens the file picker (multi-select, every supported format) and imports
  /// the chosen files. Shows the result as a snackbar on [context].
  static Future<ImportOutcome> pickFiles(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: LibraryController.importableExtensions,
      );
    } catch (e) {
      _show(messenger, l10n.filePickerError('$e'), error: true);
      return const ImportOutcome(failed: 1);
    }
    if (files.isEmpty) return const ImportOutcome(cancelled: true);

    var imported = 0;
    final failures = <String>[];
    String? lastTitle;
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) throw UnsupportedDocumentException(file.name, UnsupportedReason.emptyFile);
        final item = await LibraryController.instance.addDocument(
          fileName: file.name,
          bytes: bytes,
          folderPath: file.path != null ? File(file.path!).parent.path : null,
        );
        lastTitle = item.publication.metadata.title;
        imported++;
      } on UnsupportedDocumentException catch (e) {
        failures.add('${e.fileName}: ${describeUnsupported(e.reason)}');
      } catch (e) {
        failures.add('${file.name}: couldn\'t be read ($e)');
      }
    }

    if (imported > 0 && failures.isEmpty) {
      _show(messenger, imported == 1 ? l10n.addedBook(lastTitle ?? '') : l10n.addedBooks(imported));
    } else if (imported > 0) {
      _show(messenger, l10n.addedWithFailures(imported, failures.length, failures.first), warn: true);
    } else {
      _show(messenger, failures.isEmpty ? l10n.nothingImported : failures.first, error: true);
    }
    return ImportOutcome(imported: imported, failed: failures.length, lastTitle: lastTitle);
  }

  /// Asks for folder access (Android), lets the user pick a folder and
  /// imports every supported document inside it.
  static Future<ImportOutcome> scanFolder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final String? folder;
    if (FolderTree.isUsed) {
      // Play build: the system folder picker grants access to this folder.
      folder = await FolderTree.pick();
    } else {
      if (!await StorageAccess.ensureFolderAccess(context)) return const ImportOutcome(cancelled: true);
      folder = await FilePicker.getDirectoryPath();
    }
    if (folder == null || folder.isEmpty) return const ImportOutcome(cancelled: true);
    try {
      final count = await LibraryController.instance.scanAndImportFolder(folder);
      _show(
        messenger,
        count == 0 ? l10n.noBooksInFolder(supportedFormatsLabel) : l10n.addedFromFolder(count),
        warn: count == 0,
      );
      return ImportOutcome(imported: count);
    } on FolderScanPermissionException {
      _show(messenger, l10n.thisFolderCanTBeRead, warn: true);
      return const ImportOutcome(failed: 1);
    } catch (e) {
      _show(messenger, l10n.folderScanError('$e'), error: true);
      return const ImportOutcome(failed: 1);
    }
  }

  /// Translated explanation for an import that can't be done.
  static String describeUnsupported(UnsupportedReason reason) => switch (reason) {
        UnsupportedReason.legacyWordDoc => l10n.importErrorLegacyDoc,
        UnsupportedReason.unknownType => l10n.importErrorUnknownType,
        UnsupportedReason.damagedFile => l10n.importErrorDamaged,
        UnsupportedReason.notWordDocument => l10n.importErrorNotWord,
        UnsupportedReason.emptyFile => l10n.importErrorEmpty,
        UnsupportedReason.pdfNotSupported => l10n.importErrorPdfUnsupported,
      };

  static void _show(ScaffoldMessengerState messenger, String text, {bool error = false, bool warn = false}) {
    messenger.showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.redAccent : (warn ? Colors.orange : AppColors.accentLime),
      duration: const Duration(seconds: 4),
    ));
  }
}
