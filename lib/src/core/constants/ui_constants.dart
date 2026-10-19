/// Isolated visual dimensions, paddings, border radii, and component metrics.
library;

class UIConstants {
  UIConstants._();

  // Screen Padding & Margins
  static const double screenPaddingHorizontal = 20.0;
  static const double screenPaddingVertical = 12.0;
  static const double cardMarginRight = 14.0;
  static const double sheetPaddingHorizontal = 24.0;
  static const double sheetPaddingVertical = 16.0;

  // Component Dimensions
  static const double bookCardWidth = 135.0;
  static const double bookCardHeight = 190.0;
  static const double carouselHeight = 270.0;
  static const double listItemCoverWidth = 60.0;
  static const double listItemCoverHeight = 84.0;
  static const double getStartedButtonHeight = 62.0;
  static const double themeBoxHeight = 44.0;
  static const double dragHandleWidth = 36.0;
  static const double dragHandleHeight = 4.0;
  static const double floatingBarHeight = 48.0;
  // Reader chrome: one size for square icon-boxes (back/TOC/customize...),
  // one for circular close buttons on sheets/popups - was previously 44/36/46
  // used interchangeably for the same kind of control.
  static const double readerIconBoxSize = 44.0;
  static const double popupCloseButtonSize = 36.0;
  // Side padding of book text in both reader engines.
  // Book text side padding; the book's own paragraph margins add a few more.
  static const double readerTextPadding = 16.0;

  // Corner Radii
  static const double cardCornerRadius = 10.0;
  static const double sheetCornerRadius = 24.0;
  static const double pillCornerRadius = 30.0;
  static const double buttonCornerRadius = 12.0;
  static const double dialogCornerRadius = 20.0;

  // Typography Sizes
  static const double introHeadlineFontSize = 32.0;
  static const double sectionTitleFontSize = 20.0;
  static const double sheetTitleFontSize = 18.0;
  static const double buttonFontSize = 17.0;
  static const double bookTitleFontSize = 16.0;
  static const double bodyFontSize = 15.0;
  static const double subtitleFontSize = 14.0;
  static const double captionFontSize = 12.0;
  static const double tagFontSize = 10.0;

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration normalAnimation = Duration(milliseconds: 300);
}
