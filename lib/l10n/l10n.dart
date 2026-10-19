/// App-wide access to translated strings.
///
/// Widgets can use `AppLocalizations.of(context)`, but much UI text is built
/// in helpers without a BuildContext (snackbar helpers, sort labels), so the
/// app also keeps the active localizations here, updated by MaterialApp's
/// builder whenever the locale changes. Strings live in lib/l10n/app_*.arb.
library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

AppLocalizations? _current;

/// Translated strings for the active locale (English until the app builds).
AppLocalizations get l10n => _current ?? lookupAppLocalizations(const Locale('en'));

/// Called from MaterialApp.builder with the resolved localizations.
void updateL10n(AppLocalizations value) => _current = value;
