// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'DroidClaw';

  @override
  String get chatTitle => 'DroidClaw';

  @override
  String get chatConversations => 'Conversations';

  @override
  String get chatNewSession => 'New session';

  @override
  String get chatSettings => 'Settings';

  @override
  String get chatEmptyTitle => 'DroidClaw';

  @override
  String get chatEmptySubtitle =>
      'Your personal AI assistant.\nType a message to get started.';

  @override
  String get chatInputHint => 'Message DroidClaw...';

  @override
  String get chatVoiceInput => 'Voice input';

  @override
  String get chatSend => 'Send';

  @override
  String get chatCopied => 'Copied to clipboard';

  @override
  String chatCalling(String name) {
    return 'Calling $name...';
  }

  @override
  String get statusThinking => 'Thinking...';

  @override
  String statusThinkingStep(int step) {
    return 'Thinking (step $step)...';
  }

  @override
  String get statusSummarizing => 'Summarizing conversation...';

  @override
  String statusUsingTool(String name) {
    return 'Using $name...';
  }

  @override
  String statusGotResult(String name) {
    return 'Got result from $name';
  }

  @override
  String get statusProcessing => 'Processing...';

  @override
  String get historyTitle => 'Conversations';

  @override
  String get historySectionChat => 'Chat';

  @override
  String get historySectionCron => 'Scheduled Prompts';

  @override
  String get historySectionTelegram => 'Telegram';

  @override
  String get historyEmpty => 'No conversations yet';

  @override
  String historyExecutions(int count, String date) {
    return '$count executions - Last: $date';
  }

  @override
  String historyMessages(int count) {
    return '$count messages';
  }

  @override
  String get historyNewConversation => 'New conversation';

  @override
  String get historyScheduledPrompt => 'Scheduled prompt';

  @override
  String get historyNoExecutions => 'No executions yet';

  @override
  String get historyDeleteTitle => 'Delete conversation?';

  @override
  String historyDeleteContent(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String historyError(String error) {
    return 'Error: $error';
  }

  @override
  String get onboardWelcome => 'Welcome to DroidClaw';

  @override
  String get onboardSubtitle =>
      'Your personal AI assistant on Android.\nLet\'s set up your LLM provider to get started.';

  @override
  String get onboardGetStarted => 'Get Started';

  @override
  String get onboardChooseProvider => 'Choose a provider';

  @override
  String get onboardChooseProviderSubtitle =>
      'Select which LLM provider you want to use.';

  @override
  String get onboardNext => 'Next';

  @override
  String get onboardEnterApiKey => 'Enter your API key';

  @override
  String get onboardApiKeySecure => 'Your key is stored securely on device.';

  @override
  String get onboardApiKeyLabel => 'API Key';

  @override
  String get onboardTestConnection => 'Test Connection';

  @override
  String get onboardFinishSetup => 'Finish Setup';

  @override
  String onboardTestSuccess(String response) {
    return 'Connected! Response: $response';
  }

  @override
  String get onboardEnterApiKeyError => 'Please enter an API key';

  @override
  String get providerOpenRouter => 'OpenRouter';

  @override
  String get providerOpenRouterDesc => 'Access many models with one API key';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerAnthropicDesc => 'Direct access to Claude models';

  @override
  String get providerOpenAI => 'OpenAI';

  @override
  String get providerOpenAIDesc => 'Access to GPT models';

  @override
  String get providerGroq => 'Groq';

  @override
  String get providerGroqDesc => 'Fast inference for open models';

  @override
  String get providerGemini => 'Google Gemini';

  @override
  String get providerGeminiDesc => 'Google AI models with free tier';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionProvider => 'LLM Provider';

  @override
  String get settingsProvider => 'Provider';

  @override
  String get settingsModel => 'Model';

  @override
  String get settingsSectionAgent => 'Agent';

  @override
  String get settingsMaxTokens => 'Max tokens';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsMaxToolIterations => 'Max tool iterations';

  @override
  String get settingsSectionTools => 'Tools';

  @override
  String get settingsManageTools => 'Manage Tools';

  @override
  String get settingsManageToolsSubtitle => 'Enable or disable agent tools';

  @override
  String get settingsWebSearch => 'Web Search';

  @override
  String get settingsWebSearchSubtitle => 'Configure Brave Search API';

  @override
  String get settingsRouting => 'Routing';

  @override
  String get settingsRoutingSubtitle => 'Configure routing & transit APIs';

  @override
  String get settingsScheduledPrompts => 'Scheduled Prompts';

  @override
  String get settingsScheduledPromptsSubtitle => 'Automated recurring tasks';

  @override
  String get settingsSectionChannels => 'Channels';

  @override
  String get settingsTelegramBot => 'Telegram Bot';

  @override
  String get settingsTelegramRunning => 'Running';

  @override
  String get settingsTelegramDisabled => 'Disabled';

  @override
  String get settingsSkills => 'Skills';

  @override
  String get settingsSkillsSubtitle => 'Manage installed skills';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get providerConfigTitle => 'Provider Config';

  @override
  String get providerConfigProviderLabel => 'Provider';

  @override
  String get providerConfigApiKeyLabel => 'API Key';

  @override
  String get providerConfigModelLabel => 'Model (optional)';

  @override
  String get providerConfigModelHint => 'e.g. claude-sonnet-4-20250514';

  @override
  String get providerConfigApiBaseLabel => 'API Base URL (optional)';

  @override
  String get providerConfigApiBaseHint => 'Leave empty for default';

  @override
  String get providerConfigTestConnection => 'Test Connection';

  @override
  String get providerConfigSave => 'Save';

  @override
  String get providerConfigSaved => 'Settings saved';

  @override
  String providerConfigTestSuccess(String response) {
    return 'Connection successful! Response: $response';
  }

  @override
  String providerConfigTestFailed(String error) {
    return 'Connection failed: $error';
  }

  @override
  String get telegramTitle => 'Telegram Bot';

  @override
  String get telegramBotToken => 'Bot Token';

  @override
  String get telegramBotTokenHelper => 'Get one from @BotFather on Telegram';

  @override
  String get telegramTestConnection => 'Test Connection';

  @override
  String telegramTestSuccess(String username) {
    return 'Connected! Bot: @$username';
  }

  @override
  String get telegramEnableBot => 'Enable Bot';

  @override
  String get telegramBotRunning => 'Bot is running';

  @override
  String get telegramBotStarting => 'Starting...';

  @override
  String get telegramBotDisabled => 'Bot is disabled';

  @override
  String get telegramBotActive => 'Bot Active';

  @override
  String telegramMessages(int count) {
    return '$count messages';
  }

  @override
  String telegramLastMessage(String time) {
    return 'Last: $time';
  }

  @override
  String get telegramAllowedUsers => 'Allowed Users (optional)';

  @override
  String get telegramAllowedUsersHelper =>
      'Comma-separated Telegram usernames. Leave empty for all.';

  @override
  String get telegramAllowedUsersHint => 'alice, bob, charlie';

  @override
  String get telegramSaveUsers => 'Save Users';

  @override
  String get telegramUsersUpdated => 'Allowed users updated';

  @override
  String get telegramEnterToken => 'Please enter a bot token first';

  @override
  String get telegramEnterTokenError => 'Please enter a bot token';

  @override
  String get telegramHowToSetup => 'How to set up';

  @override
  String get telegramSetupSteps =>
      '1. Open Telegram and search for @BotFather\n2. Send /newbot and follow the instructions\n3. Copy the bot token and paste it above\n4. Test the connection, then enable the bot\n5. Send a message to your bot on Telegram!';

  @override
  String get webSearchTitle => 'Web Search';

  @override
  String get webSearchDescription =>
      'Web search works without a key using DuckDuckGo, but Brave Search gives faster, higher-quality results.';

  @override
  String get webSearchApiKeyLabel => 'Brave Search API Key';

  @override
  String get webSearchTestSearch => 'Test Search';

  @override
  String get webSearchSave => 'Save';

  @override
  String get webSearchSaved => 'Brave API key saved';

  @override
  String get webSearchTestSuccess => 'Search successful! Results received.';

  @override
  String get routingTitle => 'Routing & Transit';

  @override
  String get routingSave => 'Save';

  @override
  String get routingSaved => 'API keys saved';

  @override
  String get routingOrsTitle => 'OpenRouteService';

  @override
  String get routingOrsDesc =>
      'Free API key at openrouteservice.org for car, bike, and walking routes.';

  @override
  String get routingOrsKeyLabel => 'ORS API Key';

  @override
  String get routingOrsTestRoute => 'Test Route (Paris → Versailles)';

  @override
  String get routingOrsTestGeocode => 'Test Geocode (Tour Eiffel, Paris)';

  @override
  String get routingSncfTitle => 'SNCF (National Trains)';

  @override
  String get routingSncfDesc =>
      'Free API key at ressources.data.sncf.com for TGV, TER, and Intercités routes across France.';

  @override
  String get routingSncfKeyLabel => 'SNCF API Key';

  @override
  String get routingSncfTestTransit => 'Test Transit (Paris → Lyon)';

  @override
  String get routingPrimTitle => 'PRIM / IDFM (Île-de-France)';

  @override
  String get routingPrimDesc =>
      'Free API key at prim.iledefrance-mobilites.fr for Métro, RER, Bus, and Tram in Paris region.';

  @override
  String get routingPrimKeyLabel => 'PRIM API Key';

  @override
  String get routingPrimTestTransit => 'Test Transit (Gare de Lyon → Châtelet)';

  @override
  String get cronTitle => 'Scheduled Prompts';

  @override
  String get cronEmpty => 'No scheduled prompts';

  @override
  String get cronEmptySubtitle =>
      'Tap + to create a recurring prompt.\nThe AI will run it automatically on schedule.';

  @override
  String get cronServiceRunning => 'Background service running';

  @override
  String get cronServiceNotRunning => 'Background service not running';

  @override
  String get cronNoPromptsEnabled => 'No prompts enabled';

  @override
  String get cronNeverRan => 'Never ran';

  @override
  String get cronDeleteTitle => 'Delete scheduled prompt?';

  @override
  String cronDeleteContent(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get cronViewExecutions => 'View executions';

  @override
  String get cronEditTitle => 'New Prompt';

  @override
  String get cronEditTitleEdit => 'Edit Prompt';

  @override
  String get cronEditSave => 'Save';

  @override
  String get cronEditName => 'Name';

  @override
  String get cronEditNameHint => 'e.g., Daily news brief';

  @override
  String get cronEditPrompt => 'Prompt';

  @override
  String get cronEditPromptHint => 'What should the AI do?';

  @override
  String get cronEditSchedule => 'Schedule';

  @override
  String get cronEditInterval => 'Interval';

  @override
  String get cronEditSpecificTimes => 'Specific times';

  @override
  String get cronEditAddTime => 'Add time';

  @override
  String get cronEditDays => 'Days';

  @override
  String get cronEditConversation => 'Conversation';

  @override
  String get cronEditNewEach => 'New conversation each time';

  @override
  String get cronEditNewEachSubtitle => 'Each execution is independent';

  @override
  String get cronEditSameThread => 'Continue in same thread';

  @override
  String get cronEditSameThreadSubtitle =>
      'The AI remembers previous executions';

  @override
  String get cronEditNameRequired => 'Name and prompt are required';

  @override
  String get cronEditTimeRequired => 'Add at least one time';

  @override
  String get cronEditInterval15 => '15 min';

  @override
  String get cronEditInterval30 => '30 min';

  @override
  String get cronEditInterval1h => '1 hour';

  @override
  String get cronEditInterval2h => '2 hours';

  @override
  String get cronEditInterval6h => '6 hours';

  @override
  String get cronEditInterval12h => '12 hours';

  @override
  String get cronEditInterval24h => '24 hours';

  @override
  String get cronEditMon => 'Mon';

  @override
  String get cronEditTue => 'Tue';

  @override
  String get cronEditWed => 'Wed';

  @override
  String get cronEditThu => 'Thu';

  @override
  String get cronEditFri => 'Fri';

  @override
  String get cronEditSat => 'Sat';

  @override
  String get cronEditSun => 'Sun';

  @override
  String cronDisplayEveryMinutes(int minutes) {
    return 'Every $minutes min';
  }

  @override
  String get cronDisplayEveryHour => 'Every hour';

  @override
  String cronDisplayEveryHours(int hours) {
    return 'Every $hours hours';
  }

  @override
  String cronDisplayDailyAt(String times) {
    return 'Daily at $times';
  }

  @override
  String cronDisplayAt(String times) {
    return 'At $times';
  }

  @override
  String get skillsTitle => 'Skills';

  @override
  String get skillsGithubUrl => 'GitHub URL';

  @override
  String get skillsGithubUrlHint =>
      'https://github.com/user/repo/blob/main/SKILL.md';

  @override
  String get skillsInstall => 'Install';

  @override
  String get skillsNoSkills => 'No skills installed';

  @override
  String skillsInstalled(String name) {
    return 'Installed skill: $name';
  }

  @override
  String skillsInstallFailed(String error) {
    return 'Install failed: $error';
  }

  @override
  String get skillsUninstallTitle => 'Uninstall Skill';

  @override
  String skillsUninstallContent(String name) {
    return 'Remove \"$name\"?';
  }

  @override
  String get skillsUninstall => 'Uninstall';

  @override
  String skillsUninstalled(String name) {
    return 'Uninstalled: $name';
  }

  @override
  String skillsUninstallFailed(String error) {
    return 'Uninstall failed: $error';
  }

  @override
  String get toolsTitle => 'Manage Tools';

  @override
  String get toolWebSearch => 'Web Search';

  @override
  String get toolWebSearchDesc => 'Search the web via Brave API';

  @override
  String get toolWebScrape => 'Web Scrape';

  @override
  String get toolWebScrapeDesc => 'Lightweight page scraping (HTTP + Markdown)';

  @override
  String get toolWebScrapeJs => 'Web Scrape (JS)';

  @override
  String get toolWebScrapeJsDesc => 'Heavy JS-rendered page scraping (WebView)';

  @override
  String get toolFile => 'File Access';

  @override
  String get toolFileDesc => 'Read and write files in workspace';

  @override
  String get toolLocation => 'GPS Location';

  @override
  String get toolLocationDesc => 'Access device GPS coordinates';

  @override
  String get toolAddress => 'Reverse Geocoding';

  @override
  String get toolAddressDesc => 'Convert GPS coordinates to address';

  @override
  String get toolSubagent => 'Sub-agent';

  @override
  String get toolSubagentDesc => 'Spawn sub-tasks for complex queries';

  @override
  String get toolClipboard => 'Clipboard';

  @override
  String get toolClipboardDesc => 'Read and write device clipboard';

  @override
  String get toolDatetime => 'Date & Time';

  @override
  String get toolDatetimeDesc =>
      'Get current date, time, day of week, timezone';

  @override
  String get toolDeviceInfo => 'Device Info';

  @override
  String get toolDeviceInfoDesc => 'Battery, connectivity, device model';

  @override
  String get toolSpeak => 'Text to Speech';

  @override
  String get toolSpeakDesc => 'Speak text aloud (foreground only)';

  @override
  String get toolOpenApp => 'Open App / URL';

  @override
  String get toolOpenAppDesc => 'Open URLs, phone, maps, email on device';

  @override
  String get toolAlarm => 'Alarm / Timer';

  @override
  String get toolAlarmDesc => 'Set alarms and timers via system Clock app';

  @override
  String get toolNotifications => 'Notifications';

  @override
  String get toolNotificationsDesc =>
      'Create and schedule local notifications / reminders';

  @override
  String get toolContacts => 'Contacts';

  @override
  String get toolContactsDesc => 'Search and read device contacts (read-only)';

  @override
  String get toolCalendar => 'Calendar';

  @override
  String get toolCalendarDesc => 'Read and create calendar events';

  @override
  String get toolOcr => 'OCR';

  @override
  String get toolOcrDesc => 'Extract text from images (on-device ML Kit)';

  @override
  String get toolQrGenerate => 'QR Code';

  @override
  String get toolQrGenerateDesc => 'Generate QR code images from text or URLs';

  @override
  String get toolPickImage => 'Image Picker';

  @override
  String get toolPickImageDesc =>
      'Pick photos from gallery or take with camera';

  @override
  String get toolVolumeControl => 'Volume Control';

  @override
  String get toolVolumeControlDesc =>
      'Read and adjust device volume levels (alarm, media, etc.)';

  @override
  String get toolGeocode => 'Geocode';

  @override
  String get toolGeocodeDesc =>
      'Convert address to GPS coordinates (OpenRouteService)';

  @override
  String get toolDirections => 'Directions';

  @override
  String get toolDirectionsDesc =>
      'Route calculation (car, bike, walk) via OpenRouteService';

  @override
  String get toolTransit => 'Public Transit';

  @override
  String get toolTransitDesc => 'Metro, RER, bus, train routes (SNCF + IDFM)';

  @override
  String get toolWeather => 'Weather';

  @override
  String get toolWeatherDesc =>
      'Weather forecast via Open-Meteo (Météo-France models)';

  @override
  String get toolRadio => 'Radio France';

  @override
  String get toolRadioDesc =>
      'Play live Radio France streams (France Inter, FIP, etc.)';

  @override
  String get toolKnowledgeSearch => 'Knowledge Search';

  @override
  String get toolKnowledgeSearchDesc =>
      'Search remembered knowledge from past conversations';

  @override
  String get toolKnowledgeStore => 'Knowledge Store';

  @override
  String get toolKnowledgeStoreDesc =>
      'Store a fact to remember across conversations';

  @override
  String get weatherClearSky => 'Clear sky';

  @override
  String get weatherMainlyClear => 'Mainly clear';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherOvercast => 'Overcast';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherLightDrizzle => 'Light drizzle';

  @override
  String get weatherModerateDrizzle => 'Moderate drizzle';

  @override
  String get weatherDenseDrizzle => 'Dense drizzle';

  @override
  String get weatherFreezingDrizzle => 'Freezing drizzle';

  @override
  String get weatherLightRain => 'Light rain';

  @override
  String get weatherModerateRain => 'Moderate rain';

  @override
  String get weatherHeavyRain => 'Heavy rain';

  @override
  String get weatherFreezingRain => 'Freezing rain';

  @override
  String get weatherLightSnow => 'Light snow';

  @override
  String get weatherModerateSnow => 'Moderate snow';

  @override
  String get weatherHeavySnow => 'Heavy snow';

  @override
  String get weatherSleet => 'Sleet';

  @override
  String get weatherLightShowers => 'Light showers';

  @override
  String get weatherModerateShowers => 'Moderate showers';

  @override
  String get weatherViolentShowers => 'Violent showers';

  @override
  String get weatherLightSnowShowers => 'Light snow showers';

  @override
  String get weatherHeavySnowShowers => 'Heavy snow showers';

  @override
  String get weatherThunderstorm => 'Thunderstorm';

  @override
  String get weatherThunderstormLightHail => 'Thunderstorm with light hail';

  @override
  String get weatherThunderstormHeavyHail => 'Thunderstorm with heavy hail';

  @override
  String weatherUnknown(int code) {
    return 'Unknown (code $code)';
  }

  @override
  String weatherToday(String date) {
    return 'Today ($date)';
  }

  @override
  String get weatherTodayShort => 'Today';

  @override
  String get weatherMorning => 'Morning (9h)';

  @override
  String get weatherAfternoon => 'Afternoon (15h)';

  @override
  String get weatherEvening => 'Evening (21h)';

  @override
  String weatherWind(int speed) {
    return 'wind $speed km/h';
  }

  @override
  String get transitTransfer => 'transfer';

  @override
  String get transitWaiting => 'waiting';

  @override
  String get transitDuration => 'Duration:';

  @override
  String get transitDeparture => 'Dep:';

  @override
  String get transitArrival => 'Arr:';

  @override
  String get transitDirect => 'direct';

  @override
  String transitTransferCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count transfer$_temp0';
  }

  @override
  String transitOption(int index, String api) {
    return 'Option $index (via $api)';
  }

  @override
  String get transitSections => 'Sections:';

  @override
  String get transitNoRoutes =>
      'No transit routes found between these locations.';

  @override
  String get transitNoApiKey =>
      'No transit API key configured. Set SNCF or PRIM key in Settings > Routing.';

  @override
  String transitInvalidKey(String api) {
    return '$api API key is invalid. Check it in Settings > Routing.';
  }

  @override
  String get transitRateLimit =>
      'Transit API rate limit reached. Try again later.';

  @override
  String get transitSncfRequired =>
      'SNCF API key needed for trips outside Île-de-France. Set it in Settings > Routing.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String commonFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get commonEnterApiKey => 'Please enter an API key';

  @override
  String get noProviderConfigured =>
      'No LLM provider configured. Please set up a provider in Settings.';

  @override
  String get telegramBotPrivate => 'This bot is private.';

  @override
  String get localeSettingsTitle => 'Language';

  @override
  String get localeSystem => 'System default';

  @override
  String get localeEnglish => 'English';

  @override
  String get localeFrench => 'French';

  @override
  String get localeSpanish => 'Spanish';

  @override
  String get localeGerman => 'German';

  @override
  String get localeItalian => 'Italian';

  @override
  String get agentLanguageDirective =>
      'RESPONSE LANGUAGE: ENGLISH. You MUST always respond in English.';

  @override
  String get agentKeyBehaviors =>
      'Key behaviors:\n- BEFORE calling any tool, check the <knowledge_context> and memory above. If they already contain the answer (address, preference, contact, etc.), respond directly — do NOT call tools for information you already have.\n- Use knowledge data as tool input when chaining: if you know the user\'s home address from the knowledge context, pass it to geocode instead of calling get_location.\n- get_location returns the device CURRENT physical position only. Use it for \"where am I now\", \"nearest X\", \"from my current position\" — never for stored addresses or known places.\n- When you need information NOT in the knowledge context, call the appropriate tool(s) immediately without asking permission.\n- Chain tools when needed: if a tool requires coordinates but you have an address (from knowledge or the user), call geocode first.\n- When the user tells you personal information to remember (e.g. \"I live at...\", \"my dentist is...\"), just acknowledge and store it via knowledge_store. Do NOT call other tools or suggest actions in response.\n- Be concise and helpful. Use markdown formatting.';

  @override
  String get agentRespondInstructions =>
      'You MUST respond in English. All your output text must be in English.';

  @override
  String get batteryCharging => 'charging';

  @override
  String get batteryDischarging => 'discharging';

  @override
  String get batteryFull => 'full';

  @override
  String get batteryConnectedNotCharging => 'connected (not charging)';

  @override
  String get batteryUnknown => 'unknown';

  @override
  String agentLlmError(String error) {
    return 'LLM call failed: $error';
  }

  @override
  String get agentMaxIterations => 'Maximum tool iterations reached.';

  @override
  String agentError(String error) {
    return 'Error: $error';
  }

  @override
  String get telegramErrorGeneric =>
      'Sorry, I encountered an error. Please try again.';

  @override
  String get telegramErrorProcessing =>
      'An error occurred while processing your message.';

  @override
  String get notifChannelName => 'DroidClaw Background Service';

  @override
  String get notifChannelDesc =>
      'Background service for Telegram bot and scheduled prompts';

  @override
  String get notifServiceActive => 'DroidClaw - Active';

  @override
  String get notifServiceRunning => 'Background service running';

  @override
  String get notifBotActive => 'DroidClaw Bot - Active';

  @override
  String notifBotMessages(int count) {
    return 'Messages processed: $count';
  }

  @override
  String get notifBotError => 'DroidClaw Bot - Error';

  @override
  String get notifBotInvalidToken => 'Invalid bot token';

  @override
  String get notifBotDisconnected => 'DroidClaw Bot - Disconnected';

  @override
  String get notifBotRetrying => 'Retrying...';

  @override
  String notifLastCron(String name) {
    return 'Last cron: $name';
  }

  @override
  String cronLastRun(String date) {
    return 'Last: $date';
  }

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsEmpty => 'No log entries';

  @override
  String get logsFilterAll => 'All';

  @override
  String get logsFilterInfo => 'Info';

  @override
  String get logsFilterWarning => 'Warning';

  @override
  String get logsFilterError => 'Error';

  @override
  String get logsSourceAgent => 'Agent';

  @override
  String get logsSourceCron => 'Cron';

  @override
  String get logsSourceService => 'Service';

  @override
  String get logsSourceTelegram => 'Telegram';

  @override
  String get logsSourceApp => 'App';

  @override
  String get logsClearAll => 'Clear all logs';

  @override
  String get logsClearConfirm => 'Delete all log entries?';

  @override
  String logsEntryCount(int count) {
    return '$count entries';
  }

  @override
  String get logsCleared => 'Logs cleared';

  @override
  String logsPurged(int count) {
    return 'Purged $count old log entries';
  }

  @override
  String get cronDeleteGroup => 'Delete all executions for this cron?';

  @override
  String get cronDeleteExecution => 'Delete this execution?';

  @override
  String cronDeleteGroupCount(int count) {
    return 'This will delete $count sessions.';
  }

  @override
  String get chatListening => 'Listening...';

  @override
  String chatSpeechError(String error) {
    return 'Speech recognition error: $error';
  }

  @override
  String get chatSpeechUnavailable =>
      'Speech recognition unavailable on this device';

  @override
  String get agentSummarizeInstructions => 'Write the summary in English.';

  @override
  String get settingsExportConversations => 'Export Conversations';

  @override
  String get settingsExportSubtitle => 'Share all conversations as JSON';

  @override
  String get exportProgress => 'Exporting...';

  @override
  String exportSuccess(int count) {
    return '$count conversations exported';
  }

  @override
  String get exportEmpty => 'No conversations to export';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get knowledgeTitle => 'Knowledge Graph';

  @override
  String get knowledgeSubtitle => 'Persistent memory across conversations';

  @override
  String get knowledgeEnable => 'Enable Knowledge Graph';

  @override
  String get knowledgeEnableDesc =>
      'Automatically extract and remember knowledge from conversations';

  @override
  String get knowledgeAutoExtract => 'Auto-extract';

  @override
  String get knowledgeAutoExtractDesc =>
      'Extract entities and facts after each response';

  @override
  String knowledgeStatsEntities(int count) {
    return '$count entities';
  }

  @override
  String knowledgeStatsRelations(int count) {
    return '$count relations';
  }

  @override
  String knowledgeStatsSize(String size) {
    return 'Database size: $size';
  }

  @override
  String get knowledgeForgetAll => 'Forget Everything';

  @override
  String get knowledgeForgetAllDesc => 'Delete all remembered knowledge';

  @override
  String get knowledgeForgetConfirmTitle => 'Forget Everything?';

  @override
  String get knowledgeForgetConfirmBody =>
      'This will permanently delete all entities, relations, and facts from the knowledge graph. This cannot be undone.';

  @override
  String get knowledgeForgetConfirmButton => 'Forget All';

  @override
  String get knowledgeEmpty => 'No knowledge stored yet';

  @override
  String get knowledgeForgotten => 'All knowledge deleted';

  @override
  String get settingsKnowledge => 'Knowledge Graph';

  @override
  String get settingsKnowledgeSubtitle => 'Persistent memory settings';

  @override
  String get llmTracesTitle => 'LLM Traces';

  @override
  String get llmTracesEmpty => 'No traces recorded';

  @override
  String llmTracesStatsHeader(int count, String tokens, String latency) {
    return '$count calls · $tokens tokens · ${latency}s avg';
  }

  @override
  String get llmTracesLast24h => 'Last 24 hours';

  @override
  String get llmTracesFilterAll => 'All';

  @override
  String get llmTracesFilterChat => 'Chat';

  @override
  String get llmTracesFilterSummarize => 'Summarize';

  @override
  String get llmTracesFilterExtract => 'Extract';

  @override
  String get llmTracesClearAll => 'Clear all traces';

  @override
  String get llmTracesClearConfirm => 'Delete all LLM trace entries?';

  @override
  String get llmTracesCleared => 'Traces cleared';

  @override
  String get llmTraceDetailTitle => 'Trace Detail';

  @override
  String get llmTraceTokens => 'Tokens';

  @override
  String get llmTraceTokensIn => 'In';

  @override
  String get llmTraceTokensOut => 'Out';

  @override
  String get llmTraceTokensTotal => 'Total';

  @override
  String llmTraceLatency(int ms) {
    return 'Latency: $ms ms';
  }

  @override
  String llmTraceSystemPrompt(int chars) {
    return 'System prompt ($chars chars)';
  }

  @override
  String llmTraceMessages(int count) {
    return 'Messages ($count)';
  }

  @override
  String llmTraceResponse(int chars) {
    return 'Response ($chars chars)';
  }

  @override
  String get llmTraceToolsCalled => 'Tools called';

  @override
  String get llmTraceFinishReason => 'Finish reason';

  @override
  String get llmTraceError => 'Error';

  @override
  String llmTraceIteration(int n) {
    return 'iter $n';
  }

  @override
  String get settingsLlmTraces => 'LLM Traces';

  @override
  String get settingsLlmTracesSubtitle => 'API call history and token usage';

  @override
  String get knowledgeBrowse => 'Browse Entities';

  @override
  String get knowledgeBrowseSubtitle => 'Inspect stored knowledge';

  @override
  String get knowledgeLanguageLabel => 'Knowledge language';

  @override
  String knowledgeLanguageLocked(String language) {
    return 'All knowledge is stored in $language. Change via Forget All.';
  }

  @override
  String get kgBrowserTitle => 'Knowledge Browser';

  @override
  String get kgBrowserSearch => 'Search entities...';

  @override
  String get kgBrowserEmpty => 'No entities found';

  @override
  String get kgFilterAll => 'All';

  @override
  String get kgFilterPerson => 'Person';

  @override
  String get kgFilterPlace => 'Place';

  @override
  String get kgFilterOrg => 'Org';

  @override
  String get kgFilterEvent => 'Event';

  @override
  String get kgFilterConcept => 'Concept';

  @override
  String get kgFilterDate => 'Date';

  @override
  String get kgFilterHot => 'Hot';

  @override
  String get kgFilterWarm => 'Warm';

  @override
  String get kgFilterCool => 'Cool';

  @override
  String get kgFilterCold => 'Cold';

  @override
  String get kgEntityFacts => 'Facts';

  @override
  String get kgEntityRelations => 'Relations';

  @override
  String get kgEntityAliases => 'Aliases';

  @override
  String get kgEntityDecay => 'Decay Diagnostics';

  @override
  String get kgEntityDelete => 'Delete Entity';

  @override
  String get kgEntityDeleteConfirm =>
      'Deactivate this entity? It will no longer appear in queries.';

  @override
  String get kgEntityDeleted => 'Entity deactivated';

  @override
  String kgFactCount(int count) {
    return '$count facts';
  }

  @override
  String get kgRetentionScore => 'Retention score';

  @override
  String get kgLoadMore => 'Load more';

  @override
  String get settingsEmbedding => 'Embeddings';

  @override
  String get settingsEmbeddingSubtitle => 'Vector embedding provider';

  @override
  String get embeddingTitle => 'Embedding Provider';

  @override
  String get embeddingDescription =>
      'Configure a remote embedding API for semantic search in the Knowledge Graph. Gemini offers a generous free tier.';

  @override
  String get embeddingProvider => 'Provider';

  @override
  String get embeddingProviderNone => 'None (disabled)';

  @override
  String get embeddingModel => 'Model';

  @override
  String get embeddingDimensions => 'Dimensions';

  @override
  String get embeddingUseOwnApiKey => 'Use dedicated API key';

  @override
  String get embeddingUseOwnApiKeySubtitle => 'Off = reuse LLM provider key';

  @override
  String get embeddingApiKey => 'Embedding API Key';

  @override
  String get embeddingTestButton => 'Test Embedding';

  @override
  String embeddingTestSuccess(int dims, int ms) {
    return 'Success! Vector of $dims dimensions in ${ms}ms';
  }

  @override
  String get embeddingSave => 'Save';

  @override
  String get embeddingSaved => 'Embedding provider saved';
}
