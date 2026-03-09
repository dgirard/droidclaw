// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'DroidClaw';

  @override
  String get chatTitle => 'DroidClaw';

  @override
  String get chatConversations => 'Conversazioni';

  @override
  String get chatNewSession => 'Nuova sessione';

  @override
  String get chatSettings => 'Impostazioni';

  @override
  String get chatEmptyTitle => 'DroidClaw';

  @override
  String get chatEmptySubtitle =>
      'Il tuo assistente AI personale.\nScrivi un messaggio per iniziare.';

  @override
  String get chatInputHint => 'Messaggio a DroidClaw...';

  @override
  String get chatVoiceInput => 'Input vocale';

  @override
  String get chatSend => 'Invia';

  @override
  String get chatCopied => 'Copiato negli appunti';

  @override
  String chatCalling(String name) {
    return 'Chiamando $name...';
  }

  @override
  String get statusThinking => 'Pensando...';

  @override
  String statusThinkingStep(int step) {
    return 'Pensando (passo $step)...';
  }

  @override
  String get statusSummarizing => 'Riepilogando la conversazione...';

  @override
  String statusUsingTool(String name) {
    return 'Usando $name...';
  }

  @override
  String statusGotResult(String name) {
    return 'Risultato ottenuto da $name';
  }

  @override
  String get statusProcessing => 'Elaborazione...';

  @override
  String get historyTitle => 'Conversazioni';

  @override
  String get historySectionChat => 'Chat';

  @override
  String get historySectionCron => 'Prompt Programmati';

  @override
  String get historySectionTelegram => 'Telegram';

  @override
  String get historyEmpty => 'Nessuna conversazione ancora';

  @override
  String historyExecutions(int count, String date) {
    return '$count esecuzioni - Ultima: $date';
  }

  @override
  String historyMessages(int count) {
    return '$count messaggi';
  }

  @override
  String get historyNewConversation => 'Nuova conversazione';

  @override
  String get historyScheduledPrompt => 'Prompt programmato';

  @override
  String get historyNoExecutions => 'Nessuna esecuzione ancora';

  @override
  String get historyDeleteTitle => 'Eliminare conversazione?';

  @override
  String historyDeleteContent(String title) {
    return 'Eliminare \"$title\"? Questa azione non può essere annullata.';
  }

  @override
  String get historyToday => 'Oggi';

  @override
  String get historyYesterday => 'Ieri';

  @override
  String historyError(String error) {
    return 'Errore: $error';
  }

  @override
  String get onboardWelcome => 'Benvenuto in DroidClaw';

  @override
  String get onboardSubtitle =>
      'Il tuo assistente AI personale su Android.\nConfiguriamo il tuo provider LLM per iniziare.';

  @override
  String get onboardGetStarted => 'Inizia';

  @override
  String get onboardChooseProvider => 'Scegli un provider';

  @override
  String get onboardChooseProviderSubtitle =>
      'Seleziona quale provider LLM vuoi usare.';

  @override
  String get onboardNext => 'Avanti';

  @override
  String get onboardEnterApiKey => 'Inserisci la tua chiave API';

  @override
  String get onboardApiKeySecure =>
      'La tua chiave è memorizzata in modo sicuro sul dispositivo.';

  @override
  String get onboardApiKeyLabel => 'Chiave API';

  @override
  String get onboardTestConnection => 'Testa Connessione';

  @override
  String get onboardFinishSetup => 'Completa Configurazione';

  @override
  String onboardTestSuccess(String response) {
    return 'Connesso! Risposta: $response';
  }

  @override
  String get onboardEnterApiKeyError => 'Inserisci una chiave API';

  @override
  String get providerOpenRouter => 'OpenRouter';

  @override
  String get providerOpenRouterDesc =>
      'Accedi a molti modelli con una sola chiave API';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerAnthropicDesc => 'Accesso diretto ai modelli Claude';

  @override
  String get providerOpenAI => 'OpenAI';

  @override
  String get providerOpenAIDesc => 'Accesso ai modelli GPT';

  @override
  String get providerGroq => 'Groq';

  @override
  String get providerGroqDesc => 'Inferenza veloce per modelli open';

  @override
  String get providerGemini => 'Google Gemini';

  @override
  String get providerGeminiDesc => 'Modelli AI di Google con piano gratuito';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsSectionProvider => 'Provider LLM';

  @override
  String get settingsProvider => 'Provider';

  @override
  String get settingsModel => 'Modello';

  @override
  String get settingsSectionAgent => 'Agente';

  @override
  String get settingsMaxTokens => 'Token massimi';

  @override
  String get settingsTemperature => 'Temperatura';

  @override
  String get settingsMaxToolIterations => 'Iterazioni strumenti massime';

  @override
  String get settingsSectionTools => 'Strumenti';

  @override
  String get settingsManageTools => 'Gestisci Strumenti';

  @override
  String get settingsManageToolsSubtitle =>
      'Abilita o disabilita gli strumenti dell\'agente';

  @override
  String get settingsWebSearch => 'Ricerca Web';

  @override
  String get settingsWebSearchSubtitle => 'Configura API Brave Search';

  @override
  String get settingsRouting => 'Percorsi';

  @override
  String get settingsRoutingSubtitle => 'Configura API percorsi e trasporti';

  @override
  String get settingsScheduledPrompts => 'Prompt Programmati';

  @override
  String get settingsScheduledPromptsSubtitle =>
      'Attività ricorrenti automatizzate';

  @override
  String get settingsSectionChannels => 'Canali';

  @override
  String get settingsTelegramBot => 'Bot Telegram';

  @override
  String get settingsTelegramRunning => 'In esecuzione';

  @override
  String get settingsTelegramDisabled => 'Disabilitato';

  @override
  String get settingsSkills => 'Abilità';

  @override
  String get settingsSkillsSubtitle => 'Gestisci le abilità installate';

  @override
  String get settingsSectionAbout => 'Info';

  @override
  String get providerConfigTitle => 'Config Provider';

  @override
  String get providerConfigProviderLabel => 'Provider';

  @override
  String get providerConfigApiKeyLabel => 'Chiave API';

  @override
  String get providerConfigModelLabel => 'Modello (opzionale)';

  @override
  String get providerConfigModelHint => 'es. claude-sonnet-4-20250514';

  @override
  String get providerConfigApiBaseLabel => 'URL Base API (opzionale)';

  @override
  String get providerConfigApiBaseHint =>
      'Lascia vuoto per il valore predefinito';

  @override
  String get providerConfigTestConnection => 'Testa Connessione';

  @override
  String get providerConfigSave => 'Salva';

  @override
  String get providerConfigSaved => 'Impostazioni salvate';

  @override
  String providerConfigTestSuccess(String response) {
    return 'Connessione riuscita! Risposta: $response';
  }

  @override
  String providerConfigTestFailed(String error) {
    return 'Connessione fallita: $error';
  }

  @override
  String get telegramTitle => 'Bot Telegram';

  @override
  String get telegramBotToken => 'Token Bot';

  @override
  String get telegramBotTokenHelper =>
      'Ottienine uno da @BotFather su Telegram';

  @override
  String get telegramTestConnection => 'Testa Connessione';

  @override
  String telegramTestSuccess(String username) {
    return 'Connesso! Bot: @$username';
  }

  @override
  String get telegramEnableBot => 'Abilita Bot';

  @override
  String get telegramBotRunning => 'Bot in esecuzione';

  @override
  String get telegramBotStarting => 'Avvio in corso...';

  @override
  String get telegramBotDisabled => 'Bot disabilitato';

  @override
  String get telegramBotActive => 'Bot Attivo';

  @override
  String telegramMessages(int count) {
    return '$count messaggi';
  }

  @override
  String telegramLastMessage(String time) {
    return 'Ultimo: $time';
  }

  @override
  String get telegramAllowedUsers => 'Utenti Autorizzati (opzionale)';

  @override
  String get telegramAllowedUsersHelper =>
      'Nomi utente Telegram separati da virgola. Lascia vuoto per tutti.';

  @override
  String get telegramAllowedUsersHint => 'alice, bob, charlie';

  @override
  String get telegramSaveUsers => 'Salva Utenti';

  @override
  String get telegramUsersUpdated => 'Utenti autorizzati aggiornati';

  @override
  String get telegramEnterToken => 'Inserisci prima un token bot';

  @override
  String get telegramEnterTokenError => 'Inserisci un token bot';

  @override
  String get telegramHowToSetup => 'Come configurare';

  @override
  String get telegramSetupSteps =>
      '1. Apri Telegram e cerca @BotFather\n2. Invia /newbot e segui le istruzioni\n3. Copia il token del bot e incollalo sopra\n4. Testa la connessione, poi abilita il bot\n5. Invia un messaggio al tuo bot su Telegram!';

  @override
  String get webSearchTitle => 'Ricerca Web';

  @override
  String get webSearchDescription =>
      'La ricerca web funziona senza chiave usando DuckDuckGo, ma Brave Search offre risultati più veloci e di qualità superiore.';

  @override
  String get webSearchApiKeyLabel => 'Chiave API Brave Search';

  @override
  String get webSearchTestSearch => 'Testa Ricerca';

  @override
  String get webSearchSave => 'Salva';

  @override
  String get webSearchSaved => 'Chiave API Brave salvata';

  @override
  String get webSearchTestSuccess => 'Ricerca riuscita! Risultati ricevuti.';

  @override
  String get routingTitle => 'Percorsi e Trasporti';

  @override
  String get routingSave => 'Salva';

  @override
  String get routingSaved => 'Chiavi API salvate';

  @override
  String get routingOrsTitle => 'OpenRouteService';

  @override
  String get routingOrsDesc =>
      'Chiave API gratuita su openrouteservice.org per percorsi in auto, bici e a piedi.';

  @override
  String get routingOrsKeyLabel => 'Chiave API ORS';

  @override
  String get routingOrsTestRoute => 'Testa Percorso (Parigi → Versailles)';

  @override
  String get routingOrsTestGeocode =>
      'Testa Geocodifica (Torre Eiffel, Parigi)';

  @override
  String get routingSncfTitle => 'SNCF (Treni Nazionali)';

  @override
  String get routingSncfDesc =>
      'Chiave API gratuita su ressources.data.sncf.com per percorsi TGV, TER e Intercités in tutta la Francia.';

  @override
  String get routingSncfKeyLabel => 'Chiave API SNCF';

  @override
  String get routingSncfTestTransit => 'Testa Trasporto (Parigi → Lione)';

  @override
  String get routingPrimTitle => 'PRIM / IDFM (Île-de-France)';

  @override
  String get routingPrimDesc =>
      'Chiave API gratuita su prim.iledefrance-mobilites.fr per Métro, RER, Bus e Tram nella regione di Parigi.';

  @override
  String get routingPrimKeyLabel => 'Chiave API PRIM';

  @override
  String get routingPrimTestTransit =>
      'Testa Trasporto (Gare de Lyon → Châtelet)';

  @override
  String get cronTitle => 'Prompt Programmati';

  @override
  String get cronEmpty => 'Nessun prompt programmato';

  @override
  String get cronEmptySubtitle =>
      'Tocca + per creare un prompt ricorrente.\nL\'IA lo eseguirà automaticamente secondo il programma.';

  @override
  String get cronServiceRunning => 'Servizio in background in esecuzione';

  @override
  String get cronServiceNotRunning =>
      'Servizio in background non in esecuzione';

  @override
  String get cronNoPromptsEnabled => 'Nessun prompt abilitato';

  @override
  String get cronNeverRan => 'Mai eseguito';

  @override
  String get cronDeleteTitle => 'Eliminare prompt programmato?';

  @override
  String cronDeleteContent(String name) {
    return 'Eliminare \"$name\"? Questa azione non può essere annullata.';
  }

  @override
  String get cronViewExecutions => 'Visualizza esecuzioni';

  @override
  String get cronEditTitle => 'Nuovo Prompt';

  @override
  String get cronEditTitleEdit => 'Modifica Prompt';

  @override
  String get cronEditSave => 'Salva';

  @override
  String get cronEditName => 'Nome';

  @override
  String get cronEditNameHint => 'es., Riepilogo notizie giornaliero';

  @override
  String get cronEditPrompt => 'Prompt';

  @override
  String get cronEditPromptHint => 'Cosa dovrebbe fare l\'IA?';

  @override
  String get cronEditSchedule => 'Programmazione';

  @override
  String get cronEditInterval => 'Intervallo';

  @override
  String get cronEditSpecificTimes => 'Orari specifici';

  @override
  String get cronEditAddTime => 'Aggiungi orario';

  @override
  String get cronEditDays => 'Giorni';

  @override
  String get cronEditConversation => 'Conversazione';

  @override
  String get cronEditNewEach => 'Nuova conversazione ogni volta';

  @override
  String get cronEditNewEachSubtitle => 'Ogni esecuzione è indipendente';

  @override
  String get cronEditSameThread => 'Continua nello stesso thread';

  @override
  String get cronEditSameThreadSubtitle =>
      'L\'IA ricorda le esecuzioni precedenti';

  @override
  String get cronEditNameRequired => 'Nome e prompt sono obbligatori';

  @override
  String get cronEditTimeRequired => 'Aggiungi almeno un orario';

  @override
  String get cronEditInterval15 => '15 min';

  @override
  String get cronEditInterval30 => '30 min';

  @override
  String get cronEditInterval1h => '1 ora';

  @override
  String get cronEditInterval2h => '2 ore';

  @override
  String get cronEditInterval6h => '6 ore';

  @override
  String get cronEditInterval12h => '12 ore';

  @override
  String get cronEditInterval24h => '24 ore';

  @override
  String get cronEditMon => 'Lun';

  @override
  String get cronEditTue => 'Mar';

  @override
  String get cronEditWed => 'Mer';

  @override
  String get cronEditThu => 'Gio';

  @override
  String get cronEditFri => 'Ven';

  @override
  String get cronEditSat => 'Sab';

  @override
  String get cronEditSun => 'Dom';

  @override
  String cronDisplayEveryMinutes(int minutes) {
    return 'Ogni $minutes min';
  }

  @override
  String get cronDisplayEveryHour => 'Ogni ora';

  @override
  String cronDisplayEveryHours(int hours) {
    return 'Ogni $hours ore';
  }

  @override
  String cronDisplayDailyAt(String times) {
    return 'Giornalmente alle $times';
  }

  @override
  String cronDisplayAt(String times) {
    return 'Alle $times';
  }

  @override
  String get skillsTitle => 'Abilità';

  @override
  String get skillsGithubUrl => 'URL GitHub';

  @override
  String get skillsGithubUrlHint =>
      'https://github.com/user/repo/blob/main/SKILL.md';

  @override
  String get skillsInstall => 'Installa';

  @override
  String get skillsNoSkills => 'Nessuna abilità installata';

  @override
  String skillsInstalled(String name) {
    return 'Abilità installata: $name';
  }

  @override
  String skillsInstallFailed(String error) {
    return 'Installazione fallita: $error';
  }

  @override
  String get skillsUninstallTitle => 'Disinstallare Abilità';

  @override
  String skillsUninstallContent(String name) {
    return 'Rimuovere \"$name\"?';
  }

  @override
  String get skillsUninstall => 'Disinstalla';

  @override
  String skillsUninstalled(String name) {
    return 'Disinstallata: $name';
  }

  @override
  String skillsUninstallFailed(String error) {
    return 'Disinstallazione fallita: $error';
  }

  @override
  String get toolsTitle => 'Gestisci Strumenti';

  @override
  String get toolWebSearch => 'Ricerca Web';

  @override
  String get toolWebSearchDesc => 'Cerca sul web tramite API Brave';

  @override
  String get toolWebScrape => 'Scraping Web';

  @override
  String get toolWebScrapeDesc =>
      'Scraping leggero di pagine (HTTP + Markdown)';

  @override
  String get toolWebScrapeJs => 'Scraping Web (JS)';

  @override
  String get toolWebScrapeJsDesc =>
      'Scraping pesante di pagine renderizzate con JS (WebView)';

  @override
  String get toolFile => 'Accesso File';

  @override
  String get toolFileDesc => 'Leggi e scrivi file nello spazio di lavoro';

  @override
  String get toolLocation => 'Posizione GPS';

  @override
  String get toolLocationDesc => 'Accedi alle coordinate GPS del dispositivo';

  @override
  String get toolAddress => 'Geocodifica Inversa';

  @override
  String get toolAddressDesc => 'Converti coordinate GPS in indirizzo';

  @override
  String get toolSubagent => 'Sotto-agente';

  @override
  String get toolSubagentDesc => 'Genera sotto-task per query complesse';

  @override
  String get toolClipboard => 'Appunti';

  @override
  String get toolClipboardDesc =>
      'Leggi e scrivi negli appunti del dispositivo';

  @override
  String get toolDatetime => 'Data e Ora';

  @override
  String get toolDatetimeDesc =>
      'Ottieni data, ora, giorno della settimana, fuso orario correnti';

  @override
  String get toolDeviceInfo => 'Info Dispositivo';

  @override
  String get toolDeviceInfoDesc =>
      'Batteria, connettività, modello dispositivo';

  @override
  String get toolSpeak => 'Sintesi Vocale';

  @override
  String get toolSpeakDesc =>
      'Pronuncia testo ad alta voce (solo in primo piano)';

  @override
  String get toolOpenApp => 'Apri App / URL';

  @override
  String get toolOpenAppDesc =>
      'Apri URL, telefono, mappe, email sul dispositivo';

  @override
  String get toolAlarm => 'Sveglia / Timer';

  @override
  String get toolAlarmDesc =>
      'Imposta sveglie e timer tramite app Orologio di sistema';

  @override
  String get toolNotifications => 'Notifiche';

  @override
  String get toolNotificationsDesc =>
      'Crea e programma notifiche locali / promemoria';

  @override
  String get toolContacts => 'Contatti';

  @override
  String get toolContactsDesc =>
      'Cerca e leggi i contatti del dispositivo (sola lettura)';

  @override
  String get toolCalendar => 'Calendario';

  @override
  String get toolCalendarDesc => 'Leggi e crea eventi del calendario';

  @override
  String get toolOcr => 'OCR';

  @override
  String get toolOcrDesc => 'Estrai testo da immagini (ML Kit locale)';

  @override
  String get toolQrGenerate => 'Codice QR';

  @override
  String get toolQrGenerateDesc =>
      'Genera immagini di codici QR da testo o URL';

  @override
  String get toolPickImage => 'Selettore Immagini';

  @override
  String get toolPickImageDesc =>
      'Scegli foto dalla galleria o scatta con la fotocamera';

  @override
  String get toolVolumeControl => 'Controllo Volume';

  @override
  String get toolVolumeControlDesc =>
      'Leggi e regola i livelli di volume del dispositivo (sveglia, media, ecc.)';

  @override
  String get toolGeocode => 'Geocodifica';

  @override
  String get toolGeocodeDesc =>
      'Converti indirizzo in coordinate GPS (OpenRouteService)';

  @override
  String get toolDirections => 'Indicazioni';

  @override
  String get toolDirectionsDesc =>
      'Calcolo percorsi (auto, bici, a piedi) tramite OpenRouteService';

  @override
  String get toolTransit => 'Trasporto Pubblico';

  @override
  String get toolTransitDesc => 'Percorsi metro, RER, bus, treno (SNCF + IDFM)';

  @override
  String get toolWeather => 'Meteo';

  @override
  String get toolWeatherDesc =>
      'Previsioni meteo tramite Open-Meteo (modelli Météo-France)';

  @override
  String get toolRadio => 'Radio France';

  @override
  String get toolRadioDesc =>
      'Ascolta le radio France in diretta (France Inter, FIP, ecc.)';

  @override
  String get toolKnowledgeSearch => 'Ricerca conoscenze';

  @override
  String get toolKnowledgeSearchDesc =>
      'Cercare conoscenze memorizzate da conversazioni precedenti';

  @override
  String get toolKnowledgeStore => 'Archiviazione conoscenze';

  @override
  String get toolKnowledgeStoreDesc =>
      'Salvare un fatto da ricordare tra le conversazioni';

  @override
  String get weatherClearSky => 'Cielo sereno';

  @override
  String get weatherMainlyClear => 'Prevalentemente sereno';

  @override
  String get weatherPartlyCloudy => 'Parzialmente nuvoloso';

  @override
  String get weatherOvercast => 'Coperto';

  @override
  String get weatherFog => 'Nebbia';

  @override
  String get weatherLightDrizzle => 'Pioggerellina leggera';

  @override
  String get weatherModerateDrizzle => 'Pioggerellina moderata';

  @override
  String get weatherDenseDrizzle => 'Pioggerellina fitta';

  @override
  String get weatherFreezingDrizzle => 'Pioggerellina gelata';

  @override
  String get weatherLightRain => 'Pioggia leggera';

  @override
  String get weatherModerateRain => 'Pioggia moderata';

  @override
  String get weatherHeavyRain => 'Pioggia forte';

  @override
  String get weatherFreezingRain => 'Pioggia gelata';

  @override
  String get weatherLightSnow => 'Neve leggera';

  @override
  String get weatherModerateSnow => 'Neve moderata';

  @override
  String get weatherHeavySnow => 'Neve forte';

  @override
  String get weatherSleet => 'Nevischio';

  @override
  String get weatherLightShowers => 'Rovesci leggeri';

  @override
  String get weatherModerateShowers => 'Rovesci moderati';

  @override
  String get weatherViolentShowers => 'Rovesci violenti';

  @override
  String get weatherLightSnowShowers => 'Rovesci di neve leggeri';

  @override
  String get weatherHeavySnowShowers => 'Rovesci di neve forti';

  @override
  String get weatherThunderstorm => 'Temporale';

  @override
  String get weatherThunderstormLightHail => 'Temporale con grandine leggera';

  @override
  String get weatherThunderstormHeavyHail => 'Temporale con grandine forte';

  @override
  String weatherUnknown(int code) {
    return 'Sconosciuto (codice $code)';
  }

  @override
  String weatherToday(String date) {
    return 'Oggi ($date)';
  }

  @override
  String get weatherTodayShort => 'Oggi';

  @override
  String get weatherMorning => 'Mattina (9h)';

  @override
  String get weatherAfternoon => 'Pomeriggio (15h)';

  @override
  String get weatherEvening => 'Sera (21h)';

  @override
  String weatherWind(int speed) {
    return 'vento $speed km/h';
  }

  @override
  String get transitTransfer => 'cambio';

  @override
  String get transitWaiting => 'attesa';

  @override
  String get transitDuration => 'Durata:';

  @override
  String get transitDeparture => 'Part:';

  @override
  String get transitArrival => 'Arr:';

  @override
  String get transitDirect => 'diretto';

  @override
  String transitTransferCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cambi',
      one: '1 cambio',
    );
    return '$_temp0';
  }

  @override
  String transitOption(int index, String api) {
    return 'Opzione $index (via $api)';
  }

  @override
  String get transitSections => 'Tratte:';

  @override
  String get transitNoRoutes =>
      'Nessun percorso di trasporto pubblico trovato tra queste località.';

  @override
  String get transitNoApiKey =>
      'Nessuna chiave API trasporto configurata. Imposta la chiave SNCF o PRIM in Impostazioni > Percorsi.';

  @override
  String transitInvalidKey(String api) {
    return 'La chiave API $api non è valida. Controllala in Impostazioni > Percorsi.';
  }

  @override
  String get transitRateLimit =>
      'Limite di frequenza API trasporto raggiunto. Riprova più tardi.';

  @override
  String get transitSncfRequired =>
      'Chiave API SNCF necessaria per viaggi fuori dall\'Île-de-France. Impostala in Impostazioni > Percorsi.';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonSave => 'Salva';

  @override
  String commonFailed(String error) {
    return 'Fallito: $error';
  }

  @override
  String get commonEnterApiKey => 'Inserisci una chiave API';

  @override
  String get noProviderConfigured =>
      'Nessun provider LLM configurato. Configura un provider nelle Impostazioni.';

  @override
  String get telegramBotPrivate => 'Questo bot è privato.';

  @override
  String get localeSettingsTitle => 'Lingua';

  @override
  String get localeSystem => 'Predefinito sistema';

  @override
  String get localeEnglish => 'Inglese';

  @override
  String get localeFrench => 'Francese';

  @override
  String get localeSpanish => 'Spagnolo';

  @override
  String get localeGerman => 'Tedesco';

  @override
  String get localeItalian => 'Italiano';

  @override
  String get agentLanguageDirective =>
      'RESPONSE LANGUAGE: ITALIAN. You MUST always respond in Italian. DEVI sempre rispondere in italiano.';

  @override
  String get agentKeyBehaviors =>
      'Key behaviors:\n- BEFORE calling any tool, check the <knowledge_context> and memory above. If they already contain the answer (address, preference, contact, etc.), respond directly — do NOT call tools for information you already have.\n- Use knowledge data as tool input when chaining: if you know the user\'s home address from the knowledge context, pass it to geocode instead of calling get_location.\n- get_location returns the device CURRENT physical position only. Use it for \"where am I now\", \"nearest X\", \"from my current position\" — never for stored addresses or known places.\n- When you need information NOT in the knowledge context, call the appropriate tool(s) immediately without asking permission.\n- Chain tools when needed: if a tool requires coordinates but you have an address (from knowledge or the user), call geocode first.\n- When the user tells you personal information to remember (e.g. \"I live at...\", \"my dentist is...\"), just acknowledge and store it via knowledge_store. Do NOT call other tools or suggest actions in response.\n- Be concise and helpful. Use markdown formatting.';

  @override
  String get agentRespondInstructions =>
      'You MUST respond in Italian. All your output text must be in Italian. Rispondi sempre in italiano.';

  @override
  String get batteryCharging => 'in carica';

  @override
  String get batteryDischarging => 'in scarica';

  @override
  String get batteryFull => 'carica';

  @override
  String get batteryConnectedNotCharging => 'connessa (non in carica)';

  @override
  String get batteryUnknown => 'sconosciuto';

  @override
  String agentLlmError(String error) {
    return 'Chiamata LLM fallita: $error';
  }

  @override
  String get agentMaxIterations =>
      'Numero massimo di iterazioni strumenti raggiunto.';

  @override
  String agentError(String error) {
    return 'Errore: $error';
  }

  @override
  String get telegramErrorGeneric =>
      'Spiacente, si è verificato un errore. Riprova.';

  @override
  String get telegramErrorProcessing =>
      'Si è verificato un errore durante l\'elaborazione del tuo messaggio.';

  @override
  String get notifChannelName => 'Servizio in Background DroidClaw';

  @override
  String get notifChannelDesc =>
      'Servizio in background per bot Telegram e prompt programmati';

  @override
  String get notifServiceActive => 'DroidClaw - Attivo';

  @override
  String get notifServiceRunning => 'Servizio in background in esecuzione';

  @override
  String get notifBotActive => 'Bot DroidClaw - Attivo';

  @override
  String notifBotMessages(int count) {
    return 'Messaggi elaborati: $count';
  }

  @override
  String get notifBotError => 'Bot DroidClaw - Errore';

  @override
  String get notifBotInvalidToken => 'Token bot non valido';

  @override
  String get notifBotDisconnected => 'Bot DroidClaw - Disconnesso';

  @override
  String get notifBotRetrying => 'Nuovo tentativo...';

  @override
  String notifLastCron(String name) {
    return 'Ultimo cron: $name';
  }

  @override
  String cronLastRun(String date) {
    return 'Ultimo: $date';
  }

  @override
  String get logsTitle => 'Registri';

  @override
  String get logsEmpty => 'Nessuna voce di registro';

  @override
  String get logsFilterAll => 'Tutti';

  @override
  String get logsFilterInfo => 'Info';

  @override
  String get logsFilterWarning => 'Avviso';

  @override
  String get logsFilterError => 'Errore';

  @override
  String get logsSourceAgent => 'Agente';

  @override
  String get logsSourceCron => 'Cron';

  @override
  String get logsSourceService => 'Servizio';

  @override
  String get logsSourceTelegram => 'Telegram';

  @override
  String get logsSourceApp => 'App';

  @override
  String get logsClearAll => 'Cancella tutti i registri';

  @override
  String get logsClearConfirm => 'Eliminare tutte le voci di registro?';

  @override
  String logsEntryCount(int count) {
    return '$count voci';
  }

  @override
  String get logsCleared => 'Registri cancellati';

  @override
  String logsPurged(int count) {
    return '$count vecchie voci eliminate';
  }

  @override
  String get cronDeleteGroup => 'Eliminare tutte le esecuzioni di questo cron?';

  @override
  String get cronDeleteExecution => 'Eliminare questa esecuzione?';

  @override
  String cronDeleteGroupCount(int count) {
    return 'Questo eliminerà $count sessioni.';
  }

  @override
  String get chatListening => 'In ascolto...';

  @override
  String chatSpeechError(String error) {
    return 'Errore riconoscimento vocale: $error';
  }

  @override
  String get chatSpeechUnavailable =>
      'Riconoscimento vocale non disponibile su questo dispositivo';

  @override
  String get agentSummarizeInstructions => 'Write the summary in Italian.';

  @override
  String get settingsExportConversations => 'Esporta conversazioni';

  @override
  String get settingsExportSubtitle =>
      'Condividi tutte le conversazioni in JSON';

  @override
  String get exportProgress => 'Esportazione...';

  @override
  String exportSuccess(int count) {
    return '$count conversazioni esportate';
  }

  @override
  String get exportEmpty => 'Nessuna conversazione da esportare';

  @override
  String exportFailed(String error) {
    return 'Esportazione fallita: $error';
  }

  @override
  String get knowledgeTitle => 'Grafo della conoscenza';

  @override
  String get knowledgeSubtitle => 'Memoria persistente tra le conversazioni';

  @override
  String get knowledgeEnable => 'Attiva grafo della conoscenza';

  @override
  String get knowledgeEnableDesc =>
      'Estrarre e ricordare automaticamente le conoscenze dalle conversazioni';

  @override
  String get knowledgeAutoExtract => 'Estrazione automatica';

  @override
  String get knowledgeAutoExtractDesc =>
      'Estrarre entità e fatti dopo ogni risposta';

  @override
  String knowledgeStatsEntities(int count) {
    return '$count entità';
  }

  @override
  String knowledgeStatsRelations(int count) {
    return '$count relazioni';
  }

  @override
  String knowledgeStatsSize(String size) {
    return 'Dimensione database: $size';
  }

  @override
  String get knowledgeForgetAll => 'Dimentica tutto';

  @override
  String get knowledgeForgetAllDesc =>
      'Elimina tutte le conoscenze memorizzate';

  @override
  String get knowledgeForgetConfirmTitle => 'Dimenticare tutto?';

  @override
  String get knowledgeForgetConfirmBody =>
      'Questo eliminerà permanentemente tutte le entità, relazioni e fatti dal grafo della conoscenza. Questa azione è irreversibile.';

  @override
  String get knowledgeForgetConfirmButton => 'Dimentica tutto';

  @override
  String get knowledgeEmpty => 'Nessuna conoscenza memorizzata';

  @override
  String get knowledgeForgotten => 'Tutte le conoscenze eliminate';

  @override
  String get settingsKnowledge => 'Grafo della conoscenza';

  @override
  String get settingsKnowledgeSubtitle =>
      'Impostazioni della memoria persistente';

  @override
  String get llmTracesTitle => 'Tracce LLM';

  @override
  String get llmTracesEmpty => 'Nessuna traccia registrata';

  @override
  String llmTracesStatsHeader(int count, String tokens, String latency) {
    return '$count chiamate · $tokens token · ${latency}s media';
  }

  @override
  String get llmTracesLast24h => 'Ultime 24 ore';

  @override
  String get llmTracesFilterAll => 'Tutti';

  @override
  String get llmTracesFilterChat => 'Chat';

  @override
  String get llmTracesFilterSummarize => 'Riassunto';

  @override
  String get llmTracesFilterExtract => 'Estrazione';

  @override
  String get llmTracesClearAll => 'Cancella tutte le tracce';

  @override
  String get llmTracesClearConfirm => 'Eliminare tutte le tracce LLM?';

  @override
  String get llmTracesCleared => 'Tracce cancellate';

  @override
  String get llmTraceDetailTitle => 'Dettaglio traccia';

  @override
  String get llmTraceTokens => 'Token';

  @override
  String get llmTraceTokensIn => 'Ingresso';

  @override
  String get llmTraceTokensOut => 'Uscita';

  @override
  String get llmTraceTokensTotal => 'Totale';

  @override
  String llmTraceLatency(int ms) {
    return 'Latenza: $ms ms';
  }

  @override
  String llmTraceSystemPrompt(int chars) {
    return 'Prompt di sistema ($chars car.)';
  }

  @override
  String llmTraceMessages(int count) {
    return 'Messaggi ($count)';
  }

  @override
  String llmTraceResponse(int chars) {
    return 'Risposta ($chars car.)';
  }

  @override
  String get llmTraceToolsCalled => 'Strumenti chiamati';

  @override
  String get llmTraceFinishReason => 'Motivo di fine';

  @override
  String get llmTraceError => 'Errore';

  @override
  String llmTraceIteration(int n) {
    return 'iter $n';
  }

  @override
  String llmTracesSessionCalls(int count) {
    return '$count chiamate';
  }

  @override
  String get llmTracesSessionChat => 'Chat';

  @override
  String get llmTracesSessionCron => 'Cron';

  @override
  String get llmTracesSessionExtract => 'Estrazione';

  @override
  String get llmTracesUngrouped => 'Chiamate non raggruppate';

  @override
  String get llmTimelineTitle => 'Cronologia sessione';

  @override
  String get llmTimelineFinalResponse => 'Risposta finale';

  @override
  String get llmTimelineSummarize => 'Riepilogo del contesto';

  @override
  String get llmTimelineExtract => 'Estrazione KG';

  @override
  String llmTimelineToolsCalled(String tools) {
    return 'Strumenti: $tools';
  }

  @override
  String get llmTimelineUserPrompt => 'Prompt';

  @override
  String llmTimelineLlmCall(int n) {
    return 'Chiamata LLM #$n';
  }

  @override
  String get settingsLlmTraces => 'Tracce LLM';

  @override
  String get settingsLlmTracesSubtitle =>
      'Cronologia chiamate API e uso dei token';

  @override
  String get knowledgeBrowse => 'Esplora entità';

  @override
  String get knowledgeBrowseSubtitle => 'Ispeziona le conoscenze archiviate';

  @override
  String get knowledgeLanguageLabel => 'Lingua della base di conoscenza';

  @override
  String knowledgeLanguageLocked(String language) {
    return 'Tutta la conoscenza è archiviata in $language. Modifica tramite Dimentica tutto.';
  }

  @override
  String get knowledgeRebuild => 'Ricostruisci dalle conversazioni';

  @override
  String get knowledgeRebuildDesc =>
      'Rielabora tutto lo storico delle conversazioni nella base di conoscenza';

  @override
  String get knowledgeRebuildConfirmTitle =>
      'Ricostruire la base di conoscenza?';

  @override
  String knowledgeRebuildConfirmBody(int count, int sessions) {
    return 'Verranno elaborati $count turni di conversazione in $sessions sessioni. Ogni turno richiede una chiamata API LLM. Potrebbe richiedere diversi minuti.';
  }

  @override
  String knowledgeRebuildProgress(int current, int total) {
    return 'Elaborazione $current di $total...';
  }

  @override
  String knowledgeRebuildComplete(int processed, int failed) {
    return 'Ricostruzione completata: $processed turni elaborati, $failed falliti';
  }

  @override
  String knowledgeRebuildCancelled(int processed) {
    return 'Ricostruzione annullata dopo $processed turni';
  }

  @override
  String get knowledgeRebuildEmpty => 'Nessuna conversazione da elaborare';

  @override
  String get kgBrowserTitle => 'Browser conoscenze';

  @override
  String get kgBrowserSearch => 'Cerca entità...';

  @override
  String get kgBrowserEmpty => 'Nessuna entità trovata';

  @override
  String get kgFilterAll => 'Tutti';

  @override
  String get kgFilterPerson => 'Persona';

  @override
  String get kgFilterPlace => 'Luogo';

  @override
  String get kgFilterOrg => 'Org';

  @override
  String get kgFilterEvent => 'Evento';

  @override
  String get kgFilterConcept => 'Concetto';

  @override
  String get kgFilterDate => 'Data';

  @override
  String get kgFilterHot => 'Caldo';

  @override
  String get kgFilterWarm => 'Tiepido';

  @override
  String get kgFilterCool => 'Fresco';

  @override
  String get kgFilterCold => 'Freddo';

  @override
  String get kgEntityFacts => 'Fatti';

  @override
  String get kgEntityRelations => 'Relazioni';

  @override
  String get kgEntityAliases => 'Alias';

  @override
  String get kgEntityDecay => 'Diagnostica del deterioramento';

  @override
  String get kgEntityDelete => 'Elimina entità';

  @override
  String get kgEntityDeleteConfirm =>
      'Disattivare questa entità? Non apparirà più nelle ricerche.';

  @override
  String get kgEntityDeleted => 'Entità disattivata';

  @override
  String kgFactCount(int count) {
    return '$count fatti';
  }

  @override
  String get kgRetentionScore => 'Punteggio di ritenzione';

  @override
  String get kgLoadMore => 'Carica altro';

  @override
  String get settingsEmbedding => 'Embeddings';

  @override
  String get settingsEmbeddingSubtitle => 'Provider di vettori';

  @override
  String get embeddingTitle => 'Provider di Embedding';

  @override
  String get embeddingDescription =>
      'Configura un\'API di embedding remota per la ricerca semantica nel Knowledge Graph. Gemini offre un generoso livello gratuito.';

  @override
  String get embeddingProvider => 'Provider';

  @override
  String get embeddingProviderNone => 'Nessuno (disattivato)';

  @override
  String get embeddingModel => 'Modello';

  @override
  String get embeddingDimensions => 'Dimensioni';

  @override
  String get embeddingUseOwnApiKey => 'Usa chiave API dedicata';

  @override
  String get embeddingUseOwnApiKeySubtitle =>
      'Disattivato = riutilizza la chiave del LLM';

  @override
  String get embeddingApiKey => 'Chiave API Embedding';

  @override
  String get embeddingTestButton => 'Testa Embedding';

  @override
  String embeddingTestSuccess(int dims, int ms) {
    return 'Successo! Vettore di $dims dimensioni in ${ms}ms';
  }

  @override
  String get embeddingSave => 'Salva';

  @override
  String get embeddingSaved => 'Provider di embedding salvato';
}
