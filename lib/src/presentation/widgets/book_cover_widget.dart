import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../aread.dart';
import '../state/library_controller.dart';
import '../theme/app_colors.dart';
import 'app_chrome.dart';

enum CoverLayoutMode {
  /// Cover art + title/author/progress bar below it, at UIConstants.bookCardWidth/Height.
  card,

  /// Thumbnail + title/author/progress in a row, at UIConstants.listItemCoverWidth/Height.
  listItem,

  /// Just the cover art (gradient/image + format badge, no title/author/progress
  /// text) - fills whatever size the parent gives it (wrap in a SizedBox).
  /// For call sites that render their own title/author/progress alongside a
  /// custom-sized thumbnail; using `card` there means fitting its ~245px-tall
  /// card layout into a much smaller box meant for the image alone, which
  /// overflows.
  coverOnly,
}

class BookCoverWidget extends StatelessWidget {
  final BookItem book;
  final CoverLayoutMode layoutMode;
  final VoidCallback? onTap;

  /// Corner radius for `coverOnly` (Figma: 2pt in lists, 5pt on Home).
  final double? coverRadius;

  /// Whether to overlay the white file-glyph format badge at the top-left
  /// (Figma shows it on the Home carousel covers only).
  final bool showFormatBadge;

  const BookCoverWidget({
    super.key,
    required this.book,
    this.layoutMode = CoverLayoutMode.card,
    this.onTap,
    this.coverRadius,
    this.showFormatBadge = true,
  });

  // Cover bytes by publication id: the FutureBuilder below used to re-extract
  // the image from the archive on every rebuild, so covers blinked back to
  // the gradient placeholder whenever a parent (tab switch, progress update)
  // rebuilt.
  static final Map<String, Future<Uint8List?>> _coverCache = {};
  static final Map<String, Uint8List?> _coverBytes = {};

  Future<Uint8List?> _cachedCoverBytes() {
    final id = book.publication.id;
    return _coverCache.putIfAbsent(id, () async {
      final bytes = await _loadCoverBytes(book);
      _coverBytes[id] = bytes;
      return bytes;
    });
  }

  Future<Uint8List?> _loadCoverBytes(BookItem book) async {
    final coverResource = book.publication.coverResource;
    if (coverResource == null) return null;

    final resolver = book.session.resourceResolver;
    if (resolver != null && resolver.hasResource(coverResource.href)) {
      try {
        final bytes = await resolver.fetchResourceBytes(coverResource.href);
        if (bytes.isNotEmpty) return Uint8List.fromList(bytes);
      } catch (_) {}
    }

    try {
      final container = OcfContainer.fromBytes(book.archiveBytes);
      final cleanPath = PathUtils.normalizePath(coverResource.href);
      if (container.hasEntry(cleanPath)) {
        return Uint8List.fromList(container.readBytes(cleanPath));
      }
      final filename = cleanPath.split('/').last.toLowerCase();
      for (final path in container.entryPaths) {
        if (path.split('/').last.toLowerCase() == filename) {
          return Uint8List.fromList(container.readBytes(path));
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    switch (layoutMode) {
      case CoverLayoutMode.card:
        return _buildCard(context);
      case CoverLayoutMode.listItem:
        return _buildListItem(context);
      case CoverLayoutMode.coverOnly:
        return GestureDetector(
          onTap: onTap,
          child: _buildCoverArt(context, borderRadius: coverRadius ?? UIConstants.cardCornerRadius, shadow: false),
        );
    }
  }

  /// The actual cover art: gradient background, the book's real cover image
  /// once loaded (or a title/author fallback while it's missing/loading),
  /// and the format badge - shared by `card` and `coverOnly` so both render
  /// pixel-identical art. Fills whatever size its parent constrains it to.
  Widget _buildCoverArt(BuildContext context, {required double borderRadius, required bool shadow}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [book.coverGradientStart, book.coverGradientEnd],
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: FutureBuilder<Uint8List?>(
          future: _cachedCoverBytes(),
          initialData: _coverBytes[book.publication.id],
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (showFormatBadge)
                    Positioned(
                      left: 8,
                      top: 7,
                      child: FormatBadge(format: book.format, color: Colors.white),
                    ),
                ],
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                // The format glyph sits just outside the padding (-4,-5) so it
                // lines up with the image covers' badge at (8,7).
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clear the format glyph pinned at the top-left.
                      if (showFormatBadge) const SizedBox(height: 22),
                      Text(
                        book.publication.metadata.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ptSerif(
                          fontSize: UIConstants.bookTitleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book.publication.metadata.authors.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  if (showFormatBadge)
                    Positioned(
                      left: -4,
                      top: -5,
                      child: FormatBadge(format: book.format, color: Colors.white),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final progress = book.progress * 100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: UIConstants.bookCardWidth,
        margin: const EdgeInsets.only(right: UIConstants.cardMarginRight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: UIConstants.bookCardHeight,
              child: _buildCoverArt(context, borderRadius: UIConstants.cardCornerRadius, shadow: true),
            ),

            const SizedBox(height: 10),

            // Title below cover
            Text(
              book.publication.metadata.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: UIConstants.subtitleFontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),

            // Author below cover
            Text(
              book.publication.metadata.authors.isNotEmpty
                  ? book.publication.metadata.authors.first
                  : l10n.unknownAuthor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: UIConstants.captionFontSize,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 8),

            // Lime Reading Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (progress / 100.0).clamp(0.02, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentLime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context) {
    final progress = book.progress * 100;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UIConstants.cardCornerRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // Thumbnail Cover
            Container(
              width: UIConstants.listItemCoverWidth,
              height: UIConstants.listItemCoverHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [book.coverGradientStart, book.coverGradientEnd],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List?>(
                  future: _cachedCoverBytes(),
          initialData: _coverBytes[book.publication.id],
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          book.publication.metadata.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ptSerif(
                            fontSize: UIConstants.tagFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Book Details & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.publication.metadata.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: UIConstants.bodyFontSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Text(
                          book.format,
                          style: GoogleFonts.sora(
                            fontSize: UIConstants.tagFontSize,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    book.publication.metadata.authors.isNotEmpty
                        ? book.publication.metadata.authors.first
                        : l10n.unknownAuthor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reading Progress Bar & Percentage Label / Checkmark
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (progress / 100.0).clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentLime),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (progress >= 99.5)
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.accentLime.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.accentLime,
                          ),
                        )
                      else
                        Text(
                          '${progress.toInt().toString().padLeft(2, '0')}%',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
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
