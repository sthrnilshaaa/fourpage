import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Complete'**
  String percentComplete(int percent);

  /// No description provided for @folderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder: {name}'**
  String folderLabel(String name);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pageOf(int page, int total);

  /// No description provided for @pageRangeHint.
  ///
  /// In en, this message translates to:
  /// **'1 – {total}'**
  String pageRangeHint(int total);

  /// No description provided for @couldNotOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this PDF.\n{error}'**
  String couldNotOpenPdf(String error);

  /// No description provided for @chapterBookmark.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number} Bookmark'**
  String chapterBookmark(int number);

  /// No description provided for @chapterN.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterN(int number);

  /// No description provided for @bookmarkAtPercent.
  ///
  /// In en, this message translates to:
  /// **'Bookmark at {percent}%'**
  String bookmarkAtPercent(int percent);

  /// No description provided for @couldNotOpenBookFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this book\'s file.\n{error}'**
  String couldNotOpenBookFile(String error);

  /// No description provided for @percentRead.
  ///
  /// In en, this message translates to:
  /// **'{percent}% read'**
  String percentRead(int percent);

  /// No description provided for @importedBooks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 book} other{Imported {count} books}}'**
  String importedBooks(int count);

  /// No description provided for @filePickerError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file picker: {error}'**
  String filePickerError(String error);

  /// No description provided for @addedBook.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\"'**
  String addedBook(String title);

  /// No description provided for @addedBooks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 book} other{Added {count} books}}'**
  String addedBooks(int count);

  /// No description provided for @addedWithFailures.
  ///
  /// In en, this message translates to:
  /// **'Added {added}, {failed} failed: {firstError}'**
  String addedWithFailures(int added, int failed, String firstError);

  /// No description provided for @noBooksInFolder.
  ///
  /// In en, this message translates to:
  /// **'No books found in that folder ({formats})'**
  String noBooksInFolder(String formats);

  /// No description provided for @addedFromFolder.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 book from the folder} other{Added {count} books from the folder}}'**
  String addedFromFolder(int count);

  /// No description provided for @folderScanError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t scan the folder: {error}'**
  String folderScanError(String error);

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result in this book} other{{count} results in this book}}'**
  String searchResultsCount(int count);

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @noteN.
  ///
  /// In en, this message translates to:
  /// **'Note {number}'**
  String noteN(int number);

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterLabel(String number);

  /// No description provided for @sectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Section {number}'**
  String sectionLabel(String number);

  /// No description provided for @your.
  ///
  /// In en, this message translates to:
  /// **'Your '**
  String get your;

  /// No description provided for @alwaysWithYou.
  ///
  /// In en, this message translates to:
  /// **'\nalways with you.'**
  String get alwaysWithYou;

  /// No description provided for @openYourBooksReadOfflineAnd.
  ///
  /// In en, this message translates to:
  /// **'Open your books, read offline, and enjoy every page\nwithout distractions.'**
  String get openYourBooksReadOfflineAnd;

  /// No description provided for @importYour.
  ///
  /// In en, this message translates to:
  /// **'Import Your '**
  String get importYour;

  /// No description provided for @fourpagesSupportsEpubBooks.
  ///
  /// In en, this message translates to:
  /// **'Fourpages supports EPUB books.'**
  String get fourpagesSupportsEpubBooks;

  /// No description provided for @books.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get books;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip →'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @selectFolders.
  ///
  /// In en, this message translates to:
  /// **'Select Folders'**
  String get selectFolders;

  /// No description provided for @addBooks.
  ///
  /// In en, this message translates to:
  /// **'Add Books'**
  String get addBooks;

  /// No description provided for @unknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown Author'**
  String get unknownAuthor;

  /// No description provided for @recentReading.
  ///
  /// In en, this message translates to:
  /// **'Recent Reading'**
  String get recentReading;

  /// No description provided for @pickUpWhereYouLeftOff.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off'**
  String get pickUpWhereYouLeftOff;

  /// No description provided for @viewAllYourBooks.
  ///
  /// In en, this message translates to:
  /// **'View all your books'**
  String get viewAllYourBooks;

  /// No description provided for @noBooksInYourLibrary.
  ///
  /// In en, this message translates to:
  /// **'No books in your library'**
  String get noBooksInYourLibrary;

  /// No description provided for @importEpubBooksToStartYour.
  ///
  /// In en, this message translates to:
  /// **'Import EPUB books to start your reading journey.'**
  String get importEpubBooksToStartYour;

  /// No description provided for @importBooks.
  ///
  /// In en, this message translates to:
  /// **'Import Books'**
  String get importBooks;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @allBooks.
  ///
  /// In en, this message translates to:
  /// **'All Books'**
  String get allBooks;

  /// No description provided for @shelves.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get shelves;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @noBooksFoundInThisFolder.
  ///
  /// In en, this message translates to:
  /// **'No books found in this folder.'**
  String get noBooksFoundInThisFolder;

  /// No description provided for @showAllBooks.
  ///
  /// In en, this message translates to:
  /// **'Show all books'**
  String get showAllBooks;

  /// No description provided for @noBooksAvailableImportBooksTo.
  ///
  /// In en, this message translates to:
  /// **'No books available.\nImport books to build your library!'**
  String get noBooksAvailableImportBooksTo;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noShelvesYetImportBooksTo.
  ///
  /// In en, this message translates to:
  /// **'No shelves yet.\nImport books to start filling them.'**
  String get noShelvesYetImportBooksTo;

  /// No description provided for @unshelved.
  ///
  /// In en, this message translates to:
  /// **'Unshelved'**
  String get unshelved;

  /// No description provided for @noFoldersYetImportAFolder.
  ///
  /// In en, this message translates to:
  /// **'No folders yet.\nImport a folder of EPUBs to see it here.'**
  String get noFoldersYetImportAFolder;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @fourpagesImported.
  ///
  /// In en, this message translates to:
  /// **'Fourpages/Imported'**
  String get fourpagesImported;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @bookmarkedCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked current location!'**
  String get bookmarkedCurrentLocation;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @fontStyle.
  ///
  /// In en, this message translates to:
  /// **'Font Style'**
  String get fontStyle;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get textSize;

  /// No description provided for @alignment.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get alignment;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get addBookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove Bookmark'**
  String get removeBookmark;

  /// No description provided for @vertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get vertical;

  /// No description provided for @horizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get horizontal;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @feedbackIsnTAvailableYetCheck.
  ///
  /// In en, this message translates to:
  /// **'Feedback isn\'t available yet - check back soon!'**
  String get feedbackIsnTAvailableYetCheck;

  /// No description provided for @customization.
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get customization;

  /// No description provided for @bookmarkThisPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get bookmarkThisPage;

  /// No description provided for @searchInBook.
  ///
  /// In en, this message translates to:
  /// **'Search in book'**
  String get searchInBook;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @writeANote.
  ///
  /// In en, this message translates to:
  /// **'Write a note…'**
  String get writeANote;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @highlightRemoved.
  ///
  /// In en, this message translates to:
  /// **'Highlight removed'**
  String get highlightRemoved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @lastChapter.
  ///
  /// In en, this message translates to:
  /// **'Last chapter'**
  String get lastChapter;

  /// No description provided for @firstChapter.
  ///
  /// In en, this message translates to:
  /// **'First chapter'**
  String get firstChapter;

  /// No description provided for @releaseToOpen.
  ///
  /// In en, this message translates to:
  /// **'Release to open'**
  String get releaseToOpen;

  /// No description provided for @nextChapter.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get nextChapter;

  /// No description provided for @previousChapter.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get previousChapter;

  /// No description provided for @stillOpeningThisBook.
  ///
  /// In en, this message translates to:
  /// **'Still opening this book…'**
  String get stillOpeningThisBook;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @chapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chapters;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @quotes.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get quotes;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @noSavedQuotesYetHighlightText.
  ///
  /// In en, this message translates to:
  /// **'No saved quotes yet.\nHighlight text while reading to save quotes!'**
  String get noSavedQuotesYetHighlightText;

  /// No description provided for @noBookmarksSavedTapBookmarkWhile.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks saved.\nTap bookmark while reading to save pages!'**
  String get noBookmarksSavedTapBookmarkWhile;

  /// No description provided for @noNotesCreatedYet.
  ///
  /// In en, this message translates to:
  /// **'No notes created yet.'**
  String get noNotesCreatedYet;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @searchBooks.
  ///
  /// In en, this message translates to:
  /// **'Search books'**
  String get searchBooks;

  /// No description provided for @noMatchingBooksFound.
  ///
  /// In en, this message translates to:
  /// **'No matching books found'**
  String get noMatchingBooksFound;

  /// No description provided for @paper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get paper;

  /// No description provided for @sepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get sepia;

  /// No description provided for @night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get night;

  /// No description provided for @forest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get forest;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get black;

  /// No description provided for @applyToAllBooks.
  ///
  /// In en, this message translates to:
  /// **'Apply to all books?'**
  String get applyToAllBooks;

  /// No description provided for @everyBookInYourLibraryWill.
  ///
  /// In en, this message translates to:
  /// **'Every book in your library will use these reading settings. You can still change a single book from its reader menu.'**
  String get everyBookInYourLibraryWill;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @readingSettingsAppliedToAllBooks.
  ///
  /// In en, this message translates to:
  /// **'Reading settings applied to all books'**
  String get readingSettingsAppliedToAllBooks;

  /// No description provided for @noEpubBooksFoundInThis.
  ///
  /// In en, this message translates to:
  /// **'No EPUB books found in this folder'**
  String get noEpubBooksFoundInThis;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get appTheme;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @defaultsForBooksYouHavenT.
  ///
  /// In en, this message translates to:
  /// **'Defaults for books you haven\'t customised yet'**
  String get defaultsForBooksYouHavenT;

  /// No description provided for @bookTheme.
  ///
  /// In en, this message translates to:
  /// **'Book theme'**
  String get bookTheme;

  /// No description provided for @textSize2.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize2;

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @justified.
  ///
  /// In en, this message translates to:
  /// **'Justified'**
  String get justified;

  /// No description provided for @centered.
  ///
  /// In en, this message translates to:
  /// **'Centered'**
  String get centered;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @readingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readingMode;

  /// No description provided for @scrollChapter.
  ///
  /// In en, this message translates to:
  /// **'Scroll chapter'**
  String get scrollChapter;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pages;

  /// No description provided for @hapticsOnChapterSwipe.
  ///
  /// In en, this message translates to:
  /// **'Haptics on chapter swipe'**
  String get hapticsOnChapterSwipe;

  /// No description provided for @dynamicBookBackground.
  ///
  /// In en, this message translates to:
  /// **'Dynamic book background'**
  String get dynamicBookBackground;

  /// No description provided for @removeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove highlight'**
  String get removeHighlight;

  /// No description provided for @originalLayout.
  ///
  /// In en, this message translates to:
  /// **'Original layout'**
  String get originalLayout;

  /// No description provided for @fastLayout.
  ///
  /// In en, this message translates to:
  /// **'Fast layout'**
  String get fastLayout;

  /// No description provided for @openedInOriginalLayout.
  ///
  /// In en, this message translates to:
  /// **'This book opens in its original layout (complex formatting)'**
  String get openedInOriginalLayout;

  /// No description provided for @dynamicBookBackgroundCaption.
  ///
  /// In en, this message translates to:
  /// **'Sepia pages in light mode, dark pages in dark mode, following the app theme'**
  String get dynamicBookBackgroundCaption;

  /// No description provided for @applyToAllBooks2.
  ///
  /// In en, this message translates to:
  /// **'Apply to all books'**
  String get applyToAllBooks2;

  /// No description provided for @libraryStorage.
  ///
  /// In en, this message translates to:
  /// **'Library & storage'**
  String get libraryStorage;

  /// No description provided for @defaultSort.
  ///
  /// In en, this message translates to:
  /// **'Default sort'**
  String get defaultSort;

  /// No description provided for @folderAccess.
  ///
  /// In en, this message translates to:
  /// **'Folder access'**
  String get folderAccess;

  /// No description provided for @neededToFindBooksInsideFolders.
  ///
  /// In en, this message translates to:
  /// **'Needed to find books inside folders you scan'**
  String get neededToFindBooksInsideFolders;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @scannedFolders.
  ///
  /// In en, this message translates to:
  /// **'Scanned folders'**
  String get scannedFolders;

  /// No description provided for @noneYetAddOneFromThe.
  ///
  /// In en, this message translates to:
  /// **'None yet - add one from the + button in Library'**
  String get noneYetAddOneFromThe;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @stopTrackingFolder.
  ///
  /// In en, this message translates to:
  /// **'Stop tracking folder'**
  String get stopTrackingFolder;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privateByDesign.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get privateByDesign;

  /// No description provided for @booksNotesAndProgressAreStored.
  ///
  /// In en, this message translates to:
  /// **'Books, notes and progress are stored only on this device. No account, no tracking.'**
  String get booksNotesAndProgressAreStored;

  /// No description provided for @formats.
  ///
  /// In en, this message translates to:
  /// **'Formats'**
  String get formats;

  /// No description provided for @epub2AndEpub3.
  ///
  /// In en, this message translates to:
  /// **'EPUB 2 and EPUB 3'**
  String get epub2AndEpub3;

  /// No description provided for @wordDocx.
  ///
  /// In en, this message translates to:
  /// **'Word (.docx)'**
  String get wordDocx;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @markdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get markdown;

  /// No description provided for @nothingImported.
  ///
  /// In en, this message translates to:
  /// **'Nothing imported'**
  String get nothingImported;

  /// No description provided for @thisFolderCanTBeRead.
  ///
  /// In en, this message translates to:
  /// **'This folder can\'t be read. Allow folder access in Settings, or choose files instead.'**
  String get thisFolderCanTBeRead;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @titleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title (A–Z)'**
  String get titleAZ;

  /// No description provided for @authorAZ.
  ///
  /// In en, this message translates to:
  /// **'Author (A–Z)'**
  String get authorAZ;

  /// No description provided for @readingProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading progress'**
  String get readingProgress;

  /// No description provided for @allowAccessToYourBooks.
  ///
  /// In en, this message translates to:
  /// **'Allow access to your books'**
  String get allowAccessToYourBooks;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @importBooks2.
  ///
  /// In en, this message translates to:
  /// **'Import books'**
  String get importBooks2;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importing;

  /// No description provided for @chooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get chooseFiles;

  /// No description provided for @scanAFolder.
  ///
  /// In en, this message translates to:
  /// **'Scan a folder'**
  String get scanAFolder;

  /// No description provided for @themingCustomization.
  ///
  /// In en, this message translates to:
  /// **'Theming & Customization'**
  String get themingCustomization;

  /// No description provided for @screenMode.
  ///
  /// In en, this message translates to:
  /// **'Screen mode'**
  String get screenMode;

  /// No description provided for @typeAWordOrSentenceTo.
  ///
  /// In en, this message translates to:
  /// **'Type a word or sentence to search in book'**
  String get typeAWordOrSentenceTo;

  /// No description provided for @loadingChapters.
  ///
  /// In en, this message translates to:
  /// **'Loading chapters…'**
  String get loadingChapters;

  /// No description provided for @noNotesSavedInThisBook.
  ///
  /// In en, this message translates to:
  /// **'No notes saved in this book.'**
  String get noNotesSavedInThisBook;

  /// No description provided for @tapPlayToStartListening.
  ///
  /// In en, this message translates to:
  /// **'Tap play to start listening.'**
  String get tapPlayToStartListening;

  /// No description provided for @paginated.
  ///
  /// In en, this message translates to:
  /// **'Paginated'**
  String get paginated;

  /// No description provided for @scrolled.
  ///
  /// In en, this message translates to:
  /// **'Scrolled'**
  String get scrolled;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @noNotesYetSelectTextWhile.
  ///
  /// In en, this message translates to:
  /// **'No notes yet.\nSelect text while reading to add one.'**
  String get noNotesYetSelectTextWhile;

  /// No description provided for @allFilesAccessExplanation.
  ///
  /// In en, this message translates to:
  /// **'Android hides EPUB files in folders from apps by default. To find the books inside a folder, Fourpages needs \"All files access\".\n\nTurn it on for Fourpages on the next screen, then come back.'**
  String get allFilesAccessExplanation;

  /// No description provided for @importErrorLegacyDoc.
  ///
  /// In en, this message translates to:
  /// **'Old Word (.doc) files aren\'t supported - save it as .docx or PDF.'**
  String get importErrorLegacyDoc;

  /// No description provided for @importErrorUnknownType.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get importErrorUnknownType;

  /// No description provided for @importErrorDamaged.
  ///
  /// In en, this message translates to:
  /// **'This file is damaged.'**
  String get importErrorDamaged;

  /// No description provided for @importErrorNotWord.
  ///
  /// In en, this message translates to:
  /// **'Not a Word document.'**
  String get importErrorNotWord;

  /// No description provided for @importErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get importErrorEmpty;

  /// No description provided for @importErrorPdfUnsupported.
  ///
  /// In en, this message translates to:
  /// **'PDF isn\'t supported on this device yet.'**
  String get importErrorPdfUnsupported;

  /// No description provided for @reminderContinueTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to read'**
  String get reminderContinueTitle;

  /// No description provided for @reminderContinueBody.
  ///
  /// In en, this message translates to:
  /// **'Continue {title} — {percent}% done'**
  String reminderContinueBody(String title, int percent);

  /// No description provided for @breakReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Time for a break'**
  String get breakReminderTitle;

  /// No description provided for @breakReminderBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been reading for {minutes} minutes. Rest your eyes for a moment.'**
  String breakReminderBody(int minutes);

  /// No description provided for @keepReading.
  ///
  /// In en, this message translates to:
  /// **'Keep reading'**
  String get keepReading;

  /// No description provided for @takeABreak.
  ///
  /// In en, this message translates to:
  /// **'Take a break'**
  String get takeABreak;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @moreLanguagesSoon.
  ///
  /// In en, this message translates to:
  /// **'More languages coming soon'**
  String get moreLanguagesSoon;

  /// No description provided for @remindersAndNotifications.
  ///
  /// In en, this message translates to:
  /// **'Reminders & notifications'**
  String get remindersAndNotifications;

  /// No description provided for @breakReminder.
  ///
  /// In en, this message translates to:
  /// **'Break reminder'**
  String get breakReminder;

  /// No description provided for @breakReminderCaption.
  ///
  /// In en, this message translates to:
  /// **'Suggest a pause after reading this long without a break'**
  String get breakReminderCaption;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationUnderAMinute.
  ///
  /// In en, this message translates to:
  /// **'< 1 min'**
  String get durationUnderAMinute;

  /// No description provided for @dailyReadingReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reading reminder'**
  String get dailyReadingReminder;

  /// No description provided for @dailyReadingReminderCaption.
  ///
  /// In en, this message translates to:
  /// **'A notification to continue your current book'**
  String get dailyReadingReminderCaption;

  /// No description provided for @notificationSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get notificationSound;

  /// No description provided for @soundDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get soundDefault;

  /// No description provided for @soundSilent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get soundSilent;

  /// No description provided for @soundCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom sound'**
  String get soundCustom;

  /// No description provided for @soundChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get soundChoose;

  /// No description provided for @sendTestNotification.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get sendTestNotification;

  /// No description provided for @testNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Reminders will look like this.'**
  String get testNotificationBody;

  /// No description provided for @notificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Fourpages. Allow them in system settings.'**
  String get notificationsBlocked;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @vibrationFeedback.
  ///
  /// In en, this message translates to:
  /// **'Vibration feedback'**
  String get vibrationFeedback;

  /// No description provided for @vibrationStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get vibrationStrength;

  /// No description provided for @strengthLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get strengthLight;

  /// No description provided for @strengthMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get strengthMedium;

  /// No description provided for @strengthHeavy.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strengthHeavy;

  /// No description provided for @resetLibrary.
  ///
  /// In en, this message translates to:
  /// **'Reset library'**
  String get resetLibrary;

  /// No description provided for @resetLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset library?'**
  String get resetLibraryTitle;

  /// No description provided for @resetLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'This removes every book, highlight, note, bookmark, reading progress and reading stat from this device. Your settings stay. This can\'t be undone.'**
  String get resetLibraryBody;

  /// No description provided for @resetLibraryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetLibraryConfirm;

  /// No description provided for @libraryResetDone.
  ///
  /// In en, this message translates to:
  /// **'Library reset'**
  String get libraryResetDone;

  /// No description provided for @readingStats.
  ///
  /// In en, this message translates to:
  /// **'Reading stats'**
  String get readingStats;

  /// No description provided for @rateFourpages.
  ///
  /// In en, this message translates to:
  /// **'Rate Fourpages'**
  String get rateFourpages;

  /// No description provided for @shareFourpages.
  ///
  /// In en, this message translates to:
  /// **'Share Fourpages'**
  String get shareFourpages;

  /// No description provided for @supportTheProject.
  ///
  /// In en, this message translates to:
  /// **'Support the project'**
  String get supportTheProject;

  /// No description provided for @supportTheProjectCaption.
  ///
  /// In en, this message translates to:
  /// **'Fourpages is free, offline and has no ads. Rating it or sharing it with a friend keeps it going.'**
  String get supportTheProjectCaption;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the app store.'**
  String get storeUnavailable;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'I\'m reading with Fourpages, a free offline book reader: {url}'**
  String shareMessage(String url);

  /// No description provided for @statToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statToday;

  /// No description provided for @statThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get statThisWeek;

  /// No description provided for @statTotalReading.
  ///
  /// In en, this message translates to:
  /// **'Total reading'**
  String get statTotalReading;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statStreak;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @statSpeed.
  ///
  /// In en, this message translates to:
  /// **'Reading speed'**
  String get statSpeed;

  /// No description provided for @wordsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'{wpm} words/min'**
  String wordsPerMinute(int wpm);

  /// No description provided for @statBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get statBooks;

  /// No description provided for @booksStartedFinished.
  ///
  /// In en, this message translates to:
  /// **'{started} started · {finished} finished'**
  String booksStartedFinished(int started, int finished);

  /// No description provided for @statScreenTimeToday.
  ///
  /// In en, this message translates to:
  /// **'Screen time today'**
  String get statScreenTimeToday;

  /// No description provided for @statScreenTimeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total screen time'**
  String get statScreenTimeTotal;

  /// No description provided for @suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// No description provided for @timePerBook.
  ///
  /// In en, this message translates to:
  /// **'Time per book'**
  String get timePerBook;

  /// No description provided for @noReadingYet.
  ///
  /// In en, this message translates to:
  /// **'No reading recorded yet.'**
  String get noReadingYet;

  /// No description provided for @removedBook.
  ///
  /// In en, this message translates to:
  /// **'Removed book'**
  String get removedBook;

  /// No description provided for @sessionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String sessionsCount(int count);

  /// No description provided for @insightStartReading.
  ///
  /// In en, this message translates to:
  /// **'Open a book to start tracking your reading.'**
  String get insightStartReading;

  /// No description provided for @insightContinueBook.
  ///
  /// In en, this message translates to:
  /// **'Pick up {title} — you\'re {percent}% through.'**
  String insightContinueBook(String title, int percent);

  /// No description provided for @insightTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'About {time} left in {title} at your reading speed.'**
  String insightTimeLeft(String title, String time);

  /// No description provided for @insightStreak.
  ///
  /// In en, this message translates to:
  /// **'{days}-day reading streak — keep it going!'**
  String insightStreak(int days);

  /// No description provided for @insightBelowAverage.
  ///
  /// In en, this message translates to:
  /// **'You usually read about {minutes} min a day. A short session today keeps the habit.'**
  String insightBelowAverage(int minutes);

  /// No description provided for @insightFinishOne.
  ///
  /// In en, this message translates to:
  /// **'You have {count} books in progress — finishing one might feel great.'**
  String insightFinishOne(int count);

  /// No description provided for @widgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'Open a book in Fourpages'**
  String get widgetEmpty;

  /// No description provided for @define.
  ///
  /// In en, this message translates to:
  /// **'Define'**
  String get define;

  /// No description provided for @dictionaryOffline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the dictionary. Check your internet connection and try again.'**
  String get dictionaryOffline;

  /// No description provided for @noDefinitionFound.
  ///
  /// In en, this message translates to:
  /// **'No definition found for this word.'**
  String get noDefinitionFound;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @synonyms.
  ///
  /// In en, this message translates to:
  /// **'Synonyms'**
  String get synonyms;

  /// No description provided for @pagesLeftInBook.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page left in book} other{{count} pages left in book}}'**
  String pagesLeftInBook(int count);

  /// No description provided for @contentPadding.
  ///
  /// In en, this message translates to:
  /// **'Page margins'**
  String get contentPadding;

  /// No description provided for @contentPaddingCaption.
  ///
  /// In en, this message translates to:
  /// **'Space on the left and right of the book text'**
  String get contentPaddingCaption;

  /// No description provided for @newShelf.
  ///
  /// In en, this message translates to:
  /// **'New shelf'**
  String get newShelf;

  /// No description provided for @shelfName.
  ///
  /// In en, this message translates to:
  /// **'Shelf name'**
  String get shelfName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameShelf.
  ///
  /// In en, this message translates to:
  /// **'Rename shelf'**
  String get renameShelf;

  /// No description provided for @deleteShelf.
  ///
  /// In en, this message translates to:
  /// **'Delete shelf'**
  String get deleteShelf;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @deleteShelfBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be deleted. Its books stay in your library as unshelved.'**
  String deleteShelfBody(String name);

  /// No description provided for @shelfNameTaken.
  ///
  /// In en, this message translates to:
  /// **'You already have a shelf with this name'**
  String get shelfNameTaken;

  /// No description provided for @shelfOptions.
  ///
  /// In en, this message translates to:
  /// **'Shelf options'**
  String get shelfOptions;

  /// No description provided for @addBooksToShelf.
  ///
  /// In en, this message translates to:
  /// **'Add books to {name}'**
  String addBooksToShelf(String name);

  /// No description provided for @noBooksToAdd.
  ///
  /// In en, this message translates to:
  /// **'Every book is already on this shelf.'**
  String get noBooksToAdd;

  /// No description provided for @moveToShelf.
  ///
  /// In en, this message translates to:
  /// **'Move to shelf'**
  String get moveToShelf;

  /// No description provided for @removeFromShelf.
  ///
  /// In en, this message translates to:
  /// **'Remove from shelf'**
  String get removeFromShelf;

  /// No description provided for @dropToRemoveFromShelf.
  ///
  /// In en, this message translates to:
  /// **'Drop to unshelve'**
  String get dropToRemoveFromShelf;

  /// No description provided for @dropToCreateShelf.
  ///
  /// In en, this message translates to:
  /// **'Drop for new shelf'**
  String get dropToCreateShelf;

  /// No description provided for @emptyShelfHint.
  ///
  /// In en, this message translates to:
  /// **'Empty. Long-press a book and drag it here.'**
  String get emptyShelfHint;

  /// No description provided for @shelvesDragHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a cover and drag it onto another shelf to move it.'**
  String get shelvesDragHint;

  /// No description provided for @movedToShelf.
  ///
  /// In en, this message translates to:
  /// **'Moved to {name}'**
  String movedToShelf(String name);

  /// No description provided for @removedFromShelf.
  ///
  /// In en, this message translates to:
  /// **'Removed from {name}'**
  String removedFromShelf(String name);

  /// No description provided for @shelfCreated.
  ///
  /// In en, this message translates to:
  /// **'Created shelf \"{name}\"'**
  String shelfCreated(String name);

  /// No description provided for @shelfBookCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Book} other{{count} Books}}'**
  String shelfBookCount(int count);

  /// No description provided for @openBook.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openBook;

  /// No description provided for @noShelvesCreateOne.
  ///
  /// In en, this message translates to:
  /// **'No shelves yet. Tap New shelf to make your first one.'**
  String get noShelvesCreateOne;

  /// No description provided for @manageShelvesCaption.
  ///
  /// In en, this message translates to:
  /// **'Create, rename, reorder and delete shelves here. Move books between shelves on Library › Shelves.'**
  String get manageShelvesCaption;

  /// No description provided for @appGuide.
  ///
  /// In en, this message translates to:
  /// **'App guide'**
  String get appGuide;

  /// No description provided for @appGuideIntro.
  ///
  /// In en, this message translates to:
  /// **'Everything you can do in the app, and how to do it.'**
  String get appGuideIntro;

  /// No description provided for @guideAddingBooks.
  ///
  /// In en, this message translates to:
  /// **'Adding books'**
  String get guideAddingBooks;

  /// No description provided for @guideImportFiles.
  ///
  /// In en, this message translates to:
  /// **'Tap + at the top of Home or Library, then Choose files. EPUB and PDF open as they are; TXT, Markdown, HTML and DOCX are turned into books.'**
  String get guideImportFiles;

  /// No description provided for @guideScanFolder.
  ///
  /// In en, this message translates to:
  /// **'Tap + then Scan a folder to import every book inside it. Settings › Library lists scanned folders: rescan or stop tracking them there.'**
  String get guideScanFolder;

  /// No description provided for @guideFolderAccess.
  ///
  /// In en, this message translates to:
  /// **'On Android, allow Folder access in Settings so folders can be scanned.'**
  String get guideFolderAccess;

  /// No description provided for @guideHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home & search'**
  String get guideHomeTitle;

  /// No description provided for @guideRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent Reading shows the books you opened last. Tap one to pick up where you left off.'**
  String get guideRecent;

  /// No description provided for @guideSearchBooks.
  ///
  /// In en, this message translates to:
  /// **'Tap the search bar to find a book by title or author.'**
  String get guideSearchBooks;

  /// No description provided for @guideLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get guideLibraryTitle;

  /// No description provided for @guideLibraryTabs.
  ///
  /// In en, this message translates to:
  /// **'All Books lists every book, Shelves groups them, Folders shows where they came from.'**
  String get guideLibraryTabs;

  /// No description provided for @guideSort.
  ///
  /// In en, this message translates to:
  /// **'Tap the tab that\'s already selected to change the sort order (recently added, title, author, progress). Set the default in Settings.'**
  String get guideSort;

  /// No description provided for @guideFolders.
  ///
  /// In en, this message translates to:
  /// **'Tap a folder to see only its books in All Books. Tap Clear to see everything again.'**
  String get guideFolders;

  /// No description provided for @guideShelvesTitle.
  ///
  /// In en, this message translates to:
  /// **'Shelves'**
  String get guideShelvesTitle;

  /// No description provided for @guideNewShelf.
  ///
  /// In en, this message translates to:
  /// **'Library › Shelves › New shelf, or Settings › Shelves, to make a shelf.'**
  String get guideNewShelf;

  /// No description provided for @guideDragBook.
  ///
  /// In en, this message translates to:
  /// **'Long-press a book cover and drag it onto another shelf to move it. Drop it on Drop to unshelve to take it off its shelf, or on Drop for new shelf to start a shelf with it.'**
  String get guideDragBook;

  /// No description provided for @guideShelfMenu.
  ///
  /// In en, this message translates to:
  /// **'Tap ⋮ on a shelf to add books, rename it or delete it. Deleting a shelf keeps its books.'**
  String get guideShelfMenu;

  /// No description provided for @guideShelfOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap a shelf\'s name to see all its books. Long-press a book there to move it or remove it from the shelf.'**
  String get guideShelfOpen;

  /// No description provided for @guideLongPressList.
  ///
  /// In en, this message translates to:
  /// **'In All Books, long-press a book to put it on a shelf.'**
  String get guideLongPressList;

  /// No description provided for @guideReorderShelves.
  ///
  /// In en, this message translates to:
  /// **'Reorder shelves in Settings › Shelves by dragging the handle.'**
  String get guideReorderShelves;

  /// No description provided for @guideReaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get guideReaderTitle;

  /// No description provided for @guideTapControls.
  ///
  /// In en, this message translates to:
  /// **'Tap the page to show or hide the top and bottom bars.'**
  String get guideTapControls;

  /// No description provided for @guideTurnPages.
  ///
  /// In en, this message translates to:
  /// **'Swipe left or right to turn the page. Keyboard: arrow keys, Space, Page Up/Down.'**
  String get guideTurnPages;

  /// No description provided for @guideScrolledMode.
  ///
  /// In en, this message translates to:
  /// **'In Scrolled mode, scroll up and down; pull past the end of a chapter sideways until the ring fills to go to the next or previous one.'**
  String get guideScrolledMode;

  /// No description provided for @guideZoomStrip.
  ///
  /// In en, this message translates to:
  /// **'While the bars are showing, pages shrink into a strip: swipe it to look around, tap a page to go there.'**
  String get guideZoomStrip;

  /// No description provided for @guideScrubber.
  ///
  /// In en, this message translates to:
  /// **'Drag or tap the bar at the bottom to jump through the book. Tap the rest of the bottom pill for Chapters & Notes.'**
  String get guideScrubber;

  /// No description provided for @guideCustomize.
  ///
  /// In en, this message translates to:
  /// **'Aa in the top bar changes theme, font, text size, line spacing, alignment and reading mode for this book.'**
  String get guideCustomize;

  /// No description provided for @guideBookmark.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon to bookmark the page (keyboard: B).'**
  String get guideBookmark;

  /// No description provided for @guideSearchInBook.
  ///
  /// In en, this message translates to:
  /// **'Use the search icon in the top bar to search inside the book.'**
  String get guideSearchInBook;

  /// No description provided for @guideSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlights & notes'**
  String get guideSelectionTitle;

  /// No description provided for @guideSelectText.
  ///
  /// In en, this message translates to:
  /// **'Long-press a word to select it, then drag the handles to select more.'**
  String get guideSelectText;

  /// No description provided for @guideSelectionMenu.
  ///
  /// In en, this message translates to:
  /// **'From the menu pick a colour to highlight, or Add note, Copy, Search, Share and Define (dictionary).'**
  String get guideSelectionMenu;

  /// No description provided for @guideTapHighlight.
  ///
  /// In en, this message translates to:
  /// **'Tap a highlight to change its colour or remove it.'**
  String get guideTapHighlight;

  /// No description provided for @guideSavedTab.
  ///
  /// In en, this message translates to:
  /// **'The Saved tab collects your bookmarks, quotes (highlights) and notes from every book. Tap one to open the book there.'**
  String get guideSavedTab;

  /// No description provided for @guidePdfTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get guidePdfTitle;

  /// No description provided for @guidePdf.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom, drag to pan, double-tap to zoom in or out. Use Go to page to jump.'**
  String get guidePdf;

  /// No description provided for @guideSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get guideSettingsTitle;

  /// No description provided for @guideAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance: app theme (system, light, dark) and language.'**
  String get guideAppearance;

  /// No description provided for @guideReadingDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reading: theme, text size, spacing, alignment, mode and page margins for books you haven\'t changed yourself. Apply to all books overwrites every book.'**
  String get guideReadingDefaults;

  /// No description provided for @guideDynamicBackground.
  ///
  /// In en, this message translates to:
  /// **'Dynamic book background makes books follow the app theme: sepia when light, dark when dark.'**
  String get guideDynamicBackground;

  /// No description provided for @guideReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders: break reminders while reading, a daily reading reminder and its sound.'**
  String get guideReminders;

  /// No description provided for @guideHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics: vibration on/off, strength, and a buzz when swiping chapters.'**
  String get guideHaptics;

  /// No description provided for @guideLibrarySettings.
  ///
  /// In en, this message translates to:
  /// **'Library & storage: book count, default sort, folder access, scanned folders, reading stats, and Reset library (deletes every book).'**
  String get guideLibrarySettings;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready to install.'**
  String updateAvailableBody(String version);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @skipThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get skipThisVersion;

  /// No description provided for @downloadingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String downloadingUpdate(int percent);

  /// No description provided for @installUpdate.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get installUpdate;

  /// No description provided for @allowInstallsHint.
  ///
  /// In en, this message translates to:
  /// **'Allow Fourpages to install apps, then tap Install again.'**
  String get allowInstallsHint;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Check your connection.'**
  String get updateCheckFailed;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Try again.'**
  String get updateDownloadFailed;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get whatsNew;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @buildGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub build · updates from GitHub Releases'**
  String get buildGithub;

  /// No description provided for @buildPlaystore.
  ///
  /// In en, this message translates to:
  /// **'Play Store build · updates through Google Play'**
  String get buildPlaystore;

  /// No description provided for @supportOnKofi.
  ///
  /// In en, this message translates to:
  /// **'Support on Ko-fi'**
  String get supportOnKofi;

  /// No description provided for @supportOnKofiCaption.
  ///
  /// In en, this message translates to:
  /// **'Fourpages is free, offline and has no ads. A coffee keeps it going.'**
  String get supportOnKofiCaption;

  /// No description provided for @starOnGithub.
  ///
  /// In en, this message translates to:
  /// **'Star on GitHub'**
  String get starOnGithub;

  /// No description provided for @starOnGithubCaption.
  ///
  /// In en, this message translates to:
  /// **'Stars help other readers find the app. Translations and fixes are welcome there too.'**
  String get starOnGithubCaption;

  /// No description provided for @linkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get linkUnavailable;

  /// No description provided for @guideUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates & support'**
  String get guideUpdatesTitle;

  /// No description provided for @guideUpdates.
  ///
  /// In en, this message translates to:
  /// **'The app checks for a new version once a day. Settings › About › Check for updates checks right now.'**
  String get guideUpdates;

  /// No description provided for @guideSupport.
  ///
  /// In en, this message translates to:
  /// **'Settings › About: support the app on Ko-fi, star it on GitHub, rate or share it.'**
  String get guideSupport;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @noBookSelected.
  ///
  /// In en, this message translates to:
  /// **'Select a book to see its details'**
  String get noBookSelected;

  /// No description provided for @contents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get contents;

  /// No description provided for @readingSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get readingSettings;

  /// No description provided for @showContents.
  ///
  /// In en, this message translates to:
  /// **'Show contents'**
  String get showContents;

  /// No description provided for @hideContents.
  ///
  /// In en, this message translates to:
  /// **'Hide contents'**
  String get hideContents;

  /// No description provided for @showSettingsPane.
  ///
  /// In en, this message translates to:
  /// **'Show settings'**
  String get showSettingsPane;

  /// No description provided for @hideSettingsPane.
  ///
  /// In en, this message translates to:
  /// **'Hide settings'**
  String get hideSettingsPane;

  /// No description provided for @notOnAShelf.
  ///
  /// In en, this message translates to:
  /// **'Not on a shelf'**
  String get notOnAShelf;

  /// No description provided for @aboutThisBook.
  ///
  /// In en, this message translates to:
  /// **'About this book'**
  String get aboutThisBook;

  /// No description provided for @shareBookFile.
  ///
  /// In en, this message translates to:
  /// **'Share book file'**
  String get shareBookFile;

  /// No description provided for @couldNotShareBook.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share this book'**
  String get couldNotShareBook;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @removeFromLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed with its reading progress, highlights and bookmarks. The original file on your device is not deleted.'**
  String removeFromLibraryBody(String title);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Removed “{title}”'**
  String removedFromLibrary(String title);

  /// No description provided for @bookInfoPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get bookInfoPublisher;

  /// No description provided for @bookInfoPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get bookInfoPublished;

  /// No description provided for @bookInfoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get bookInfoLanguage;

  /// No description provided for @bookInfoFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get bookInfoFormat;

  /// No description provided for @bookInfoFileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get bookInfoFileSize;

  /// No description provided for @bookInfoShelf.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get bookInfoShelf;

  /// No description provided for @bookInfoSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get bookInfoSubjects;

  /// No description provided for @bookInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get bookInfoDescription;

  /// No description provided for @seekToPercent.
  ///
  /// In en, this message translates to:
  /// **'Release to go to {percent}%'**
  String seekToPercent(int percent);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
