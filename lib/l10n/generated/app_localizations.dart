import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw'**
  String get appName;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw'**
  String get chatTitle;

  /// No description provided for @chatConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatConversations;

  /// No description provided for @chatNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get chatNewSession;

  /// No description provided for @chatSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get chatSettings;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal AI assistant.\nType a message to get started.'**
  String get chatEmptySubtitle;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message DroidClaw...'**
  String get chatInputHint;

  /// No description provided for @chatVoiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get chatVoiceInput;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get chatCopied;

  /// No description provided for @chatCalling.
  ///
  /// In en, this message translates to:
  /// **'Calling {name}...'**
  String chatCalling(String name);

  /// No description provided for @statusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking...'**
  String get statusThinking;

  /// No description provided for @statusThinkingStep.
  ///
  /// In en, this message translates to:
  /// **'Thinking (step {step})...'**
  String statusThinkingStep(int step);

  /// No description provided for @statusSummarizing.
  ///
  /// In en, this message translates to:
  /// **'Summarizing conversation...'**
  String get statusSummarizing;

  /// No description provided for @statusUsingTool.
  ///
  /// In en, this message translates to:
  /// **'Using {name}...'**
  String statusUsingTool(String name);

  /// No description provided for @statusGotResult.
  ///
  /// In en, this message translates to:
  /// **'Got result from {name}'**
  String statusGotResult(String name);

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get statusProcessing;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get historyTitle;

  /// No description provided for @historySectionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get historySectionChat;

  /// No description provided for @historySectionCron.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Prompts'**
  String get historySectionCron;

  /// No description provided for @historySectionTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get historySectionTelegram;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get historyEmpty;

  /// No description provided for @historyExecutions.
  ///
  /// In en, this message translates to:
  /// **'{count} executions - Last: {date}'**
  String historyExecutions(int count, String date);

  /// No description provided for @historyMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String historyMessages(int count);

  /// No description provided for @historyNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get historyNewConversation;

  /// No description provided for @historyScheduledPrompt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled prompt'**
  String get historyScheduledPrompt;

  /// No description provided for @historyNoExecutions.
  ///
  /// In en, this message translates to:
  /// **'No executions yet'**
  String get historyNoExecutions;

  /// No description provided for @historyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation?'**
  String get historyDeleteTitle;

  /// No description provided for @historyDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String historyDeleteContent(String title);

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyYesterday;

  /// No description provided for @historyError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String historyError(String error);

  /// No description provided for @onboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to DroidClaw'**
  String get onboardWelcome;

  /// No description provided for @onboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal AI assistant on Android.\nLet\'s set up your LLM provider to get started.'**
  String get onboardSubtitle;

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardGetStarted;

  /// No description provided for @onboardChooseProvider.
  ///
  /// In en, this message translates to:
  /// **'Choose a provider'**
  String get onboardChooseProvider;

  /// No description provided for @onboardChooseProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select which LLM provider you want to use.'**
  String get onboardChooseProviderSubtitle;

  /// No description provided for @onboardNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardNext;

  /// No description provided for @onboardEnterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter your API key'**
  String get onboardEnterApiKey;

  /// No description provided for @onboardApiKeySecure.
  ///
  /// In en, this message translates to:
  /// **'Your key is stored securely on device.'**
  String get onboardApiKeySecure;

  /// No description provided for @onboardApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get onboardApiKeyLabel;

  /// No description provided for @onboardTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get onboardTestConnection;

  /// No description provided for @onboardFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish Setup'**
  String get onboardFinishSetup;

  /// No description provided for @onboardTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected! Response: {response}'**
  String onboardTestSuccess(String response);

  /// No description provided for @onboardEnterApiKeyError.
  ///
  /// In en, this message translates to:
  /// **'Please enter an API key'**
  String get onboardEnterApiKeyError;

  /// No description provided for @providerOpenRouter.
  ///
  /// In en, this message translates to:
  /// **'OpenRouter'**
  String get providerOpenRouter;

  /// No description provided for @providerOpenRouterDesc.
  ///
  /// In en, this message translates to:
  /// **'Access many models with one API key'**
  String get providerOpenRouterDesc;

  /// No description provided for @providerAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Anthropic'**
  String get providerAnthropic;

  /// No description provided for @providerAnthropicDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct access to Claude models'**
  String get providerAnthropicDesc;

  /// No description provided for @providerOpenAI.
  ///
  /// In en, this message translates to:
  /// **'OpenAI'**
  String get providerOpenAI;

  /// No description provided for @providerOpenAIDesc.
  ///
  /// In en, this message translates to:
  /// **'Access to GPT models'**
  String get providerOpenAIDesc;

  /// No description provided for @providerGroq.
  ///
  /// In en, this message translates to:
  /// **'Groq'**
  String get providerGroq;

  /// No description provided for @providerGroqDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast inference for open models'**
  String get providerGroqDesc;

  /// No description provided for @providerGemini.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini'**
  String get providerGemini;

  /// No description provided for @providerGeminiDesc.
  ///
  /// In en, this message translates to:
  /// **'Google AI models with free tier'**
  String get providerGeminiDesc;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionProvider.
  ///
  /// In en, this message translates to:
  /// **'LLM Provider'**
  String get settingsSectionProvider;

  /// No description provided for @settingsProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsProvider;

  /// No description provided for @settingsModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsModel;

  /// No description provided for @settingsSectionAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get settingsSectionAgent;

  /// No description provided for @settingsMaxTokens.
  ///
  /// In en, this message translates to:
  /// **'Max tokens'**
  String get settingsMaxTokens;

  /// No description provided for @settingsTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get settingsTemperature;

  /// No description provided for @settingsMaxToolIterations.
  ///
  /// In en, this message translates to:
  /// **'Max tool iterations'**
  String get settingsMaxToolIterations;

  /// No description provided for @settingsSectionTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get settingsSectionTools;

  /// No description provided for @settingsManageTools.
  ///
  /// In en, this message translates to:
  /// **'Manage Tools'**
  String get settingsManageTools;

  /// No description provided for @settingsManageToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable agent tools'**
  String get settingsManageToolsSubtitle;

  /// No description provided for @settingsWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get settingsWebSearch;

  /// No description provided for @settingsWebSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Brave Search API'**
  String get settingsWebSearchSubtitle;

  /// No description provided for @settingsRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get settingsRouting;

  /// No description provided for @settingsRoutingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure routing & transit APIs'**
  String get settingsRoutingSubtitle;

  /// No description provided for @settingsScheduledPrompts.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Prompts'**
  String get settingsScheduledPrompts;

  /// No description provided for @settingsScheduledPromptsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automated recurring tasks'**
  String get settingsScheduledPromptsSubtitle;

  /// No description provided for @settingsSectionChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get settingsSectionChannels;

  /// No description provided for @settingsTelegramBot.
  ///
  /// In en, this message translates to:
  /// **'Telegram Bot'**
  String get settingsTelegramBot;

  /// No description provided for @settingsTelegramRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get settingsTelegramRunning;

  /// No description provided for @settingsTelegramDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get settingsTelegramDisabled;

  /// No description provided for @settingsSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get settingsSkills;

  /// No description provided for @settingsSkillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage installed skills'**
  String get settingsSkillsSubtitle;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @providerConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Provider Config'**
  String get providerConfigTitle;

  /// No description provided for @providerConfigProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get providerConfigProviderLabel;

  /// No description provided for @providerConfigApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get providerConfigApiKeyLabel;

  /// No description provided for @providerConfigModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model (optional)'**
  String get providerConfigModelLabel;

  /// No description provided for @providerConfigModelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. claude-sonnet-4-20250514'**
  String get providerConfigModelHint;

  /// No description provided for @providerConfigApiBaseLabel.
  ///
  /// In en, this message translates to:
  /// **'API Base URL (optional)'**
  String get providerConfigApiBaseLabel;

  /// No description provided for @providerConfigApiBaseHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for default'**
  String get providerConfigApiBaseHint;

  /// No description provided for @providerConfigTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get providerConfigTestConnection;

  /// No description provided for @providerConfigSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get providerConfigSave;

  /// No description provided for @providerConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get providerConfigSaved;

  /// No description provided for @providerConfigTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful! Response: {response}'**
  String providerConfigTestSuccess(String response);

  /// No description provided for @providerConfigTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String providerConfigTestFailed(String error);

  /// No description provided for @telegramTitle.
  ///
  /// In en, this message translates to:
  /// **'Telegram Bot'**
  String get telegramTitle;

  /// No description provided for @telegramBotToken.
  ///
  /// In en, this message translates to:
  /// **'Bot Token'**
  String get telegramBotToken;

  /// No description provided for @telegramBotTokenHelper.
  ///
  /// In en, this message translates to:
  /// **'Get one from @BotFather on Telegram'**
  String get telegramBotTokenHelper;

  /// No description provided for @telegramTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get telegramTestConnection;

  /// No description provided for @telegramTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connected! Bot: @{username}'**
  String telegramTestSuccess(String username);

  /// No description provided for @telegramEnableBot.
  ///
  /// In en, this message translates to:
  /// **'Enable Bot'**
  String get telegramEnableBot;

  /// No description provided for @telegramBotRunning.
  ///
  /// In en, this message translates to:
  /// **'Bot is running'**
  String get telegramBotRunning;

  /// No description provided for @telegramBotStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get telegramBotStarting;

  /// No description provided for @telegramBotDisabled.
  ///
  /// In en, this message translates to:
  /// **'Bot is disabled'**
  String get telegramBotDisabled;

  /// No description provided for @telegramBotActive.
  ///
  /// In en, this message translates to:
  /// **'Bot Active'**
  String get telegramBotActive;

  /// No description provided for @telegramMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String telegramMessages(int count);

  /// No description provided for @telegramLastMessage.
  ///
  /// In en, this message translates to:
  /// **'Last: {time}'**
  String telegramLastMessage(String time);

  /// No description provided for @telegramAllowedUsers.
  ///
  /// In en, this message translates to:
  /// **'Allowed Users (optional)'**
  String get telegramAllowedUsers;

  /// No description provided for @telegramAllowedUsersHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated Telegram usernames. Leave empty for all.'**
  String get telegramAllowedUsersHelper;

  /// No description provided for @telegramAllowedUsersHint.
  ///
  /// In en, this message translates to:
  /// **'alice, bob, charlie'**
  String get telegramAllowedUsersHint;

  /// No description provided for @telegramSaveUsers.
  ///
  /// In en, this message translates to:
  /// **'Save Users'**
  String get telegramSaveUsers;

  /// No description provided for @telegramUsersUpdated.
  ///
  /// In en, this message translates to:
  /// **'Allowed users updated'**
  String get telegramUsersUpdated;

  /// No description provided for @telegramEnterToken.
  ///
  /// In en, this message translates to:
  /// **'Please enter a bot token first'**
  String get telegramEnterToken;

  /// No description provided for @telegramEnterTokenError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a bot token'**
  String get telegramEnterTokenError;

  /// No description provided for @telegramHowToSetup.
  ///
  /// In en, this message translates to:
  /// **'How to set up'**
  String get telegramHowToSetup;

  /// No description provided for @telegramSetupSteps.
  ///
  /// In en, this message translates to:
  /// **'1. Open Telegram and search for @BotFather\n2. Send /newbot and follow the instructions\n3. Copy the bot token and paste it above\n4. Test the connection, then enable the bot\n5. Send a message to your bot on Telegram!'**
  String get telegramSetupSteps;

  /// No description provided for @webSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get webSearchTitle;

  /// No description provided for @webSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Web search works without a key using DuckDuckGo, but Brave Search gives faster, higher-quality results.'**
  String get webSearchDescription;

  /// No description provided for @webSearchApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Brave Search API Key'**
  String get webSearchApiKeyLabel;

  /// No description provided for @webSearchTestSearch.
  ///
  /// In en, this message translates to:
  /// **'Test Search'**
  String get webSearchTestSearch;

  /// No description provided for @webSearchSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get webSearchSave;

  /// No description provided for @webSearchSaved.
  ///
  /// In en, this message translates to:
  /// **'Brave API key saved'**
  String get webSearchSaved;

  /// No description provided for @webSearchTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Search successful! Results received.'**
  String get webSearchTestSuccess;

  /// No description provided for @routingTitle.
  ///
  /// In en, this message translates to:
  /// **'Routing & Transit'**
  String get routingTitle;

  /// No description provided for @routingSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get routingSave;

  /// No description provided for @routingSaved.
  ///
  /// In en, this message translates to:
  /// **'API keys saved'**
  String get routingSaved;

  /// No description provided for @routingOrsTitle.
  ///
  /// In en, this message translates to:
  /// **'OpenRouteService'**
  String get routingOrsTitle;

  /// No description provided for @routingOrsDesc.
  ///
  /// In en, this message translates to:
  /// **'Free API key at openrouteservice.org for car, bike, and walking routes.'**
  String get routingOrsDesc;

  /// No description provided for @routingOrsKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'ORS API Key'**
  String get routingOrsKeyLabel;

  /// No description provided for @routingOrsTestRoute.
  ///
  /// In en, this message translates to:
  /// **'Test Route (Paris → Versailles)'**
  String get routingOrsTestRoute;

  /// No description provided for @routingOrsTestGeocode.
  ///
  /// In en, this message translates to:
  /// **'Test Geocode (Tour Eiffel, Paris)'**
  String get routingOrsTestGeocode;

  /// No description provided for @routingSncfTitle.
  ///
  /// In en, this message translates to:
  /// **'SNCF (National Trains)'**
  String get routingSncfTitle;

  /// No description provided for @routingSncfDesc.
  ///
  /// In en, this message translates to:
  /// **'Free API key at ressources.data.sncf.com for TGV, TER, and Intercités routes across France.'**
  String get routingSncfDesc;

  /// No description provided for @routingSncfKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'SNCF API Key'**
  String get routingSncfKeyLabel;

  /// No description provided for @routingSncfTestTransit.
  ///
  /// In en, this message translates to:
  /// **'Test Transit (Paris → Lyon)'**
  String get routingSncfTestTransit;

  /// No description provided for @routingPrimTitle.
  ///
  /// In en, this message translates to:
  /// **'PRIM / IDFM (Île-de-France)'**
  String get routingPrimTitle;

  /// No description provided for @routingPrimDesc.
  ///
  /// In en, this message translates to:
  /// **'Free API key at prim.iledefrance-mobilites.fr for Métro, RER, Bus, and Tram in Paris region.'**
  String get routingPrimDesc;

  /// No description provided for @routingPrimKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'PRIM API Key'**
  String get routingPrimKeyLabel;

  /// No description provided for @routingPrimTestTransit.
  ///
  /// In en, this message translates to:
  /// **'Test Transit (Gare de Lyon → Châtelet)'**
  String get routingPrimTestTransit;

  /// No description provided for @cronTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Prompts'**
  String get cronTitle;

  /// No description provided for @cronEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scheduled prompts'**
  String get cronEmpty;

  /// No description provided for @cronEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create a recurring prompt.\nThe AI will run it automatically on schedule.'**
  String get cronEmptySubtitle;

  /// No description provided for @cronServiceRunning.
  ///
  /// In en, this message translates to:
  /// **'Background service running'**
  String get cronServiceRunning;

  /// No description provided for @cronServiceNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Background service not running'**
  String get cronServiceNotRunning;

  /// No description provided for @cronNoPromptsEnabled.
  ///
  /// In en, this message translates to:
  /// **'No prompts enabled'**
  String get cronNoPromptsEnabled;

  /// No description provided for @cronNeverRan.
  ///
  /// In en, this message translates to:
  /// **'Never ran'**
  String get cronNeverRan;

  /// No description provided for @cronDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete scheduled prompt?'**
  String get cronDeleteTitle;

  /// No description provided for @cronDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String cronDeleteContent(String name);

  /// No description provided for @cronViewExecutions.
  ///
  /// In en, this message translates to:
  /// **'View executions'**
  String get cronViewExecutions;

  /// No description provided for @cronEditTitle.
  ///
  /// In en, this message translates to:
  /// **'New Prompt'**
  String get cronEditTitle;

  /// No description provided for @cronEditTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Prompt'**
  String get cronEditTitleEdit;

  /// No description provided for @cronEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get cronEditSave;

  /// No description provided for @cronEditName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cronEditName;

  /// No description provided for @cronEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Daily news brief'**
  String get cronEditNameHint;

  /// No description provided for @cronEditPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get cronEditPrompt;

  /// No description provided for @cronEditPromptHint.
  ///
  /// In en, this message translates to:
  /// **'What should the AI do?'**
  String get cronEditPromptHint;

  /// No description provided for @cronEditSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get cronEditSchedule;

  /// No description provided for @cronEditInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get cronEditInterval;

  /// No description provided for @cronEditSpecificTimes.
  ///
  /// In en, this message translates to:
  /// **'Specific times'**
  String get cronEditSpecificTimes;

  /// No description provided for @cronEditAddTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get cronEditAddTime;

  /// No description provided for @cronEditDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get cronEditDays;

  /// No description provided for @cronEditConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get cronEditConversation;

  /// No description provided for @cronEditNewEach.
  ///
  /// In en, this message translates to:
  /// **'New conversation each time'**
  String get cronEditNewEach;

  /// No description provided for @cronEditNewEachSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each execution is independent'**
  String get cronEditNewEachSubtitle;

  /// No description provided for @cronEditSameThread.
  ///
  /// In en, this message translates to:
  /// **'Continue in same thread'**
  String get cronEditSameThread;

  /// No description provided for @cronEditSameThreadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The AI remembers previous executions'**
  String get cronEditSameThreadSubtitle;

  /// No description provided for @cronEditNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and prompt are required'**
  String get cronEditNameRequired;

  /// No description provided for @cronEditTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one time'**
  String get cronEditTimeRequired;

  /// No description provided for @cronEditInterval15.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get cronEditInterval15;

  /// No description provided for @cronEditInterval30.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get cronEditInterval30;

  /// No description provided for @cronEditInterval1h.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get cronEditInterval1h;

  /// No description provided for @cronEditInterval2h.
  ///
  /// In en, this message translates to:
  /// **'2 hours'**
  String get cronEditInterval2h;

  /// No description provided for @cronEditInterval6h.
  ///
  /// In en, this message translates to:
  /// **'6 hours'**
  String get cronEditInterval6h;

  /// No description provided for @cronEditInterval12h.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get cronEditInterval12h;

  /// No description provided for @cronEditInterval24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get cronEditInterval24h;

  /// No description provided for @cronEditMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get cronEditMon;

  /// No description provided for @cronEditTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get cronEditTue;

  /// No description provided for @cronEditWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get cronEditWed;

  /// No description provided for @cronEditThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get cronEditThu;

  /// No description provided for @cronEditFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get cronEditFri;

  /// No description provided for @cronEditSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get cronEditSat;

  /// No description provided for @cronEditSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get cronEditSun;

  /// No description provided for @cronDisplayEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'Every {minutes} min'**
  String cronDisplayEveryMinutes(int minutes);

  /// No description provided for @cronDisplayEveryHour.
  ///
  /// In en, this message translates to:
  /// **'Every hour'**
  String get cronDisplayEveryHour;

  /// No description provided for @cronDisplayEveryHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} hours'**
  String cronDisplayEveryHours(int hours);

  /// No description provided for @cronDisplayDailyAt.
  ///
  /// In en, this message translates to:
  /// **'Daily at {times}'**
  String cronDisplayDailyAt(String times);

  /// No description provided for @cronDisplayAt.
  ///
  /// In en, this message translates to:
  /// **'At {times}'**
  String cronDisplayAt(String times);

  /// No description provided for @skillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsTitle;

  /// No description provided for @skillsGithubUrl.
  ///
  /// In en, this message translates to:
  /// **'GitHub URL'**
  String get skillsGithubUrl;

  /// No description provided for @skillsGithubUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://github.com/user/repo/blob/main/SKILL.md'**
  String get skillsGithubUrlHint;

  /// No description provided for @skillsInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get skillsInstall;

  /// No description provided for @skillsNoSkills.
  ///
  /// In en, this message translates to:
  /// **'No skills installed'**
  String get skillsNoSkills;

  /// No description provided for @skillsInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed skill: {name}'**
  String skillsInstalled(String name);

  /// No description provided for @skillsInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Install failed: {error}'**
  String skillsInstallFailed(String error);

  /// No description provided for @skillsUninstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Uninstall Skill'**
  String get skillsUninstallTitle;

  /// No description provided for @skillsUninstallContent.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\"?'**
  String skillsUninstallContent(String name);

  /// No description provided for @skillsUninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get skillsUninstall;

  /// No description provided for @skillsUninstalled.
  ///
  /// In en, this message translates to:
  /// **'Uninstalled: {name}'**
  String skillsUninstalled(String name);

  /// No description provided for @skillsUninstallFailed.
  ///
  /// In en, this message translates to:
  /// **'Uninstall failed: {error}'**
  String skillsUninstallFailed(String error);

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Tools'**
  String get toolsTitle;

  /// No description provided for @toolWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get toolWebSearch;

  /// No description provided for @toolWebSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Search the web via Brave API'**
  String get toolWebSearchDesc;

  /// No description provided for @toolWebScrape.
  ///
  /// In en, this message translates to:
  /// **'Web Scrape'**
  String get toolWebScrape;

  /// No description provided for @toolWebScrapeDesc.
  ///
  /// In en, this message translates to:
  /// **'Lightweight page scraping (HTTP + Markdown)'**
  String get toolWebScrapeDesc;

  /// No description provided for @toolWebScrapeJs.
  ///
  /// In en, this message translates to:
  /// **'Web Scrape (JS)'**
  String get toolWebScrapeJs;

  /// No description provided for @toolWebScrapeJsDesc.
  ///
  /// In en, this message translates to:
  /// **'Heavy JS-rendered page scraping (WebView)'**
  String get toolWebScrapeJsDesc;

  /// No description provided for @toolFile.
  ///
  /// In en, this message translates to:
  /// **'File Access'**
  String get toolFile;

  /// No description provided for @toolFileDesc.
  ///
  /// In en, this message translates to:
  /// **'Read and write files in workspace'**
  String get toolFileDesc;

  /// No description provided for @toolLocation.
  ///
  /// In en, this message translates to:
  /// **'GPS Location'**
  String get toolLocation;

  /// No description provided for @toolLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Access device GPS coordinates'**
  String get toolLocationDesc;

  /// No description provided for @toolAddress.
  ///
  /// In en, this message translates to:
  /// **'Reverse Geocoding'**
  String get toolAddress;

  /// No description provided for @toolAddressDesc.
  ///
  /// In en, this message translates to:
  /// **'Convert GPS coordinates to address'**
  String get toolAddressDesc;

  /// No description provided for @toolSubagent.
  ///
  /// In en, this message translates to:
  /// **'Sub-agent'**
  String get toolSubagent;

  /// No description provided for @toolSubagentDesc.
  ///
  /// In en, this message translates to:
  /// **'Spawn sub-tasks for complex queries'**
  String get toolSubagentDesc;

  /// No description provided for @toolClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get toolClipboard;

  /// No description provided for @toolClipboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Read and write device clipboard'**
  String get toolClipboardDesc;

  /// No description provided for @toolDatetime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get toolDatetime;

  /// No description provided for @toolDatetimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Get current date, time, day of week, timezone'**
  String get toolDatetimeDesc;

  /// No description provided for @toolDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get toolDeviceInfo;

  /// No description provided for @toolDeviceInfoDesc.
  ///
  /// In en, this message translates to:
  /// **'Battery, connectivity, device model'**
  String get toolDeviceInfoDesc;

  /// No description provided for @toolSpeak.
  ///
  /// In en, this message translates to:
  /// **'Text to Speech'**
  String get toolSpeak;

  /// No description provided for @toolSpeakDesc.
  ///
  /// In en, this message translates to:
  /// **'Speak text aloud (foreground only)'**
  String get toolSpeakDesc;

  /// No description provided for @toolOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open App / URL'**
  String get toolOpenApp;

  /// No description provided for @toolOpenAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Open URLs, phone, maps, email on device'**
  String get toolOpenAppDesc;

  /// No description provided for @toolAlarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm / Timer'**
  String get toolAlarm;

  /// No description provided for @toolAlarmDesc.
  ///
  /// In en, this message translates to:
  /// **'Set alarms and timers via system Clock app'**
  String get toolAlarmDesc;

  /// No description provided for @toolNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get toolNotifications;

  /// No description provided for @toolNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Create and schedule local notifications / reminders'**
  String get toolNotificationsDesc;

  /// No description provided for @toolContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get toolContacts;

  /// No description provided for @toolContactsDesc.
  ///
  /// In en, this message translates to:
  /// **'Search and read device contacts (read-only)'**
  String get toolContactsDesc;

  /// No description provided for @toolCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get toolCalendar;

  /// No description provided for @toolCalendarDesc.
  ///
  /// In en, this message translates to:
  /// **'Read and create calendar events'**
  String get toolCalendarDesc;

  /// No description provided for @toolOcr.
  ///
  /// In en, this message translates to:
  /// **'OCR'**
  String get toolOcr;

  /// No description provided for @toolOcrDesc.
  ///
  /// In en, this message translates to:
  /// **'Extract text from images (on-device ML Kit)'**
  String get toolOcrDesc;

  /// No description provided for @toolQrGenerate.
  ///
  /// In en, this message translates to:
  /// **'QR Code'**
  String get toolQrGenerate;

  /// No description provided for @toolQrGenerateDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate QR code images from text or URLs'**
  String get toolQrGenerateDesc;

  /// No description provided for @toolPickImage.
  ///
  /// In en, this message translates to:
  /// **'Image Picker'**
  String get toolPickImage;

  /// No description provided for @toolPickImageDesc.
  ///
  /// In en, this message translates to:
  /// **'Pick photos from gallery or take with camera'**
  String get toolPickImageDesc;

  /// No description provided for @toolVolumeControl.
  ///
  /// In en, this message translates to:
  /// **'Volume Control'**
  String get toolVolumeControl;

  /// No description provided for @toolVolumeControlDesc.
  ///
  /// In en, this message translates to:
  /// **'Read and adjust device volume levels (alarm, media, etc.)'**
  String get toolVolumeControlDesc;

  /// No description provided for @toolGeocode.
  ///
  /// In en, this message translates to:
  /// **'Geocode'**
  String get toolGeocode;

  /// No description provided for @toolGeocodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Convert address to GPS coordinates (OpenRouteService)'**
  String get toolGeocodeDesc;

  /// No description provided for @toolDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get toolDirections;

  /// No description provided for @toolDirectionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Route calculation (car, bike, walk) via OpenRouteService'**
  String get toolDirectionsDesc;

  /// No description provided for @toolTransit.
  ///
  /// In en, this message translates to:
  /// **'Public Transit'**
  String get toolTransit;

  /// No description provided for @toolTransitDesc.
  ///
  /// In en, this message translates to:
  /// **'Metro, RER, bus, train routes (SNCF + IDFM)'**
  String get toolTransitDesc;

  /// No description provided for @toolWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get toolWeather;

  /// No description provided for @toolWeatherDesc.
  ///
  /// In en, this message translates to:
  /// **'Weather forecast via Open-Meteo (Météo-France models)'**
  String get toolWeatherDesc;

  /// No description provided for @toolRadio.
  ///
  /// In en, this message translates to:
  /// **'Radio France'**
  String get toolRadio;

  /// No description provided for @toolRadioDesc.
  ///
  /// In en, this message translates to:
  /// **'Play live Radio France streams (France Inter, FIP, etc.)'**
  String get toolRadioDesc;

  /// No description provided for @weatherClearSky.
  ///
  /// In en, this message translates to:
  /// **'Clear sky'**
  String get weatherClearSky;

  /// No description provided for @weatherMainlyClear.
  ///
  /// In en, this message translates to:
  /// **'Mainly clear'**
  String get weatherMainlyClear;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherOvercast.
  ///
  /// In en, this message translates to:
  /// **'Overcast'**
  String get weatherOvercast;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherLightDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Light drizzle'**
  String get weatherLightDrizzle;

  /// No description provided for @weatherModerateDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Moderate drizzle'**
  String get weatherModerateDrizzle;

  /// No description provided for @weatherDenseDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Dense drizzle'**
  String get weatherDenseDrizzle;

  /// No description provided for @weatherFreezingDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Freezing drizzle'**
  String get weatherFreezingDrizzle;

  /// No description provided for @weatherLightRain.
  ///
  /// In en, this message translates to:
  /// **'Light rain'**
  String get weatherLightRain;

  /// No description provided for @weatherModerateRain.
  ///
  /// In en, this message translates to:
  /// **'Moderate rain'**
  String get weatherModerateRain;

  /// No description provided for @weatherHeavyRain.
  ///
  /// In en, this message translates to:
  /// **'Heavy rain'**
  String get weatherHeavyRain;

  /// No description provided for @weatherFreezingRain.
  ///
  /// In en, this message translates to:
  /// **'Freezing rain'**
  String get weatherFreezingRain;

  /// No description provided for @weatherLightSnow.
  ///
  /// In en, this message translates to:
  /// **'Light snow'**
  String get weatherLightSnow;

  /// No description provided for @weatherModerateSnow.
  ///
  /// In en, this message translates to:
  /// **'Moderate snow'**
  String get weatherModerateSnow;

  /// No description provided for @weatherHeavySnow.
  ///
  /// In en, this message translates to:
  /// **'Heavy snow'**
  String get weatherHeavySnow;

  /// No description provided for @weatherSleet.
  ///
  /// In en, this message translates to:
  /// **'Sleet'**
  String get weatherSleet;

  /// No description provided for @weatherLightShowers.
  ///
  /// In en, this message translates to:
  /// **'Light showers'**
  String get weatherLightShowers;

  /// No description provided for @weatherModerateShowers.
  ///
  /// In en, this message translates to:
  /// **'Moderate showers'**
  String get weatherModerateShowers;

  /// No description provided for @weatherViolentShowers.
  ///
  /// In en, this message translates to:
  /// **'Violent showers'**
  String get weatherViolentShowers;

  /// No description provided for @weatherLightSnowShowers.
  ///
  /// In en, this message translates to:
  /// **'Light snow showers'**
  String get weatherLightSnowShowers;

  /// No description provided for @weatherHeavySnowShowers.
  ///
  /// In en, this message translates to:
  /// **'Heavy snow showers'**
  String get weatherHeavySnowShowers;

  /// No description provided for @weatherThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// No description provided for @weatherThunderstormLightHail.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm with light hail'**
  String get weatherThunderstormLightHail;

  /// No description provided for @weatherThunderstormHeavyHail.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm with heavy hail'**
  String get weatherThunderstormHeavyHail;

  /// No description provided for @weatherUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown (code {code})'**
  String weatherUnknown(int code);

  /// No description provided for @weatherToday.
  ///
  /// In en, this message translates to:
  /// **'Today ({date})'**
  String weatherToday(String date);

  /// No description provided for @weatherTodayShort.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get weatherTodayShort;

  /// No description provided for @weatherMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning (9h)'**
  String get weatherMorning;

  /// No description provided for @weatherAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon (15h)'**
  String get weatherAfternoon;

  /// No description provided for @weatherEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening (21h)'**
  String get weatherEvening;

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'wind {speed} km/h'**
  String weatherWind(int speed);

  /// No description provided for @transitTransfer.
  ///
  /// In en, this message translates to:
  /// **'transfer'**
  String get transitTransfer;

  /// No description provided for @transitWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get transitWaiting;

  /// No description provided for @transitDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration:'**
  String get transitDuration;

  /// No description provided for @transitDeparture.
  ///
  /// In en, this message translates to:
  /// **'Dep:'**
  String get transitDeparture;

  /// No description provided for @transitArrival.
  ///
  /// In en, this message translates to:
  /// **'Arr:'**
  String get transitArrival;

  /// No description provided for @transitDirect.
  ///
  /// In en, this message translates to:
  /// **'direct'**
  String get transitDirect;

  /// No description provided for @transitTransferCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transfer{count, plural, =1{} other{s}}'**
  String transitTransferCount(int count);

  /// No description provided for @transitOption.
  ///
  /// In en, this message translates to:
  /// **'Option {index} (via {api})'**
  String transitOption(int index, String api);

  /// No description provided for @transitSections.
  ///
  /// In en, this message translates to:
  /// **'Sections:'**
  String get transitSections;

  /// No description provided for @transitNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'No transit routes found between these locations.'**
  String get transitNoRoutes;

  /// No description provided for @transitNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'No transit API key configured. Set SNCF or PRIM key in Settings > Routing.'**
  String get transitNoApiKey;

  /// No description provided for @transitInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'{api} API key is invalid. Check it in Settings > Routing.'**
  String transitInvalidKey(String api);

  /// No description provided for @transitRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Transit API rate limit reached. Try again later.'**
  String get transitRateLimit;

  /// No description provided for @transitSncfRequired.
  ///
  /// In en, this message translates to:
  /// **'SNCF API key needed for trips outside Île-de-France. Set it in Settings > Routing.'**
  String get transitSncfRequired;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String commonFailed(String error);

  /// No description provided for @commonEnterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter an API key'**
  String get commonEnterApiKey;

  /// No description provided for @noProviderConfigured.
  ///
  /// In en, this message translates to:
  /// **'No LLM provider configured. Please set up a provider in Settings.'**
  String get noProviderConfigured;

  /// No description provided for @telegramBotPrivate.
  ///
  /// In en, this message translates to:
  /// **'This bot is private.'**
  String get telegramBotPrivate;

  /// No description provided for @localeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localeSettingsTitle;

  /// No description provided for @localeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get localeSystem;

  /// No description provided for @localeEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEnglish;

  /// No description provided for @localeFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get localeFrench;

  /// No description provided for @localeSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get localeSpanish;

  /// No description provided for @localeGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get localeGerman;

  /// No description provided for @localeItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get localeItalian;

  /// No description provided for @agentRespondInstructions.
  ///
  /// In en, this message translates to:
  /// **'Always respond in English, regardless of the language used in previous messages.'**
  String get agentRespondInstructions;

  /// No description provided for @batteryCharging.
  ///
  /// In en, this message translates to:
  /// **'charging'**
  String get batteryCharging;

  /// No description provided for @batteryDischarging.
  ///
  /// In en, this message translates to:
  /// **'discharging'**
  String get batteryDischarging;

  /// No description provided for @batteryFull.
  ///
  /// In en, this message translates to:
  /// **'full'**
  String get batteryFull;

  /// No description provided for @batteryConnectedNotCharging.
  ///
  /// In en, this message translates to:
  /// **'connected (not charging)'**
  String get batteryConnectedNotCharging;

  /// No description provided for @batteryUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get batteryUnknown;

  /// No description provided for @agentLlmError.
  ///
  /// In en, this message translates to:
  /// **'LLM call failed: {error}'**
  String agentLlmError(String error);

  /// No description provided for @agentMaxIterations.
  ///
  /// In en, this message translates to:
  /// **'Maximum tool iterations reached.'**
  String get agentMaxIterations;

  /// No description provided for @agentError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String agentError(String error);

  /// No description provided for @telegramErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I encountered an error. Please try again.'**
  String get telegramErrorGeneric;

  /// No description provided for @telegramErrorProcessing.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while processing your message.'**
  String get telegramErrorProcessing;

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw Background Service'**
  String get notifChannelName;

  /// No description provided for @notifChannelDesc.
  ///
  /// In en, this message translates to:
  /// **'Background service for Telegram bot and scheduled prompts'**
  String get notifChannelDesc;

  /// No description provided for @notifServiceActive.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw - Active'**
  String get notifServiceActive;

  /// No description provided for @notifServiceRunning.
  ///
  /// In en, this message translates to:
  /// **'Background service running'**
  String get notifServiceRunning;

  /// No description provided for @notifBotActive.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw Bot - Active'**
  String get notifBotActive;

  /// No description provided for @notifBotMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages processed: {count}'**
  String notifBotMessages(int count);

  /// No description provided for @notifBotError.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw Bot - Error'**
  String get notifBotError;

  /// No description provided for @notifBotInvalidToken.
  ///
  /// In en, this message translates to:
  /// **'Invalid bot token'**
  String get notifBotInvalidToken;

  /// No description provided for @notifBotDisconnected.
  ///
  /// In en, this message translates to:
  /// **'DroidClaw Bot - Disconnected'**
  String get notifBotDisconnected;

  /// No description provided for @notifBotRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get notifBotRetrying;

  /// No description provided for @notifLastCron.
  ///
  /// In en, this message translates to:
  /// **'Last cron: {name}'**
  String notifLastCron(String name);

  /// No description provided for @cronLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last: {date}'**
  String cronLastRun(String date);

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No log entries'**
  String get logsEmpty;

  /// No description provided for @logsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logsFilterAll;

  /// No description provided for @logsFilterInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get logsFilterInfo;

  /// No description provided for @logsFilterWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get logsFilterWarning;

  /// No description provided for @logsFilterError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logsFilterError;

  /// No description provided for @logsSourceAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get logsSourceAgent;

  /// No description provided for @logsSourceCron.
  ///
  /// In en, this message translates to:
  /// **'Cron'**
  String get logsSourceCron;

  /// No description provided for @logsSourceService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get logsSourceService;

  /// No description provided for @logsSourceTelegram.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get logsSourceTelegram;

  /// No description provided for @logsSourceApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get logsSourceApp;

  /// No description provided for @logsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all logs'**
  String get logsClearAll;

  /// No description provided for @logsClearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all log entries?'**
  String get logsClearConfirm;

  /// No description provided for @logsEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String logsEntryCount(int count);

  /// No description provided for @logsCleared.
  ///
  /// In en, this message translates to:
  /// **'Logs cleared'**
  String get logsCleared;

  /// No description provided for @logsPurged.
  ///
  /// In en, this message translates to:
  /// **'Purged {count} old log entries'**
  String logsPurged(int count);

  /// No description provided for @cronDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete all executions for this cron?'**
  String get cronDeleteGroup;

  /// No description provided for @cronDeleteExecution.
  ///
  /// In en, this message translates to:
  /// **'Delete this execution?'**
  String get cronDeleteExecution;

  /// No description provided for @cronDeleteGroupCount.
  ///
  /// In en, this message translates to:
  /// **'This will delete {count} sessions.'**
  String cronDeleteGroupCount(int count);

  /// No description provided for @chatListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get chatListening;

  /// No description provided for @chatSpeechError.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition error: {error}'**
  String chatSpeechError(String error);

  /// No description provided for @chatSpeechUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition unavailable on this device'**
  String get chatSpeechUnavailable;

  /// No description provided for @agentSummarizeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Write the summary in English.'**
  String get agentSummarizeInstructions;

  /// No description provided for @settingsExportConversations.
  ///
  /// In en, this message translates to:
  /// **'Export Conversations'**
  String get settingsExportConversations;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share all conversations as JSON'**
  String get settingsExportSubtitle;

  /// No description provided for @exportProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exportProgress;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'{count} conversations exported'**
  String exportSuccess(int count);

  /// No description provided for @exportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations to export'**
  String get exportEmpty;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);
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
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
