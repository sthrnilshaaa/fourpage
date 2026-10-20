// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String percentComplete(int percent) {
    return '$percent% Complete';
  }

  @override
  String folderLabel(String name) {
    return 'Folder: $name';
  }

  @override
  String pageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String pageRangeHint(int total) {
    return '1 – $total';
  }

  @override
  String couldNotOpenPdf(String error) {
    return 'Couldn\'t open this PDF.\n$error';
  }

  @override
  String chapterBookmark(int number) {
    return 'Chapter $number Bookmark';
  }

  @override
  String chapterN(int number) {
    return 'Chapter $number';
  }

  @override
  String bookmarkAtPercent(int percent) {
    return 'Bookmark at $percent%';
  }

  @override
  String couldNotOpenBookFile(String error) {
    return 'Couldn\'t open this book\'s file.\n$error';
  }

  @override
  String percentRead(int percent) {
    return '$percent% read';
  }

  @override
  String importedBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count books',
      one: 'Imported 1 book',
    );
    return '$_temp0';
  }

  @override
  String filePickerError(String error) {
    return 'Couldn\'t open the file picker: $error';
  }

  @override
  String addedBook(String title) {
    return 'Added \"$title\"';
  }

  @override
  String addedBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count books',
      one: 'Added 1 book',
    );
    return '$_temp0';
  }

  @override
  String addedWithFailures(int added, int failed, String firstError) {
    return 'Added $added, $failed failed: $firstError';
  }

  @override
  String noBooksInFolder(String formats) {
    return 'No books found in that folder ($formats)';
  }

  @override
  String addedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count books from the folder',
      one: 'Added 1 book from the folder',
    );
    return '$_temp0';
  }

  @override
  String folderScanError(String error) {
    return 'Couldn\'t scan the folder: $error';
  }

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results in this book',
      one: '1 result in this book',
    );
    return '$_temp0';
  }

  @override
  String noResultsFor(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String noteN(int number) {
    return 'Note $number';
  }

  @override
  String chapterLabel(String number) {
    return 'Chapter $number';
  }

  @override
  String sectionLabel(String number) {
    return 'Section $number';
  }

  @override
  String get your => 'Your ';

  @override
  String get alwaysWithYou => '\nalways with you.';

  @override
  String get openYourBooksReadOfflineAnd =>
      'Open your books, read offline, and enjoy every page\nwithout distractions.';

  @override
  String get importYour => 'Import Your ';

  @override
  String get fourpagesSupportsEpubBooks => 'Fourpages supports EPUB books.';

  @override
  String get books => 'Books';

  @override
  String get skip => 'Skip →';

  @override
  String get getStarted => 'Get Started';

  @override
  String get selectFolders => 'Select Folders';

  @override
  String get addBooks => 'Add Books';

  @override
  String get unknownAuthor => 'Unknown Author';

  @override
  String get recentReading => 'Recent Reading';

  @override
  String get pickUpWhereYouLeftOff => 'Pick up where you left off';

  @override
  String get viewAllYourBooks => 'View all your books';

  @override
  String get noBooksInYourLibrary => 'No books in your library';

  @override
  String get importEpubBooksToStartYour =>
      'Import EPUB books to start your reading journey.';

  @override
  String get importBooks => 'Import Books';

  @override
  String get sortBy => 'Sort by';

  @override
  String get allBooks => 'All Books';

  @override
  String get shelves => 'Shelves';

  @override
  String get folders => 'Folders';

  @override
  String get noBooksFoundInThisFolder => 'No books found in this folder.';

  @override
  String get showAllBooks => 'Show all books';

  @override
  String get noBooksAvailableImportBooksTo =>
      'No books available.\nImport books to build your library!';

  @override
  String get clear => 'Clear';

  @override
  String get noShelvesYetImportBooksTo =>
      'No shelves yet.\nImport books to start filling them.';

  @override
  String get unshelved => 'Unshelved';

  @override
  String get noFoldersYetImportAFolder =>
      'No folders yet.\nImport a folder of EPUBs to see it here.';

  @override
  String get other => 'Other';

  @override
  String get fourpagesImported => 'Fourpages/Imported';

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get saved => 'Saved';

  @override
  String get settings => 'Settings';

  @override
  String get goToPage => 'Go to page';

  @override
  String get cancel => 'Cancel';

  @override
  String get go => 'Go';

  @override
  String get goBack => 'Go back';

  @override
  String get bookmarkedCurrentLocation => 'Bookmarked current location!';

  @override
  String get theme => 'Theme';

  @override
  String get fontStyle => 'Font Style';

  @override
  String get textSize => 'Text Size';

  @override
  String get alignment => 'Alignment';

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get removeBookmark => 'Remove Bookmark';

  @override
  String get vertical => 'Vertical';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get feedback => 'Feedback';

  @override
  String get feedbackIsnTAvailableYetCheck =>
      'Feedback isn\'t available yet - check back soon!';

  @override
  String get customization => 'Customization';

  @override
  String get bookmarkThisPage => 'Bookmark this page';

  @override
  String get searchInBook => 'Search in book';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get addNote => 'Add note';

  @override
  String get writeANote => 'Write a note…';

  @override
  String get save => 'Save';

  @override
  String get highlightRemoved => 'Highlight removed';

  @override
  String get undo => 'Undo';

  @override
  String get lastChapter => 'Last chapter';

  @override
  String get firstChapter => 'First chapter';

  @override
  String get releaseToOpen => 'Release to open';

  @override
  String get nextChapter => 'Next chapter';

  @override
  String get previousChapter => 'Previous chapter';

  @override
  String get stillOpeningThisBook => 'Still opening this book…';

  @override
  String get reload => 'Reload';

  @override
  String get chapters => 'Chapters';

  @override
  String get copy => 'Copy';

  @override
  String get search => 'Search';

  @override
  String get share => 'Share';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get quotes => 'Quotes';

  @override
  String get notes => 'Notes';

  @override
  String get noSavedQuotesYetHighlightText =>
      'No saved quotes yet.\nHighlight text while reading to save quotes!';

  @override
  String get noBookmarksSavedTapBookmarkWhile =>
      'No bookmarks saved.\nTap bookmark while reading to save pages!';

  @override
  String get noNotesCreatedYet => 'No notes created yet.';

  @override
  String get note => 'Note';

  @override
  String get searchBooks => 'Search books';

  @override
  String get noMatchingBooksFound => 'No matching books found';

  @override
  String get paper => 'Paper';

  @override
  String get sepia => 'Sepia';

  @override
  String get night => 'Night';

  @override
  String get forest => 'Forest';

  @override
  String get black => 'Black';

  @override
  String get applyToAllBooks => 'Apply to all books?';

  @override
  String get everyBookInYourLibraryWill =>
      'Every book in your library will use these reading settings. You can still change a single book from its reader menu.';

  @override
  String get apply => 'Apply';

  @override
  String get readingSettingsAppliedToAllBooks =>
      'Reading settings applied to all books';

  @override
  String get noEpubBooksFoundInThis => 'No EPUB books found in this folder';

  @override
  String get appearance => 'Appearance';

  @override
  String get appTheme => 'App theme';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get reading => 'Reading';

  @override
  String get defaultsForBooksYouHavenT =>
      'Defaults for books you haven\'t customised yet';

  @override
  String get bookTheme => 'Book theme';

  @override
  String get textSize2 => 'Text size';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get justified => 'Justified';

  @override
  String get centered => 'Centered';

  @override
  String get left => 'Left';

  @override
  String get readingMode => 'Reading mode';

  @override
  String get scrollChapter => 'Scroll chapter';

  @override
  String get pages => 'Pages';

  @override
  String get hapticsOnChapterSwipe => 'Haptics on chapter swipe';

  @override
  String get dynamicBookBackground => 'Dynamic book background';

  @override
  String get removeHighlight => 'Remove highlight';

  @override
  String get originalLayout => 'Original layout';

  @override
  String get fastLayout => 'Fast layout';

  @override
  String get openedInOriginalLayout =>
      'This book opens in its original layout (complex formatting)';

  @override
  String get dynamicBookBackgroundCaption =>
      'Sepia pages in light mode, dark pages in dark mode, following the app theme';

  @override
  String get applyToAllBooks2 => 'Apply to all books';

  @override
  String get libraryStorage => 'Library & storage';

  @override
  String get defaultSort => 'Default sort';

  @override
  String get folderAccess => 'Folder access';

  @override
  String get neededToFindBooksInsideFolders =>
      'Needed to find books inside folders you scan';

  @override
  String get allowed => 'Allowed';

  @override
  String get allow => 'Allow';

  @override
  String get scannedFolders => 'Scanned folders';

  @override
  String get noneYetAddOneFromThe =>
      'None yet - add one from the + button in Library';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get stopTrackingFolder => 'Stop tracking folder';

  @override
  String get about => 'About';

  @override
  String get privateByDesign => 'Private by design';

  @override
  String get booksNotesAndProgressAreStored =>
      'Books, notes and progress are stored only on this device. No account, no tracking.';

  @override
  String get formats => 'Formats';

  @override
  String get epub2AndEpub3 => 'EPUB 2 and EPUB 3';

  @override
  String get wordDocx => 'Word (.docx)';

  @override
  String get text => 'Text';

  @override
  String get markdown => 'Markdown';

  @override
  String get nothingImported => 'Nothing imported';

  @override
  String get thisFolderCanTBeRead =>
      'This folder can\'t be read. Allow folder access in Settings, or choose files instead.';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get titleAZ => 'Title (A–Z)';

  @override
  String get authorAZ => 'Author (A–Z)';

  @override
  String get readingProgress => 'Reading progress';

  @override
  String get allowAccessToYourBooks => 'Allow access to your books';

  @override
  String get notNow => 'Not now';

  @override
  String get openSettings => 'Open settings';

  @override
  String get importBooks2 => 'Import books';

  @override
  String get importing => 'Importing…';

  @override
  String get chooseFiles => 'Choose files';

  @override
  String get scanAFolder => 'Scan a folder';

  @override
  String get themingCustomization => 'Theming & Customization';

  @override
  String get screenMode => 'Screen mode';

  @override
  String get typeAWordOrSentenceTo =>
      'Type a word or sentence to search in book';

  @override
  String get loadingChapters => 'Loading chapters…';

  @override
  String get noNotesSavedInThisBook => 'No notes saved in this book.';

  @override
  String get tapPlayToStartListening => 'Tap play to start listening.';

  @override
  String get paginated => 'Paginated';

  @override
  String get scrolled => 'Scrolled';

  @override
  String get brightness => 'Brightness';

  @override
  String get untitled => 'Untitled';

  @override
  String get noNotesYetSelectTextWhile =>
      'No notes yet.\nSelect text while reading to add one.';

  @override
  String get allFilesAccessExplanation =>
      'Android hides EPUB files in folders from apps by default. To find the books inside a folder, Fourpages needs \"All files access\".\n\nTurn it on for Fourpages on the next screen, then come back.';

  @override
  String get importErrorLegacyDoc =>
      'Old Word (.doc) files aren\'t supported - save it as .docx or PDF.';

  @override
  String get importErrorUnknownType => 'This file type isn\'t supported.';

  @override
  String get importErrorDamaged => 'This file is damaged.';

  @override
  String get importErrorNotWord => 'Not a Word document.';

  @override
  String get importErrorEmpty => 'The file is empty.';

  @override
  String get importErrorPdfUnsupported =>
      'PDF isn\'t supported on this device yet.';

  @override
  String get reminderContinueTitle => 'Time to read';

  @override
  String reminderContinueBody(String title, int percent) {
    return 'Continue $title — $percent% done';
  }

  @override
  String get breakReminderTitle => 'Time for a break';

  @override
  String breakReminderBody(int minutes) {
    return 'You\'ve been reading for $minutes minutes. Rest your eyes for a moment.';
  }

  @override
  String get keepReading => 'Keep reading';

  @override
  String get takeABreak => 'Take a break';

  @override
  String get language => 'Language';

  @override
  String get moreLanguagesSoon => 'More languages coming soon';

  @override
  String get remindersAndNotifications => 'Reminders & notifications';

  @override
  String get breakReminder => 'Break reminder';

  @override
  String get breakReminderCaption =>
      'Suggest a pause after reading this long without a break';

  @override
  String get off => 'Off';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get durationUnderAMinute => '< 1 min';

  @override
  String get dailyReadingReminder => 'Daily reading reminder';

  @override
  String get dailyReadingReminderCaption =>
      'A notification to continue your current book';

  @override
  String get notificationSound => 'Notification sound';

  @override
  String get soundDefault => 'Default';

  @override
  String get soundSilent => 'Silent';

  @override
  String get soundCustom => 'Custom sound';

  @override
  String get soundChoose => 'Choose…';

  @override
  String get sendTestNotification => 'Send a test notification';

  @override
  String get testNotificationBody => 'Reminders will look like this.';

  @override
  String get notificationsBlocked =>
      'Notifications are turned off for Fourpages. Allow them in system settings.';

  @override
  String get haptics => 'Haptics';

  @override
  String get vibrationFeedback => 'Vibration feedback';

  @override
  String get vibrationStrength => 'Strength';

  @override
  String get strengthLight => 'Light';

  @override
  String get strengthMedium => 'Medium';

  @override
  String get strengthHeavy => 'Strong';

  @override
  String get resetLibrary => 'Reset library';

  @override
  String get resetLibraryTitle => 'Reset library?';

  @override
  String get resetLibraryBody =>
      'This removes every book, highlight, note, bookmark, reading progress and reading stat from this device. Your settings stay. This can\'t be undone.';

  @override
  String get resetLibraryConfirm => 'Reset';

  @override
  String get libraryResetDone => 'Library reset';

  @override
  String get readingStats => 'Reading stats';

  @override
  String get rateFourpages => 'Rate Fourpages';

  @override
  String get shareFourpages => 'Share Fourpages';

  @override
  String get supportTheProject => 'Support the project';

  @override
  String get supportTheProjectCaption =>
      'Fourpages is free, offline and has no ads. Rating it or sharing it with a friend keeps it going.';

  @override
  String get storeUnavailable => 'Couldn\'t open the app store.';

  @override
  String shareMessage(String url) {
    return 'I\'m reading with Fourpages, a free offline book reader: $url';
  }

  @override
  String get statToday => 'Today';

  @override
  String get statThisWeek => 'This week';

  @override
  String get statTotalReading => 'Total reading';

  @override
  String get statStreak => 'Streak';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get statSpeed => 'Reading speed';

  @override
  String wordsPerMinute(int wpm) {
    return '$wpm words/min';
  }

  @override
  String get statBooks => 'Books';

  @override
  String booksStartedFinished(int started, int finished) {
    return '$started started · $finished finished';
  }

  @override
  String get statScreenTimeToday => 'Screen time today';

  @override
  String get statScreenTimeTotal => 'Total screen time';

  @override
  String get suggestions => 'Suggestions';

  @override
  String get timePerBook => 'Time per book';

  @override
  String get noReadingYet => 'No reading recorded yet.';

  @override
  String get removedBook => 'Removed book';

  @override
  String sessionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get insightStartReading =>
      'Open a book to start tracking your reading.';

  @override
  String insightContinueBook(String title, int percent) {
    return 'Pick up $title — you\'re $percent% through.';
  }

  @override
  String insightTimeLeft(String title, String time) {
    return 'About $time left in $title at your reading speed.';
  }

  @override
  String insightStreak(int days) {
    return '$days-day reading streak — keep it going!';
  }

  @override
  String insightBelowAverage(int minutes) {
    return 'You usually read about $minutes min a day. A short session today keeps the habit.';
  }

  @override
  String insightFinishOne(int count) {
    return 'You have $count books in progress — finishing one might feel great.';
  }

  @override
  String get widgetEmpty => 'Open a book in Fourpages';

  @override
  String get define => 'Define';

  @override
  String get dictionaryOffline =>
      'Couldn\'t reach the dictionary. Check your internet connection and try again.';

  @override
  String get noDefinitionFound => 'No definition found for this word.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get synonyms => 'Synonyms';

  @override
  String pagesLeftInBook(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages left in book',
      one: '1 page left in book',
    );
    return '$_temp0';
  }

  @override
  String get contentPadding => 'Page margins';

  @override
  String get contentPaddingCaption =>
      'Space on the left and right of the book text';

  @override
  String get newShelf => 'New shelf';

  @override
  String get shelfName => 'Shelf name';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get renameShelf => 'Rename shelf';

  @override
  String get deleteShelf => 'Delete shelf';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String deleteShelfBody(String name) {
    return '\"$name\" will be deleted. Its books stay in your library as unshelved.';
  }

  @override
  String get shelfNameTaken => 'You already have a shelf with this name';

  @override
  String get shelfOptions => 'Shelf options';

  @override
  String addBooksToShelf(String name) {
    return 'Add books to $name';
  }

  @override
  String get noBooksToAdd => 'Every book is already on this shelf.';

  @override
  String get moveToShelf => 'Move to shelf';

  @override
  String get removeFromShelf => 'Remove from shelf';

  @override
  String get dropToRemoveFromShelf => 'Drop to unshelve';

  @override
  String get dropToCreateShelf => 'Drop for new shelf';

  @override
  String get emptyShelfHint => 'Empty. Long-press a book and drag it here.';

  @override
  String get shelvesDragHint =>
      'Long-press a cover and drag it onto another shelf to move it.';

  @override
  String movedToShelf(String name) {
    return 'Moved to $name';
  }

  @override
  String removedFromShelf(String name) {
    return 'Removed from $name';
  }

  @override
  String shelfCreated(String name) {
    return 'Created shelf \"$name\"';
  }

  @override
  String shelfBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Books',
      one: '1 Book',
    );
    return '$_temp0';
  }

  @override
  String get openBook => 'Open';

  @override
  String get noShelvesCreateOne =>
      'No shelves yet. Tap New shelf to make your first one.';

  @override
  String get manageShelvesCaption =>
      'Create, rename, reorder and delete shelves here. Move books between shelves on Library › Shelves.';

  @override
  String get appGuide => 'App guide';

  @override
  String get appGuideIntro =>
      'Everything you can do in the app, and how to do it.';

  @override
  String get guideAddingBooks => 'Adding books';

  @override
  String get guideImportFiles =>
      'Tap + at the top of Home or Library, then Choose files. EPUB and PDF open as they are; TXT, Markdown, HTML and DOCX are turned into books.';

  @override
  String get guideScanFolder =>
      'Tap + then Scan a folder to import every book inside it. Settings › Library lists scanned folders: rescan or stop tracking them there.';

  @override
  String get guideFolderAccess =>
      'On Android, allow Folder access in Settings so folders can be scanned.';

  @override
  String get guideHomeTitle => 'Home & search';

  @override
  String get guideRecent =>
      'Recent Reading shows the books you opened last. Tap one to pick up where you left off.';

  @override
  String get guideSearchBooks =>
      'Tap the search bar to find a book by title or author.';

  @override
  String get guideLibraryTitle => 'Library';

  @override
  String get guideLibraryTabs =>
      'All Books lists every book, Shelves groups them, Folders shows where they came from.';

  @override
  String get guideSort =>
      'Tap the tab that\'s already selected to change the sort order (recently added, title, author, progress). Set the default in Settings.';

  @override
  String get guideFolders =>
      'Tap a folder to see only its books in All Books. Tap Clear to see everything again.';

  @override
  String get guideShelvesTitle => 'Shelves';

  @override
  String get guideNewShelf =>
      'Library › Shelves › New shelf, or Settings › Shelves, to make a shelf.';

  @override
  String get guideDragBook =>
      'Long-press a book cover and drag it onto another shelf to move it. Drop it on Drop to unshelve to take it off its shelf, or on Drop for new shelf to start a shelf with it.';

  @override
  String get guideShelfMenu =>
      'Tap ⋮ on a shelf to add books, rename it or delete it. Deleting a shelf keeps its books.';

  @override
  String get guideShelfOpen =>
      'Tap a shelf\'s name to see all its books. Long-press a book there to move it or remove it from the shelf.';

  @override
  String get guideLongPressList =>
      'In All Books, long-press a book to put it on a shelf.';

  @override
  String get guideReorderShelves =>
      'Reorder shelves in Settings › Shelves by dragging the handle.';

  @override
  String get guideReaderTitle => 'Reading';

  @override
  String get guideTapControls =>
      'Tap the page to show or hide the top and bottom bars.';

  @override
  String get guideTurnPages =>
      'Swipe left or right to turn the page. Keyboard: arrow keys, Space, Page Up/Down.';

  @override
  String get guideScrolledMode =>
      'In Scrolled mode, scroll up and down; pull past the end of a chapter sideways until the ring fills to go to the next or previous one.';

  @override
  String get guideZoomStrip =>
      'While the bars are showing, pages shrink into a strip: swipe it to look around, tap a page to go there.';

  @override
  String get guideScrubber =>
      'Drag or tap the bar at the bottom to jump through the book. Tap the rest of the bottom pill for Chapters & Notes.';

  @override
  String get guideCustomize =>
      'Aa in the top bar changes theme, font, text size, line spacing, alignment and reading mode for this book.';

  @override
  String get guideBookmark =>
      'Tap the bookmark icon to bookmark the page (keyboard: B).';

  @override
  String get guideSearchInBook =>
      'Use the search icon in the top bar to search inside the book.';

  @override
  String get guideSelectionTitle => 'Highlights & notes';

  @override
  String get guideSelectText =>
      'Long-press a word to select it, then drag the handles to select more.';

  @override
  String get guideSelectionMenu =>
      'From the menu pick a colour to highlight, or Add note, Copy, Search, Share and Define (dictionary).';

  @override
  String get guideTapHighlight =>
      'Tap a highlight to change its colour or remove it.';

  @override
  String get guideSavedTab =>
      'The Saved tab collects your bookmarks, quotes (highlights) and notes from every book. Tap one to open the book there.';

  @override
  String get guidePdfTitle => 'PDF';

  @override
  String get guidePdf =>
      'Pinch to zoom, drag to pan, double-tap to zoom in or out. Use Go to page to jump.';

  @override
  String get guideSettingsTitle => 'Settings';

  @override
  String get guideAppearance =>
      'Appearance: app theme (system, light, dark) and language.';

  @override
  String get guideReadingDefaults =>
      'Reading: theme, text size, spacing, alignment, mode and page margins for books you haven\'t changed yourself. Apply to all books overwrites every book.';

  @override
  String get guideDynamicBackground =>
      'Dynamic book background makes books follow the app theme: sepia when light, dark when dark.';

  @override
  String get guideReminders =>
      'Reminders: break reminders while reading, a daily reading reminder and its sound.';

  @override
  String get guideHaptics =>
      'Haptics: vibration on/off, strength, and a buzz when swiping chapters.';

  @override
  String get guideLibrarySettings =>
      'Library & storage: book count, default sort, folder access, scanned folders, reading stats, and Reset library (deletes every book).';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String version) {
    return 'Version $version is ready to install.';
  }

  @override
  String get updateNow => 'Update';

  @override
  String get later => 'Later';

  @override
  String get skipThisVersion => 'Skip this version';

  @override
  String downloadingUpdate(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get installUpdate => 'Install';

  @override
  String get allowInstallsHint =>
      'Allow Fourpages to install apps, then tap Install again.';

  @override
  String get upToDate => 'You\'re on the latest version';

  @override
  String get updateCheckFailed =>
      'Couldn\'t check for updates. Check your connection.';

  @override
  String get updateDownloadFailed => 'Download failed. Try again.';

  @override
  String get whatsNew => 'What\'s new';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get buildGithub => 'GitHub build · updates from GitHub Releases';

  @override
  String get buildPlaystore => 'Play Store build · updates through Google Play';

  @override
  String get supportOnKofi => 'Support on Ko-fi';

  @override
  String get supportOnKofiCaption =>
      'Fourpages is free, offline and has no ads. A coffee keeps it going.';

  @override
  String get starOnGithub => 'Star on GitHub';

  @override
  String get starOnGithubCaption =>
      'Stars help other readers find the app. Translations and fixes are welcome there too.';

  @override
  String get linkUnavailable => 'Couldn\'t open the link';

  @override
  String get guideUpdatesTitle => 'Updates & support';

  @override
  String get guideUpdates =>
      'The app checks for a new version once a day. Settings › About › Check for updates checks right now.';

  @override
  String get guideSupport =>
      'Settings › About: support the app on Ko-fi, star it on GitHub, rate or share it.';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get noBookSelected => 'Select a book to see its details';

  @override
  String get contents => 'Contents';

  @override
  String get readingSettings => 'Reading settings';

  @override
  String get showContents => 'Show contents';

  @override
  String get hideContents => 'Hide contents';

  @override
  String get showSettingsPane => 'Show settings';

  @override
  String get hideSettingsPane => 'Hide settings';

  @override
  String get notOnAShelf => 'Not on a shelf';

  @override
  String get aboutThisBook => 'About this book';

  @override
  String get shareBookFile => 'Share book file';

  @override
  String get couldNotShareBook => 'Couldn\'t share this book';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String removeFromLibraryBody(String title) {
    return '“$title” will be removed with its reading progress, highlights and bookmarks. The original file on your device is not deleted.';
  }

  @override
  String get remove => 'Remove';

  @override
  String removedFromLibrary(String title) {
    return 'Removed “$title”';
  }

  @override
  String get bookInfoPublisher => 'Publisher';

  @override
  String get bookInfoPublished => 'Published';

  @override
  String get bookInfoLanguage => 'Language';

  @override
  String get bookInfoFormat => 'Format';

  @override
  String get bookInfoFileSize => 'File size';

  @override
  String get bookInfoShelf => 'Shelf';

  @override
  String get bookInfoSubjects => 'Subjects';

  @override
  String get bookInfoDescription => 'Description';

  @override
  String pagesLeftShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left',
      one: '1 left',
    );
    return '$_temp0';
  }
}
