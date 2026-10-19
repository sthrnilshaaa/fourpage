/// EPUB Validation Pipeline validating ZIP/OCF, mimetype, container.xml, OPF, manifest, and spine before parsing.
library;

import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../source/book_source.dart';

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> warnings;

  const ValidationResult.success([this.warnings = const []])
      : isValid = true,
        errorMessage = null;

  const ValidationResult.failure(this.errorMessage, [this.warnings = const []])
      : isValid = false;
}

class EpubValidator {
  const EpubValidator();

  /// Validates an EPUB BookSource against standard OCF/OPF requirements.
  Future<ValidationResult> validate(BookSource source) async {
    final warnings = <String>[];
    try {
      final bytes = await source.readBytes();
      if (bytes.isEmpty) {
        return const ValidationResult.failure('File is empty.');
      }

      // Step 1: Validate ZIP/OCF Archive
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (e) {
        return ValidationResult.failure('Not a valid ZIP/OCF archive: $e');
      }

      // Step 2: Validate mimetype entry
      final mimetypeFile = archive.findFile('mimetype');
      if (mimetypeFile != null) {
        final mimetypeStr = utf8.decode(mimetypeFile.content as List<int>).trim();
        if (!mimetypeStr.contains('epub')) {
          warnings.add('Non-standard mimetype entry "$mimetypeStr". Expected "application/epub+zip".');
        }
      } else {
        warnings.add('Missing "mimetype" file in OCF container root.');
      }

      // Step 3 & 4: Validate META-INF/container.xml
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile == null) {
        return const ValidationResult.failure('Missing META-INF/container.xml file in EPUB container.');
      }

      final XmlDocument containerXml;
      try {
        final containerStr = utf8.decode(containerFile.content as List<int>);
        containerXml = XmlDocument.parse(containerStr);
      } catch (e) {
        return ValidationResult.failure('Failed to parse META-INF/container.xml: $e');
      }

      final rootfileNodes = containerXml.findAllElements('rootfile');
      if (rootfileNodes.isEmpty) {
        return const ValidationResult.failure('No <rootfile> specified in container.xml.');
      }

      final opfPath = rootfileNodes.first.getAttribute('full-path');
      if (opfPath == null || opfPath.isEmpty) {
        return const ValidationResult.failure('Rootfile full-path attribute is missing or empty.');
      }

      // Step 5 & 6: Validate Package OPF Document
      final opfFile = archive.findFile(opfPath);
      if (opfFile == null) {
        return ValidationResult.failure('Package OPF document "$opfPath" not found in EPUB archive.');
      }

      final XmlDocument opfXml;
      try {
        final opfStr = utf8.decode(opfFile.content as List<int>);
        opfXml = XmlDocument.parse(opfStr);
      } catch (e) {
        return ValidationResult.failure('Failed to parse OPF XML package document: $e');
      }

      // Step 7: Validate Manifest
      final manifestElements = opfXml.findAllElements('manifest');
      if (manifestElements.isEmpty || manifestElements.first.findElements('item').isEmpty) {
        return const ValidationResult.failure('OPF package document manifest is empty or missing.');
      }

      // Step 8: Validate Spine
      final spineElements = opfXml.findAllElements('spine');
      if (spineElements.isEmpty || spineElements.first.findElements('itemref').isEmpty) {
        return const ValidationResult.failure('OPF package document spine reading order is empty or missing.');
      }

      return ValidationResult.success(warnings);
    } catch (e) {
      return ValidationResult.failure('Unexpected error during EPUB validation: $e');
    }
  }
}
