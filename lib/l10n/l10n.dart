import 'dart:ui';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Get localized strings without BuildContext.
/// Works in both main isolate and service isolate.
AppLocalizations tr(String languageCode) {
  return lookupAppLocalizations(Locale(languageCode));
}
