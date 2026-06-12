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
  String get historySectionTelegram => 'Telegram';

  @override
  String get historyTabConversations => 'Unterhaltungen';

  @override
  String get historyTabScheduled => 'Geplante Aufgaben';

  @override
  String get historyEmpty => 'Noch keine Unterhaltungen';

  @override
  String get historyEmptyScheduled => 'Keine geplanten Aufgaben';

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
  String get telegramAllowedUsers => 'Erlaubte Benutzer-IDs (erforderlich)';

  @override
  String get telegramAllowedUsersHelper =>
      'Durch Komma getrennte numerische Telegram-Benutzer-IDs (z. B. von @userinfobot). Der Bot antwortet niemandem, bis mindestens eine ID hinzugefügt wurde.';

  @override
  String get telegramAllowedUsersHint => '123456789, 987654321';

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
  String get cronRunNow => 'Jetzt ausführen';

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
  String get toolRadio => 'Radio France';

  @override
  String get toolRadioDesc =>
      'Radio-France-Sender live streamen (France Inter, FIP, usw.)';

  @override
  String get toolProofEditor => 'ProofEditor';

  @override
  String get toolProofEditorDesc =>
      'Kollaborative Dokumentbearbeitung über ProofEditor.ai';

  @override
  String get proofDocCreated => 'Dokument erstellt';

  @override
  String get proofActionApplied => 'Änderungen angewendet';

  @override
  String proofDocRenamed(String title) {
    return 'Titel aktualisiert: $title';
  }

  @override
  String proofDocTruncated(int max, int actual) {
    return '(Gekürzt auf $max von $actual Zeichen)';
  }

  @override
  String get toolKnowledgeSearch => 'Wissenssuche';

  @override
  String get toolKnowledgeSearchDesc =>
      'Gespeichertes Wissen aus früheren Gesprächen durchsuchen';

  @override
  String get toolKnowledgeStore => 'Wissensspeicher';

  @override
  String get toolKnowledgeStoreDesc =>
      'Einen Fakt zum Merken über Gespräche hinweg speichern';

  @override
  String get toolKbQuery => 'Wissensabfrage';

  @override
  String get toolKbQueryDesc => 'Wissensdatenbank durchsuchen und abfragen';

  @override
  String get toolDream => 'Traum';

  @override
  String get toolDreamDesc =>
      'KB analysieren und bereinigen durch Finden und Zusammenführen von Duplikaten';

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
  String get agentLanguageDirective =>
      'RESPONSE LANGUAGE: GERMAN. You MUST always respond in German. Du MUSST immer auf Deutsch antworten.';

  @override
  String get agentKeyBehaviors =>
      'Key behaviors:\n- BEFORE calling any tool, check the <knowledge_context> and memory above. If they already contain the answer (address, preference, contact, etc.), respond directly — do NOT call tools for information you already have.\n- Use knowledge data as tool input when chaining: if you know the user\'s home address from the knowledge context, pass it to geocode instead of calling get_location.\n- get_location returns the device CURRENT physical position only. Use it for \"where am I now\", \"nearest X\", \"from my current position\" — never for stored addresses or known places.\n- When you need information NOT in the knowledge context, call the appropriate tool(s) immediately without asking permission.\n- Chain tools when needed: if a tool requires coordinates but you have an address (from knowledge or the user), call geocode first.\n- When the user tells you personal information to remember (e.g. \"I live at...\", \"my dentist is...\"), just acknowledge and store it via knowledge_store. Do NOT call other tools or suggest actions in response.\n- Be concise and helpful. Use markdown formatting.';

  @override
  String get agentRespondInstructions =>
      'You MUST respond in German. All your output text must be in German. Antworte immer auf Deutsch.';

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

  @override
  String get logsTitle => 'Protokolle';

  @override
  String get logsEmpty => 'Keine Protokolleinträge';

  @override
  String get logsFilterAll => 'Alle';

  @override
  String get logsFilterInfo => 'Info';

  @override
  String get logsFilterWarning => 'Warnung';

  @override
  String get logsFilterError => 'Fehler';

  @override
  String get logsSourceAgent => 'Agent';

  @override
  String get logsSourceCron => 'Cron';

  @override
  String get logsSourceService => 'Dienst';

  @override
  String get logsSourceTelegram => 'Telegram';

  @override
  String get logsSourceApp => 'App';

  @override
  String get logsClearAll => 'Alle Protokolle löschen';

  @override
  String get logsClearConfirm => 'Alle Protokolleinträge löschen?';

  @override
  String logsEntryCount(int count) {
    return '$count Einträge';
  }

  @override
  String get logsCleared => 'Protokolle gelöscht';

  @override
  String logsPurged(int count) {
    return '$count alte Einträge bereinigt';
  }

  @override
  String get cronDeleteGroup => 'Alle Ausführungen dieses Crons löschen?';

  @override
  String get cronDeleteExecution => 'Diese Ausführung löschen?';

  @override
  String cronDeleteGroupCount(int count) {
    return 'Dies löscht $count Sitzungen.';
  }

  @override
  String get chatListening => 'Zuhören...';

  @override
  String chatSpeechError(String error) {
    return 'Spracherkennungsfehler: $error';
  }

  @override
  String get chatSpeechUnavailable =>
      'Spracherkennung auf diesem Gerät nicht verfügbar';

  @override
  String get voiceSpeaking => 'Sprachausgabe...';

  @override
  String get voiceStopSpeaking => 'Vorlesen stoppen';

  @override
  String get voiceLinkWord => 'Link';

  @override
  String voiceLanguageUnavailable(String language) {
    return 'Keine Stimme für \"$language\" verfügbar — Standardstimme wird verwendet';
  }

  @override
  String get voiceTtsUnavailable =>
      'Sprachausgabe ist auf diesem Gerät nicht verfügbar';

  @override
  String get agentSummarizeInstructions => 'Write the summary in German.';

  @override
  String get settingsExportConversations => 'Unterhaltungen exportieren';

  @override
  String get settingsExportSubtitle => 'Alle Unterhaltungen als JSON teilen';

  @override
  String get settingsResetAll => 'Alle Daten löschen';

  @override
  String get settingsResetAllSubtitle =>
      'API-Schlüssel, Unterhaltungen, Wissen, Zeitpläne, Telegram';

  @override
  String get resetConfirmTitle => 'Alle Daten löschen?';

  @override
  String get resetConfirmBody =>
      'Löscht dauerhaft alle API-Schlüssel, Unterhaltungen, die Wissensdatenbank, geplante Prompts, Telegram-Einstellungen, Traces und Protokolle. Die App kehrt zur Ersteinrichtung zurück.';

  @override
  String get resetConfirmButton => 'Alles löschen';

  @override
  String get resetDone => 'Alle Daten wurden gelöscht';

  @override
  String get exportProgress => 'Exportiere...';

  @override
  String exportSuccess(int count) {
    return '$count Unterhaltungen exportiert';
  }

  @override
  String get exportEmpty => 'Keine Unterhaltungen zum Exportieren';

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get knowledgeTitle => 'Wissensgraph';

  @override
  String get knowledgeSubtitle =>
      'Dauerhaftes Gedächtnis über Gespräche hinweg';

  @override
  String get knowledgeEnable => 'Wissensgraph aktivieren';

  @override
  String get knowledgeEnableDesc =>
      'Wissen aus Gesprächen automatisch extrahieren und merken';

  @override
  String get knowledgeAutoExtract => 'Automatische Extraktion';

  @override
  String get knowledgeAutoExtractDesc =>
      'Entitäten und Fakten nach jeder Antwort extrahieren';

  @override
  String knowledgeStatsEntities(int count) {
    return '$count Entitäten';
  }

  @override
  String knowledgeStatsRelations(int count) {
    return '$count Beziehungen';
  }

  @override
  String knowledgeStatsSize(String size) {
    return 'Datenbankgröße: $size';
  }

  @override
  String get knowledgeForgetAll => 'Alles vergessen';

  @override
  String get knowledgeForgetAllDesc => 'Alles gespeicherte Wissen löschen';

  @override
  String get knowledgeForgetConfirmTitle => 'Alles vergessen?';

  @override
  String get knowledgeForgetConfirmBody =>
      'Dadurch werden alle Entitäten, Beziehungen und Fakten aus dem Wissensgraph dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get knowledgeForgetConfirmButton => 'Alles vergessen';

  @override
  String get knowledgeEmpty => 'Noch kein Wissen gespeichert';

  @override
  String get knowledgeForgotten => 'Alles Wissen gelöscht';

  @override
  String get settingsKnowledge => 'Wissensgraph';

  @override
  String get settingsKnowledgeSubtitle =>
      'Einstellungen für dauerhaftes Gedächtnis';

  @override
  String get llmTracesTitle => 'LLM-Traces';

  @override
  String get llmTracesEmpty => 'Keine Traces aufgezeichnet';

  @override
  String llmTracesStatsHeader(int count, String tokens, String latency) {
    return '$count Aufrufe · $tokens Tokens · ${latency}s Durchschn.';
  }

  @override
  String get llmTracesLast24h => 'Letzte 24 Stunden';

  @override
  String get llmTracesFilterAll => 'Alle';

  @override
  String get llmTracesFilterChat => 'Chat';

  @override
  String get llmTracesFilterSummarize => 'Zusammenfassung';

  @override
  String get llmTracesFilterExtract => 'Extraktion';

  @override
  String get llmTracesClearAll => 'Alle Traces löschen';

  @override
  String get llmTracesClearConfirm => 'Alle LLM-Traces löschen?';

  @override
  String get llmTracesCleared => 'Traces gelöscht';

  @override
  String get llmTraceDetailTitle => 'Trace-Details';

  @override
  String get llmTraceTokens => 'Tokens';

  @override
  String get llmTraceTokensIn => 'Eingang';

  @override
  String get llmTraceTokensOut => 'Ausgang';

  @override
  String get llmTraceTokensTotal => 'Gesamt';

  @override
  String llmTraceLatency(int ms) {
    return 'Latenz: $ms ms';
  }

  @override
  String llmTraceSystemPrompt(int chars) {
    return 'Systemprompt ($chars Zeichen)';
  }

  @override
  String llmTraceMessages(int count) {
    return 'Nachrichten ($count)';
  }

  @override
  String llmTraceResponse(int chars) {
    return 'Antwort ($chars Zeichen)';
  }

  @override
  String get llmTraceToolsCalled => 'Aufgerufene Tools';

  @override
  String get llmTraceFinishReason => 'Abschlussgrund';

  @override
  String get llmTraceError => 'Fehler';

  @override
  String llmTraceIteration(int n) {
    return 'Iter $n';
  }

  @override
  String llmTracesSessionCalls(int count) {
    return '$count Aufrufe';
  }

  @override
  String get llmTracesSessionChat => 'Chat';

  @override
  String get llmTracesSessionCron => 'Cron';

  @override
  String get llmTracesSessionExtract => 'Extraktion';

  @override
  String get llmTracesUngrouped => 'Nicht gruppierte Aufrufe';

  @override
  String get llmTimelineTitle => 'Sitzungs-Chronologie';

  @override
  String get llmTimelineFinalResponse => 'Endantwort';

  @override
  String get llmTimelineSummarize => 'Kontextzusammenfassung';

  @override
  String get llmTimelineExtract => 'KG-Extraktion';

  @override
  String llmTimelineToolsCalled(String tools) {
    return 'Tools: $tools';
  }

  @override
  String get llmTimelineUserPrompt => 'Prompt';

  @override
  String llmTimelineLlmCall(int n) {
    return 'LLM-Aufruf #$n';
  }

  @override
  String get settingsLlmTraces => 'LLM-Traces';

  @override
  String get settingsLlmTracesSubtitle =>
      'API-Aufrufverlauf und Token-Verbrauch';

  @override
  String get knowledgeBrowse => 'Entitäten durchsuchen';

  @override
  String get knowledgeBrowseSubtitle => 'Gespeichertes Wissen inspizieren';

  @override
  String get knowledgeExport => 'Wissensdatenbank exportieren';

  @override
  String get knowledgeExportSubtitle => 'Alle Entitäten als JSON exportieren';

  @override
  String knowledgeExportSuccess(int count) {
    return '$count Entitäten exportiert';
  }

  @override
  String get knowledgeLanguageLabel => 'Sprache der Wissensdatenbank';

  @override
  String knowledgeLanguageLocked(String language) {
    return 'Alles Wissen wird auf $language gespeichert. Ändern über Alles vergessen.';
  }

  @override
  String get knowledgeRebuild => 'Aus Gesprächen neu aufbauen';

  @override
  String get knowledgeRebuildDesc =>
      'Gesamten Gesprächsverlauf in die Wissensdatenbank verarbeiten';

  @override
  String get knowledgeRebuildConfirmTitle => 'Wissensdatenbank neu aufbauen?';

  @override
  String knowledgeRebuildConfirmBody(int count, int sessions) {
    return 'Es werden $count Gesprächsrunden aus $sessions Sitzungen verarbeitet. Jede Runde erfordert einen LLM-API-Aufruf. Dies kann mehrere Minuten dauern.';
  }

  @override
  String knowledgeRebuildProgress(int current, int total) {
    return 'Verarbeite $current von $total...';
  }

  @override
  String knowledgeRebuildComplete(int processed, int failed) {
    return 'Aufbau abgeschlossen: $processed Runden verarbeitet, $failed fehlgeschlagen';
  }

  @override
  String knowledgeRebuildCancelled(int processed) {
    return 'Aufbau nach $processed Runden abgebrochen';
  }

  @override
  String get knowledgeRebuildEmpty => 'Keine Gespräche zu verarbeiten';

  @override
  String get kgBrowserTitle => 'Wissensbrowser';

  @override
  String get kgBrowserSearch => 'Entitäten suchen...';

  @override
  String get kgBrowserEmpty => 'Keine Entitäten gefunden';

  @override
  String get kgFilterAll => 'Alle';

  @override
  String get kgFilterPerson => 'Person';

  @override
  String get kgFilterPlace => 'Ort';

  @override
  String get kgFilterOrg => 'Org';

  @override
  String get kgFilterEvent => 'Ereignis';

  @override
  String get kgFilterConcept => 'Konzept';

  @override
  String get kgFilterDate => 'Datum';

  @override
  String get kgFilterHot => 'Heiß';

  @override
  String get kgFilterWarm => 'Warm';

  @override
  String get kgFilterCool => 'Kühl';

  @override
  String get kgFilterCold => 'Kalt';

  @override
  String get kgEntityFacts => 'Fakten';

  @override
  String get kgEntityRelations => 'Beziehungen';

  @override
  String get kgEntityAliases => 'Aliase';

  @override
  String get kgEntityDecay => 'Verfall-Diagnostik';

  @override
  String get kgEntityDelete => 'Entität löschen';

  @override
  String get kgEntityDeleteConfirm =>
      'Diese Entität deaktivieren? Sie wird nicht mehr in Abfragen erscheinen.';

  @override
  String get kgEntityDeleted => 'Entität deaktiviert';

  @override
  String kgFactCount(int count) {
    return '$count Fakten';
  }

  @override
  String get kgRetentionScore => 'Retentionswert';

  @override
  String get kgLoadMore => 'Mehr laden';

  @override
  String get settingsEmbedding => 'Embeddings';

  @override
  String get settingsEmbeddingSubtitle => 'Vektor-Embedding-Anbieter';

  @override
  String get embeddingTitle => 'Embedding-Anbieter';

  @override
  String get embeddingDescription =>
      'Konfigurieren Sie eine Remote-Embedding-API für die semantische Suche im Knowledge Graph. Gemini bietet ein großzügiges kostenloses Kontingent.';

  @override
  String get embeddingProvider => 'Anbieter';

  @override
  String get embeddingProviderNone => 'Keiner (deaktiviert)';

  @override
  String get embeddingModel => 'Modell';

  @override
  String get embeddingDimensions => 'Dimensionen';

  @override
  String get embeddingUseOwnApiKey => 'Dedizierten API-Schlüssel verwenden';

  @override
  String get embeddingUseOwnApiKeySubtitle =>
      'Aus = LLM-Anbieter-Schlüssel wiederverwenden';

  @override
  String get embeddingApiKey => 'Embedding-API-Schlüssel';

  @override
  String get embeddingTestButton => 'Embedding testen';

  @override
  String embeddingTestSuccess(int dims, int ms) {
    return 'Erfolg! Vektor mit $dims Dimensionen in ${ms}ms';
  }

  @override
  String get embeddingSave => 'Speichern';

  @override
  String get embeddingSaved => 'Embedding-Anbieter gespeichert';

  @override
  String get embeddingProviderLocal => 'Lokal (auf dem Gerät)';

  @override
  String get embeddingLocalSection => 'Modell auf dem Gerät';

  @override
  String get embeddingLocalConsent =>
      'EmbeddingGemma 300M wird von Hugging Face heruntergeladen (~330 MB). Der Download nutzt nur WLAN, sofern du mobile Daten nicht erlaubst. Nach dem Download funktioniert die semantische Suche vollständig offline und ohne API-Schlüssel.';

  @override
  String get embeddingLocalDimensionsNote =>
      'Die Ausgabedimensionen sind auf 256 festgelegt (Matryoshka-Kürzung).';

  @override
  String get embeddingLocalAllowMetered => 'Mobile Daten erlauben';

  @override
  String get embeddingLocalAllowMeteredSubtitle => 'Aus = nur WLAN';

  @override
  String get embeddingLocalDownload => 'Modell herunterladen';

  @override
  String get embeddingLocalCancel => 'Download abbrechen';

  @override
  String get embeddingLocalRetry => 'Download wiederholen';

  @override
  String get embeddingLocalDelete => 'Modell löschen';

  @override
  String get embeddingLocalDeleteConfirm =>
      'Heruntergeladenes Modell löschen (~330 MB)? Die semantische Suche funktioniert erst nach erneutem Download wieder.';

  @override
  String get embeddingLocalStateAbsent => 'Modell nicht heruntergeladen';

  @override
  String embeddingLocalStateDownloading(int pct) {
    return 'Wird heruntergeladen… $pct%';
  }

  @override
  String get embeddingLocalStateVerifying => 'Prüfsummen werden verifiziert…';

  @override
  String get embeddingLocalStateReady => 'Modell bereit';

  @override
  String embeddingLocalStateFailed(String error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String get embeddingLocalBenchmark => 'Latenz-Benchmark ausführen';

  @override
  String embeddingLocalBenchmarkResult(int ms, int runs, String verdict) {
    return 'Median $ms ms über $runs Durchläufe — $verdict';
  }

  @override
  String get embeddingLocalVerdictFast => 'schnell (als Standard geeignet)';

  @override
  String get embeddingLocalVerdictAcceptable => 'akzeptabel (Opt-in)';

  @override
  String get embeddingLocalVerdictSlow => 'langsam (nur Offline-Fallback)';
}
