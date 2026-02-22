// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'DroidClaw';

  @override
  String get chatTitle => 'DroidClaw';

  @override
  String get chatConversations => 'Unterhaltungen';

  @override
  String get chatNewSession => 'Neue Sitzung';

  @override
  String get chatSettings => 'Einstellungen';

  @override
  String get chatEmptyTitle => 'DroidClaw';

  @override
  String get chatEmptySubtitle =>
      'Ihr persönlicher KI-Assistent.\nGeben Sie eine Nachricht ein, um zu beginnen.';

  @override
  String get chatInputHint => 'Nachricht an DroidClaw...';

  @override
  String get chatVoiceInput => 'Spracheingabe';

  @override
  String get chatSend => 'Senden';

  @override
  String get chatCopied => 'In die Zwischenablage kopiert';

  @override
  String chatCalling(String name) {
    return '$name wird aufgerufen...';
  }

  @override
  String get statusThinking => 'Denkt nach...';

  @override
  String statusThinkingStep(int step) {
    return 'Denkt nach (Schritt $step)...';
  }

  @override
  String get statusSummarizing => 'Unterhaltung wird zusammengefasst...';

  @override
  String statusUsingTool(String name) {
    return '$name wird verwendet...';
  }

  @override
  String statusGotResult(String name) {
    return 'Ergebnis von $name erhalten';
  }

  @override
  String get statusProcessing => 'Wird verarbeitet...';

  @override
  String get historyTitle => 'Unterhaltungen';

  @override
  String get historySectionChat => 'Chat';

  @override
  String get historySectionCron => 'Geplante Eingabeaufforderungen';

  @override
  String get historySectionTelegram => 'Telegram';

  @override
  String get historyEmpty => 'Noch keine Unterhaltungen';

  @override
  String historyExecutions(int count, String date) {
    return '$count Ausführungen - Letzte: $date';
  }

  @override
  String historyMessages(int count) {
    return '$count Nachrichten';
  }

  @override
  String get historyNewConversation => 'Neue Unterhaltung';

  @override
  String get historyScheduledPrompt => 'Geplante Eingabeaufforderung';

  @override
  String get historyNoExecutions => 'Noch keine Ausführungen';

  @override
  String get historyDeleteTitle => 'Unterhaltung löschen?';

  @override
  String historyDeleteContent(String title) {
    return '\"$title\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get historyToday => 'Heute';

  @override
  String get historyYesterday => 'Gestern';

  @override
  String historyError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get onboardWelcome => 'Willkommen bei DroidClaw';

  @override
  String get onboardSubtitle =>
      'Ihr persönlicher KI-Assistent auf Android.\nRichten wir Ihren LLM-Anbieter ein, um zu beginnen.';

  @override
  String get onboardGetStarted => 'Erste Schritte';

  @override
  String get onboardChooseProvider => 'Wählen Sie einen Anbieter';

  @override
  String get onboardChooseProviderSubtitle =>
      'Wählen Sie aus, welchen LLM-Anbieter Sie verwenden möchten.';

  @override
  String get onboardNext => 'Weiter';

  @override
  String get onboardEnterApiKey => 'Geben Sie Ihren API-Schlüssel ein';

  @override
  String get onboardApiKeySecure =>
      'Ihr Schlüssel wird sicher auf dem Gerät gespeichert.';

  @override
  String get onboardApiKeyLabel => 'API-Schlüssel';

  @override
  String get onboardTestConnection => 'Verbindung testen';

  @override
  String get onboardFinishSetup => 'Einrichtung abschließen';

  @override
  String onboardTestSuccess(String response) {
    return 'Verbunden! Antwort: $response';
  }

  @override
  String get onboardEnterApiKeyError =>
      'Bitte geben Sie einen API-Schlüssel ein';

  @override
  String get providerOpenRouter => 'OpenRouter';

  @override
  String get providerOpenRouterDesc =>
      'Zugriff auf viele Modelle mit einem API-Schlüssel';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerAnthropicDesc => 'Direkter Zugriff auf Claude-Modelle';

  @override
  String get providerOpenAI => 'OpenAI';

  @override
  String get providerOpenAIDesc => 'Zugriff auf GPT-Modelle';

  @override
  String get providerGroq => 'Groq';

  @override
  String get providerGroqDesc => 'Schnelle Inferenz für offene Modelle';

  @override
  String get providerGemini => 'Google Gemini';

  @override
  String get providerGeminiDesc =>
      'Google-KI-Modelle mit kostenlosem Kontingent';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionProvider => 'LLM-Anbieter';

  @override
  String get settingsProvider => 'Anbieter';

  @override
  String get settingsModel => 'Modell';

  @override
  String get settingsSectionAgent => 'Agent';

  @override
  String get settingsMaxTokens => 'Maximale Token';

  @override
  String get settingsTemperature => 'Temperatur';

  @override
  String get settingsMaxToolIterations => 'Maximale Werkzeugiterationen';

  @override
  String get settingsSectionTools => 'Werkzeuge';

  @override
  String get settingsManageTools => 'Werkzeuge verwalten';

  @override
  String get settingsManageToolsSubtitle =>
      'Agentenwerkzeuge aktivieren oder deaktivieren';

  @override
  String get settingsWebSearch => 'Websuche';

  @override
  String get settingsWebSearchSubtitle => 'Brave Search API konfigurieren';

  @override
  String get settingsRouting => 'Routenplanung';

  @override
  String get settingsRoutingSubtitle => 'Routen- und ÖPNV-APIs konfigurieren';

  @override
  String get settingsScheduledPrompts => 'Geplante Eingabeaufforderungen';

  @override
  String get settingsScheduledPromptsSubtitle =>
      'Automatisierte wiederkehrende Aufgaben';

  @override
  String get settingsSectionChannels => 'Kanäle';

  @override
  String get settingsTelegramBot => 'Telegram-Bot';

  @override
  String get settingsTelegramRunning => 'Läuft';

  @override
  String get settingsTelegramDisabled => 'Deaktiviert';

  @override
  String get settingsSkills => 'Fähigkeiten';

  @override
  String get settingsSkillsSubtitle => 'Installierte Fähigkeiten verwalten';

  @override
  String get settingsSectionAbout => 'Über';

  @override
  String get providerConfigTitle => 'Anbieter-Konfiguration';

  @override
  String get providerConfigProviderLabel => 'Anbieter';

  @override
  String get providerConfigApiKeyLabel => 'API-Schlüssel';

  @override
  String get providerConfigModelLabel => 'Modell (optional)';

  @override
  String get providerConfigModelHint => 'z.B. claude-sonnet-4-20250514';

  @override
  String get providerConfigApiBaseLabel => 'API-Basis-URL (optional)';

  @override
  String get providerConfigApiBaseHint => 'Leer lassen für Standardwert';

  @override
  String get providerConfigTestConnection => 'Verbindung testen';

  @override
  String get providerConfigSave => 'Speichern';

  @override
  String get providerConfigSaved => 'Einstellungen gespeichert';

  @override
  String providerConfigTestSuccess(String response) {
    return 'Verbindung erfolgreich! Antwort: $response';
  }

  @override
  String providerConfigTestFailed(String error) {
    return 'Verbindung fehlgeschlagen: $error';
  }

  @override
  String get telegramTitle => 'Telegram-Bot';

  @override
  String get telegramBotToken => 'Bot-Token';

  @override
  String get telegramBotTokenHelper =>
      'Erhalten Sie einen von @BotFather auf Telegram';

  @override
  String get telegramTestConnection => 'Verbindung testen';

  @override
  String telegramTestSuccess(String username) {
    return 'Verbunden! Bot: @$username';
  }

  @override
  String get telegramEnableBot => 'Bot aktivieren';

  @override
  String get telegramBotRunning => 'Bot läuft';

  @override
  String get telegramBotStarting => 'Wird gestartet...';

  @override
  String get telegramBotDisabled => 'Bot ist deaktiviert';

  @override
  String get telegramBotActive => 'Bot aktiv';

  @override
  String telegramMessages(int count) {
    return '$count Nachrichten';
  }

  @override
  String telegramLastMessage(String time) {
    return 'Letzte: $time';
  }

  @override
  String get telegramAllowedUsers => 'Erlaubte Benutzer (optional)';

  @override
  String get telegramAllowedUsersHelper =>
      'Durch Komma getrennte Telegram-Benutzernamen. Leer lassen für alle.';

  @override
  String get telegramAllowedUsersHint => 'alice, bob, charlie';

  @override
  String get telegramSaveUsers => 'Benutzer speichern';

  @override
  String get telegramUsersUpdated => 'Erlaubte Benutzer aktualisiert';

  @override
  String get telegramEnterToken => 'Bitte geben Sie zuerst ein Bot-Token ein';

  @override
  String get telegramEnterTokenError => 'Bitte geben Sie ein Bot-Token ein';

  @override
  String get telegramHowToSetup => 'So richten Sie es ein';

  @override
  String get telegramSetupSteps =>
      '1. Öffnen Sie Telegram und suchen Sie nach @BotFather\n2. Senden Sie /newbot und folgen Sie den Anweisungen\n3. Kopieren Sie das Bot-Token und fügen Sie es oben ein\n4. Testen Sie die Verbindung und aktivieren Sie dann den Bot\n5. Senden Sie eine Nachricht an Ihren Bot auf Telegram!';

  @override
  String get webSearchTitle => 'Websuche';

  @override
  String get webSearchDescription =>
      'Websuche funktioniert ohne Schlüssel mit DuckDuckGo, aber Brave Search liefert schnellere Ergebnisse höherer Qualität.';

  @override
  String get webSearchApiKeyLabel => 'Brave Search API-Schlüssel';

  @override
  String get webSearchTestSearch => 'Suche testen';

  @override
  String get webSearchSave => 'Speichern';

  @override
  String get webSearchSaved => 'Brave API-Schlüssel gespeichert';

  @override
  String get webSearchTestSuccess => 'Suche erfolgreich! Ergebnisse empfangen.';

  @override
  String get routingTitle => 'Routenplanung & ÖPNV';

  @override
  String get routingSave => 'Speichern';

  @override
  String get routingSaved => 'API-Schlüssel gespeichert';

  @override
  String get routingOrsTitle => 'OpenRouteService';

  @override
  String get routingOrsDesc =>
      'Kostenloser API-Schlüssel bei openrouteservice.org für Auto-, Fahrrad- und Fußgängerrouten.';

  @override
  String get routingOrsKeyLabel => 'ORS API-Schlüssel';

  @override
  String get routingOrsTestRoute => 'Route testen (Paris → Versailles)';

  @override
  String get routingOrsTestGeocode =>
      'Geokodierung testen (Tour Eiffel, Paris)';

  @override
  String get routingSncfTitle => 'SNCF (Nationale Züge)';

  @override
  String get routingSncfDesc =>
      'Kostenloser API-Schlüssel bei ressources.data.sncf.com für TGV-, TER- und Intercités-Strecken in ganz Frankreich.';

  @override
  String get routingSncfKeyLabel => 'SNCF API-Schlüssel';

  @override
  String get routingSncfTestTransit => 'ÖPNV testen (Paris → Lyon)';

  @override
  String get routingPrimTitle => 'PRIM / IDFM (Île-de-France)';

  @override
  String get routingPrimDesc =>
      'Kostenloser API-Schlüssel bei prim.iledefrance-mobilites.fr für Métro, RER, Bus und Straßenbahn in der Region Paris.';

  @override
  String get routingPrimKeyLabel => 'PRIM API-Schlüssel';

  @override
  String get routingPrimTestTransit => 'ÖPNV testen (Gare de Lyon → Châtelet)';

  @override
  String get cronTitle => 'Geplante Eingabeaufforderungen';

  @override
  String get cronEmpty => 'Keine geplanten Eingabeaufforderungen';

  @override
  String get cronEmptySubtitle =>
      'Tippen Sie auf +, um eine wiederkehrende Eingabeaufforderung zu erstellen.\nDie KI wird sie automatisch nach Zeitplan ausführen.';

  @override
  String get cronServiceRunning => 'Hintergrunddienst läuft';

  @override
  String get cronServiceNotRunning => 'Hintergrunddienst läuft nicht';

  @override
  String get cronNoPromptsEnabled => 'Keine Eingabeaufforderungen aktiviert';

  @override
  String get cronNeverRan => 'Nie ausgeführt';

  @override
  String get cronDeleteTitle => 'Geplante Eingabeaufforderung löschen?';

  @override
  String cronDeleteContent(String name) {
    return '\"$name\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get cronViewExecutions => 'Ausführungen anzeigen';

  @override
  String get cronEditTitle => 'Neue Eingabeaufforderung';

  @override
  String get cronEditTitleEdit => 'Eingabeaufforderung bearbeiten';

  @override
  String get cronEditSave => 'Speichern';

  @override
  String get cronEditName => 'Name';

  @override
  String get cronEditNameHint => 'z.B. Täglicher Nachrichtenüberblick';

  @override
  String get cronEditPrompt => 'Eingabeaufforderung';

  @override
  String get cronEditPromptHint => 'Was soll die KI tun?';

  @override
  String get cronEditSchedule => 'Zeitplan';

  @override
  String get cronEditInterval => 'Intervall';

  @override
  String get cronEditSpecificTimes => 'Bestimmte Zeiten';

  @override
  String get cronEditAddTime => 'Zeit hinzufügen';

  @override
  String get cronEditDays => 'Tage';

  @override
  String get cronEditConversation => 'Unterhaltung';

  @override
  String get cronEditNewEach => 'Jedes Mal neue Unterhaltung';

  @override
  String get cronEditNewEachSubtitle => 'Jede Ausführung ist unabhängig';

  @override
  String get cronEditSameThread => 'In gleichem Thread fortsetzen';

  @override
  String get cronEditSameThreadSubtitle =>
      'Die KI erinnert sich an vorherige Ausführungen';

  @override
  String get cronEditNameRequired =>
      'Name und Eingabeaufforderung sind erforderlich';

  @override
  String get cronEditTimeRequired => 'Fügen Sie mindestens eine Zeit hinzu';

  @override
  String get cronEditInterval15 => '15 Min.';

  @override
  String get cronEditInterval30 => '30 Min.';

  @override
  String get cronEditInterval1h => '1 Stunde';

  @override
  String get cronEditInterval2h => '2 Stunden';

  @override
  String get cronEditInterval6h => '6 Stunden';

  @override
  String get cronEditInterval12h => '12 Stunden';

  @override
  String get cronEditInterval24h => '24 Stunden';

  @override
  String get cronEditMon => 'Mo';

  @override
  String get cronEditTue => 'Di';

  @override
  String get cronEditWed => 'Mi';

  @override
  String get cronEditThu => 'Do';

  @override
  String get cronEditFri => 'Fr';

  @override
  String get cronEditSat => 'Sa';

  @override
  String get cronEditSun => 'So';

  @override
  String cronDisplayEveryMinutes(int minutes) {
    return 'Alle $minutes Min.';
  }

  @override
  String get cronDisplayEveryHour => 'Jede Stunde';

  @override
  String cronDisplayEveryHours(int hours) {
    return 'Alle $hours Stunden';
  }

  @override
  String cronDisplayDailyAt(String times) {
    return 'Täglich um $times';
  }

  @override
  String cronDisplayAt(String times) {
    return 'Um $times';
  }

  @override
  String get skillsTitle => 'Fähigkeiten';

  @override
  String get skillsGithubUrl => 'GitHub-URL';

  @override
  String get skillsGithubUrlHint =>
      'https://github.com/user/repo/blob/main/SKILL.md';

  @override
  String get skillsInstall => 'Installieren';

  @override
  String get skillsNoSkills => 'Keine Fähigkeiten installiert';

  @override
  String skillsInstalled(String name) {
    return 'Fähigkeit installiert: $name';
  }

  @override
  String skillsInstallFailed(String error) {
    return 'Installation fehlgeschlagen: $error';
  }

  @override
  String get skillsUninstallTitle => 'Fähigkeit deinstallieren';

  @override
  String skillsUninstallContent(String name) {
    return '\"$name\" entfernen?';
  }

  @override
  String get skillsUninstall => 'Deinstallieren';

  @override
  String skillsUninstalled(String name) {
    return 'Deinstalliert: $name';
  }

  @override
  String skillsUninstallFailed(String error) {
    return 'Deinstallation fehlgeschlagen: $error';
  }

  @override
  String get toolsTitle => 'Werkzeuge verwalten';

  @override
  String get toolWebSearch => 'Websuche';

  @override
  String get toolWebSearchDesc => 'Durchsuchen Sie das Web über Brave API';

  @override
  String get toolWebScrape => 'Web-Scraping';

  @override
  String get toolWebScrapeDesc =>
      'Leichtgewichtiges Seiten-Scraping (HTTP + Markdown)';

  @override
  String get toolWebScrapeJs => 'Web-Scraping (JS)';

  @override
  String get toolWebScrapeJsDesc =>
      'Umfangreiches JS-gerendertes Seiten-Scraping (WebView)';

  @override
  String get toolFile => 'Dateizugriff';

  @override
  String get toolFileDesc => 'Dateien im Arbeitsbereich lesen und schreiben';

  @override
  String get toolLocation => 'GPS-Standort';

  @override
  String get toolLocationDesc => 'Auf GPS-Koordinaten des Geräts zugreifen';

  @override
  String get toolAddress => 'Reverse-Geokodierung';

  @override
  String get toolAddressDesc => 'GPS-Koordinaten in Adresse umwandeln';

  @override
  String get toolSubagent => 'Unteragent';

  @override
  String get toolSubagentDesc =>
      'Unteraufgaben für komplexe Anfragen erstellen';

  @override
  String get toolClipboard => 'Zwischenablage';

  @override
  String get toolClipboardDesc =>
      'Zwischenablage des Geräts lesen und schreiben';

  @override
  String get toolDatetime => 'Datum & Uhrzeit';

  @override
  String get toolDatetimeDesc =>
      'Aktuelles Datum, Uhrzeit, Wochentag, Zeitzone abrufen';

  @override
  String get toolDeviceInfo => 'Geräteinformationen';

  @override
  String get toolDeviceInfoDesc => 'Akku, Konnektivität, Gerätemodell';

  @override
  String get toolSpeak => 'Text-zu-Sprache';

  @override
  String get toolSpeakDesc => 'Text laut vorlesen (nur im Vordergrund)';

  @override
  String get toolOpenApp => 'App / URL öffnen';

  @override
  String get toolOpenAppDesc =>
      'URLs, Telefon, Karten, E-Mail auf dem Gerät öffnen';

  @override
  String get toolAlarm => 'Wecker / Timer';

  @override
  String get toolAlarmDesc =>
      'Wecker und Timer über die System-Uhr-App einstellen';

  @override
  String get toolNotifications => 'Benachrichtigungen';

  @override
  String get toolNotificationsDesc =>
      'Lokale Benachrichtigungen / Erinnerungen erstellen und planen';

  @override
  String get toolContacts => 'Kontakte';

  @override
  String get toolContactsDesc =>
      'Gerätekontakte suchen und lesen (schreibgeschützt)';

  @override
  String get toolCalendar => 'Kalender';

  @override
  String get toolCalendarDesc => 'Kalenderereignisse lesen und erstellen';

  @override
  String get toolOcr => 'OCR';

  @override
  String get toolOcrDesc =>
      'Text aus Bildern extrahieren (geräteinterne ML Kit)';

  @override
  String get toolQrGenerate => 'QR-Code';

  @override
  String get toolQrGenerateDesc =>
      'QR-Code-Bilder aus Text oder URLs generieren';

  @override
  String get toolPickImage => 'Bildauswahl';

  @override
  String get toolPickImageDesc =>
      'Fotos aus der Galerie auswählen oder mit der Kamera aufnehmen';

  @override
  String get toolVolumeControl => 'Lautstärkeregelung';

  @override
  String get toolVolumeControlDesc =>
      'Lautstärkepegel des Geräts lesen und anpassen (Wecker, Medien usw.)';

  @override
  String get toolGeocode => 'Geokodierung';

  @override
  String get toolGeocodeDesc =>
      'Adresse in GPS-Koordinaten umwandeln (OpenRouteService)';

  @override
  String get toolDirections => 'Wegbeschreibung';

  @override
  String get toolDirectionsDesc =>
      'Routenberechnung (Auto, Fahrrad, zu Fuß) über OpenRouteService';

  @override
  String get toolTransit => 'Öffentlicher Nahverkehr';

  @override
  String get toolTransitDesc =>
      'Metro-, RER-, Bus-, Zugverbindungen (SNCF + IDFM)';

  @override
  String get toolWeather => 'Wetter';

  @override
  String get toolWeatherDesc =>
      'Wettervorhersage über Open-Meteo (Météo-France-Modelle)';

  @override
  String get weatherClearSky => 'Klarer Himmel';

  @override
  String get weatherMainlyClear => 'Überwiegend klar';

  @override
  String get weatherPartlyCloudy => 'Teilweise bewölkt';

  @override
  String get weatherOvercast => 'Bedeckt';

  @override
  String get weatherFog => 'Nebel';

  @override
  String get weatherLightDrizzle => 'Leichter Nieselregen';

  @override
  String get weatherModerateDrizzle => 'Mäßiger Nieselregen';

  @override
  String get weatherDenseDrizzle => 'Dichter Nieselregen';

  @override
  String get weatherFreezingDrizzle => 'Gefrierender Nieselregen';

  @override
  String get weatherLightRain => 'Leichter Regen';

  @override
  String get weatherModerateRain => 'Mäßiger Regen';

  @override
  String get weatherHeavyRain => 'Starker Regen';

  @override
  String get weatherFreezingRain => 'Gefrierender Regen';

  @override
  String get weatherLightSnow => 'Leichter Schneefall';

  @override
  String get weatherModerateSnow => 'Mäßiger Schneefall';

  @override
  String get weatherHeavySnow => 'Starker Schneefall';

  @override
  String get weatherSleet => 'Schneeregen';

  @override
  String get weatherLightShowers => 'Leichte Schauer';

  @override
  String get weatherModerateShowers => 'Mäßige Schauer';

  @override
  String get weatherViolentShowers => 'Heftige Schauer';

  @override
  String get weatherLightSnowShowers => 'Leichte Schneeschauer';

  @override
  String get weatherHeavySnowShowers => 'Starke Schneeschauer';

  @override
  String get weatherThunderstorm => 'Gewitter';

  @override
  String get weatherThunderstormLightHail => 'Gewitter mit leichtem Hagel';

  @override
  String get weatherThunderstormHeavyHail => 'Gewitter mit starkem Hagel';

  @override
  String weatherUnknown(int code) {
    return 'Unbekannt (Code $code)';
  }

  @override
  String weatherToday(String date) {
    return 'Heute ($date)';
  }

  @override
  String get weatherTodayShort => 'Heute';

  @override
  String get weatherMorning => 'Morgen (9 Uhr)';

  @override
  String get weatherAfternoon => 'Nachmittag (15 Uhr)';

  @override
  String get weatherEvening => 'Abend (21 Uhr)';

  @override
  String weatherWind(int speed) {
    return 'Wind $speed km/h';
  }

  @override
  String get transitTransfer => 'Umstieg';

  @override
  String get transitWaiting => 'Wartezeit';

  @override
  String get transitDuration => 'Dauer:';

  @override
  String get transitDeparture => 'Abfahrt:';

  @override
  String get transitArrival => 'Ankunft:';

  @override
  String get transitDirect => 'direkt';

  @override
  String transitTransferCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Umstiege',
      one: '1 Umstieg',
    );
    return '$_temp0';
  }

  @override
  String transitOption(int index, String api) {
    return 'Option $index (über $api)';
  }

  @override
  String get transitSections => 'Abschnitte:';

  @override
  String get transitNoRoutes =>
      'Keine ÖPNV-Verbindungen zwischen diesen Standorten gefunden.';

  @override
  String get transitNoApiKey =>
      'Kein ÖPNV-API-Schlüssel konfiguriert. Setzen Sie den SNCF- oder PRIM-Schlüssel in Einstellungen > Routenplanung.';

  @override
  String transitInvalidKey(String api) {
    return '$api API-Schlüssel ist ungültig. Überprüfen Sie ihn in Einstellungen > Routenplanung.';
  }

  @override
  String get transitRateLimit =>
      'ÖPNV-API-Ratenlimit erreicht. Versuchen Sie es später erneut.';

  @override
  String get transitSncfRequired =>
      'SNCF API-Schlüssel erforderlich für Fahrten außerhalb der Île-de-France. Setzen Sie ihn in Einstellungen > Routenplanung.';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonSave => 'Speichern';

  @override
  String commonFailed(String error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get commonEnterApiKey => 'Bitte geben Sie einen API-Schlüssel ein';

  @override
  String get noProviderConfigured =>
      'Kein LLM-Anbieter konfiguriert. Bitte richten Sie einen Anbieter in den Einstellungen ein.';

  @override
  String get telegramBotPrivate => 'Dieser Bot ist privat.';

  @override
  String get localeSettingsTitle => 'Sprache';

  @override
  String get localeSystem => 'Systemstandard';

  @override
  String get localeEnglish => 'Englisch';

  @override
  String get localeFrench => 'Französisch';

  @override
  String get localeSpanish => 'Spanisch';

  @override
  String get localeGerman => 'Deutsch';

  @override
  String get localeItalian => 'Italienisch';

  @override
  String get agentRespondInstructions => 'Respond in German.';

  @override
  String get batteryCharging => 'lädt';

  @override
  String get batteryDischarging => 'entlädt sich';

  @override
  String get batteryFull => 'voll';

  @override
  String get batteryConnectedNotCharging => 'verbunden (lädt nicht)';

  @override
  String get batteryUnknown => 'unbekannt';

  @override
  String agentLlmError(String error) {
    return 'LLM-Aufruf fehlgeschlagen: $error';
  }

  @override
  String get agentMaxIterations => 'Maximale Werkzeugiterationen erreicht.';

  @override
  String agentError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get telegramErrorGeneric =>
      'Entschuldigung, es ist ein Fehler aufgetreten. Bitte versuchen Sie es erneut.';

  @override
  String get telegramErrorProcessing =>
      'Beim Verarbeiten Ihrer Nachricht ist ein Fehler aufgetreten.';

  @override
  String get notifChannelName => 'DroidClaw Hintergrunddienst';

  @override
  String get notifChannelDesc =>
      'Hintergrunddienst für Telegram-Bot und geplante Eingabeaufforderungen';

  @override
  String get notifServiceActive => 'DroidClaw - Aktiv';

  @override
  String get notifServiceRunning => 'Hintergrunddienst läuft';

  @override
  String get notifBotActive => 'DroidClaw Bot - Aktiv';

  @override
  String notifBotMessages(int count) {
    return 'Verarbeitete Nachrichten: $count';
  }

  @override
  String get notifBotError => 'DroidClaw Bot - Fehler';

  @override
  String get notifBotInvalidToken => 'Ungültiges Bot-Token';

  @override
  String get notifBotDisconnected => 'DroidClaw Bot - Getrennt';

  @override
  String get notifBotRetrying => 'Erneuter Versuch...';

  @override
  String notifLastCron(String name) {
    return 'Letzter Cron: $name';
  }

  @override
  String cronLastRun(String date) {
    return 'Letzte: $date';
  }
}
