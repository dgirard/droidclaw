// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'DroidClaw';

  @override
  String get chatTitle => 'DroidClaw';

  @override
  String get chatConversations => 'Conversations';

  @override
  String get chatNewSession => 'Nouvelle session';

  @override
  String get chatSettings => 'Paramètres';

  @override
  String get chatEmptyTitle => 'DroidClaw';

  @override
  String get chatEmptySubtitle =>
      'Votre assistant IA personnel.\nÉcrivez un message pour commencer.';

  @override
  String get chatInputHint => 'Message à DroidClaw...';

  @override
  String get chatVoiceInput => 'Saisie vocale';

  @override
  String get chatSend => 'Envoyer';

  @override
  String get chatCopied => 'Copié dans le presse-papiers';

  @override
  String chatCalling(String name) {
    return 'Appel de $name...';
  }

  @override
  String get statusThinking => 'Réflexion...';

  @override
  String statusThinkingStep(int step) {
    return 'Réflexion (étape $step)...';
  }

  @override
  String get statusSummarizing => 'Résumé de la conversation...';

  @override
  String statusUsingTool(String name) {
    return 'Utilisation de $name...';
  }

  @override
  String statusGotResult(String name) {
    return 'Résultat de $name';
  }

  @override
  String get statusProcessing => 'Traitement...';

  @override
  String get historyTitle => 'Conversations';

  @override
  String get historySectionChat => 'Chat';

  @override
  String get historySectionCron => 'Tâches planifiées';

  @override
  String get historySectionTelegram => 'Telegram';

  @override
  String get historyEmpty => 'Aucune conversation';

  @override
  String historyExecutions(int count, String date) {
    return '$count exécutions - Dernière : $date';
  }

  @override
  String historyMessages(int count) {
    return '$count messages';
  }

  @override
  String get historyNewConversation => 'Nouvelle conversation';

  @override
  String get historyScheduledPrompt => 'Tâche planifiée';

  @override
  String get historyNoExecutions => 'Aucune exécution';

  @override
  String get historyDeleteTitle => 'Supprimer la conversation ?';

  @override
  String historyDeleteContent(String title) {
    return 'Supprimer « $title » ? Cette action est irréversible.';
  }

  @override
  String get historyToday => 'Aujourd\'hui';

  @override
  String get historyYesterday => 'Hier';

  @override
  String historyError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get onboardWelcome => 'Bienvenue sur DroidClaw';

  @override
  String get onboardSubtitle =>
      'Votre assistant IA personnel sur Android.\nConfigurons votre fournisseur LLM pour commencer.';

  @override
  String get onboardGetStarted => 'Commencer';

  @override
  String get onboardChooseProvider => 'Choisissez un fournisseur';

  @override
  String get onboardChooseProviderSubtitle =>
      'Sélectionnez le fournisseur LLM à utiliser.';

  @override
  String get onboardNext => 'Suivant';

  @override
  String get onboardEnterApiKey => 'Entrez votre clé API';

  @override
  String get onboardApiKeySecure =>
      'Votre clé est stockée de façon sécurisée sur l\'appareil.';

  @override
  String get onboardApiKeyLabel => 'Clé API';

  @override
  String get onboardTestConnection => 'Tester la connexion';

  @override
  String get onboardFinishSetup => 'Terminer la configuration';

  @override
  String onboardTestSuccess(String response) {
    return 'Connecté ! Réponse : $response';
  }

  @override
  String get onboardEnterApiKeyError => 'Veuillez entrer une clé API';

  @override
  String get providerOpenRouter => 'OpenRouter';

  @override
  String get providerOpenRouterDesc =>
      'Accès à plusieurs modèles avec une seule clé API';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerAnthropicDesc => 'Accès direct aux modèles Claude';

  @override
  String get providerOpenAI => 'OpenAI';

  @override
  String get providerOpenAIDesc => 'Accès aux modèles GPT';

  @override
  String get providerGroq => 'Groq';

  @override
  String get providerGroqDesc => 'Inférence rapide pour les modèles ouverts';

  @override
  String get providerGemini => 'Google Gemini';

  @override
  String get providerGeminiDesc => 'Modèles Google AI avec offre gratuite';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionProvider => 'Fournisseur LLM';

  @override
  String get settingsProvider => 'Fournisseur';

  @override
  String get settingsModel => 'Modèle';

  @override
  String get settingsSectionAgent => 'Agent';

  @override
  String get settingsMaxTokens => 'Tokens max';

  @override
  String get settingsTemperature => 'Température';

  @override
  String get settingsMaxToolIterations => 'Itérations d\'outils max';

  @override
  String get settingsSectionTools => 'Outils';

  @override
  String get settingsManageTools => 'Gérer les outils';

  @override
  String get settingsManageToolsSubtitle =>
      'Activer ou désactiver les outils de l\'agent';

  @override
  String get settingsWebSearch => 'Recherche web';

  @override
  String get settingsWebSearchSubtitle => 'Configurer l\'API Brave Search';

  @override
  String get settingsRouting => 'Itinéraires';

  @override
  String get settingsRoutingSubtitle =>
      'Configurer les API de routage et transport';

  @override
  String get settingsScheduledPrompts => 'Tâches planifiées';

  @override
  String get settingsScheduledPromptsSubtitle =>
      'Tâches récurrentes automatisées';

  @override
  String get settingsSectionChannels => 'Canaux';

  @override
  String get settingsTelegramBot => 'Bot Telegram';

  @override
  String get settingsTelegramRunning => 'Actif';

  @override
  String get settingsTelegramDisabled => 'Désactivé';

  @override
  String get settingsSkills => 'Compétences';

  @override
  String get settingsSkillsSubtitle => 'Gérer les compétences installées';

  @override
  String get settingsSectionAbout => 'À propos';

  @override
  String get providerConfigTitle => 'Configuration du fournisseur';

  @override
  String get providerConfigProviderLabel => 'Fournisseur';

  @override
  String get providerConfigApiKeyLabel => 'Clé API';

  @override
  String get providerConfigModelLabel => 'Modèle (optionnel)';

  @override
  String get providerConfigModelHint => 'ex. claude-sonnet-4-20250514';

  @override
  String get providerConfigApiBaseLabel => 'URL de base API (optionnel)';

  @override
  String get providerConfigApiBaseHint =>
      'Laisser vide pour la valeur par défaut';

  @override
  String get providerConfigTestConnection => 'Tester la connexion';

  @override
  String get providerConfigSave => 'Enregistrer';

  @override
  String get providerConfigSaved => 'Paramètres enregistrés';

  @override
  String providerConfigTestSuccess(String response) {
    return 'Connexion réussie ! Réponse : $response';
  }

  @override
  String providerConfigTestFailed(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String get telegramTitle => 'Bot Telegram';

  @override
  String get telegramBotToken => 'Token du bot';

  @override
  String get telegramBotTokenHelper =>
      'Obtenez-en un auprès de @BotFather sur Telegram';

  @override
  String get telegramTestConnection => 'Tester la connexion';

  @override
  String telegramTestSuccess(String username) {
    return 'Connecté ! Bot : @$username';
  }

  @override
  String get telegramEnableBot => 'Activer le bot';

  @override
  String get telegramBotRunning => 'Le bot est actif';

  @override
  String get telegramBotStarting => 'Démarrage...';

  @override
  String get telegramBotDisabled => 'Le bot est désactivé';

  @override
  String get telegramBotActive => 'Bot actif';

  @override
  String telegramMessages(int count) {
    return '$count messages';
  }

  @override
  String telegramLastMessage(String time) {
    return 'Dernier : $time';
  }

  @override
  String get telegramAllowedUsers => 'Utilisateurs autorisés (optionnel)';

  @override
  String get telegramAllowedUsersHelper =>
      'Noms d\'utilisateurs Telegram séparés par des virgules. Laisser vide pour tous.';

  @override
  String get telegramAllowedUsersHint => 'alice, bob, charlie';

  @override
  String get telegramSaveUsers => 'Enregistrer les utilisateurs';

  @override
  String get telegramUsersUpdated => 'Utilisateurs autorisés mis à jour';

  @override
  String get telegramEnterToken => 'Veuillez d\'abord entrer un token de bot';

  @override
  String get telegramEnterTokenError => 'Veuillez entrer un token de bot';

  @override
  String get telegramHowToSetup => 'Comment configurer';

  @override
  String get telegramSetupSteps =>
      '1. Ouvrez Telegram et cherchez @BotFather\n2. Envoyez /newbot et suivez les instructions\n3. Copiez le token du bot et collez-le ci-dessus\n4. Testez la connexion, puis activez le bot\n5. Envoyez un message à votre bot sur Telegram !';

  @override
  String get webSearchTitle => 'Recherche web';

  @override
  String get webSearchDescription =>
      'La recherche fonctionne sans clé via DuckDuckGo, mais Brave Search donne des résultats plus rapides et de meilleure qualité.';

  @override
  String get webSearchApiKeyLabel => 'Clé API Brave Search';

  @override
  String get webSearchTestSearch => 'Tester la recherche';

  @override
  String get webSearchSave => 'Enregistrer';

  @override
  String get webSearchSaved => 'Clé API Brave enregistrée';

  @override
  String get webSearchTestSuccess => 'Recherche réussie ! Résultats reçus.';

  @override
  String get routingTitle => 'Itinéraires & Transports';

  @override
  String get routingSave => 'Enregistrer';

  @override
  String get routingSaved => 'Clés API enregistrées';

  @override
  String get routingOrsTitle => 'OpenRouteService';

  @override
  String get routingOrsDesc =>
      'Clé API gratuite sur openrouteservice.org pour les itinéraires voiture, vélo et piéton.';

  @override
  String get routingOrsKeyLabel => 'Clé API ORS';

  @override
  String get routingOrsTestRoute => 'Tester l\'itinéraire (Paris → Versailles)';

  @override
  String get routingOrsTestGeocode =>
      'Tester le géocodage (Tour Eiffel, Paris)';

  @override
  String get routingSncfTitle => 'SNCF (Trains nationaux)';

  @override
  String get routingSncfDesc =>
      'Clé API gratuite sur ressources.data.sncf.com pour les TGV, TER et Intercités à travers la France.';

  @override
  String get routingSncfKeyLabel => 'Clé API SNCF';

  @override
  String get routingSncfTestTransit => 'Tester le transport (Paris → Lyon)';

  @override
  String get routingPrimTitle => 'PRIM / IDFM (Île-de-France)';

  @override
  String get routingPrimDesc =>
      'Clé API gratuite sur prim.iledefrance-mobilites.fr pour le Métro, RER, Bus et Tram en région parisienne.';

  @override
  String get routingPrimKeyLabel => 'Clé API PRIM';

  @override
  String get routingPrimTestTransit =>
      'Tester le transport (Gare de Lyon → Châtelet)';

  @override
  String get cronTitle => 'Tâches planifiées';

  @override
  String get cronEmpty => 'Aucune tâche planifiée';

  @override
  String get cronEmptySubtitle =>
      'Appuyez sur + pour créer une tâche récurrente.\nL\'IA l\'exécutera automatiquement selon le planning.';

  @override
  String get cronServiceRunning => 'Service d\'arrière-plan actif';

  @override
  String get cronServiceNotRunning => 'Service d\'arrière-plan inactif';

  @override
  String get cronNoPromptsEnabled => 'Aucune tâche activée';

  @override
  String get cronNeverRan => 'Jamais exécutée';

  @override
  String get cronDeleteTitle => 'Supprimer la tâche planifiée ?';

  @override
  String cronDeleteContent(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get cronViewExecutions => 'Voir les exécutions';

  @override
  String get cronEditTitle => 'Nouvelle tâche';

  @override
  String get cronEditTitleEdit => 'Modifier la tâche';

  @override
  String get cronEditSave => 'Enregistrer';

  @override
  String get cronEditName => 'Nom';

  @override
  String get cronEditNameHint => 'ex. Résumé quotidien des actualités';

  @override
  String get cronEditPrompt => 'Prompt';

  @override
  String get cronEditPromptHint => 'Que doit faire l\'IA ?';

  @override
  String get cronEditSchedule => 'Planning';

  @override
  String get cronEditInterval => 'Intervalle';

  @override
  String get cronEditSpecificTimes => 'Heures précises';

  @override
  String get cronEditAddTime => 'Ajouter une heure';

  @override
  String get cronEditDays => 'Jours';

  @override
  String get cronEditConversation => 'Conversation';

  @override
  String get cronEditNewEach => 'Nouvelle conversation à chaque fois';

  @override
  String get cronEditNewEachSubtitle => 'Chaque exécution est indépendante';

  @override
  String get cronEditSameThread => 'Continuer dans le même fil';

  @override
  String get cronEditSameThreadSubtitle =>
      'L\'IA se souvient des exécutions précédentes';

  @override
  String get cronEditNameRequired => 'Le nom et le prompt sont requis';

  @override
  String get cronEditTimeRequired => 'Ajoutez au moins une heure';

  @override
  String get cronEditInterval15 => '15 min';

  @override
  String get cronEditInterval30 => '30 min';

  @override
  String get cronEditInterval1h => '1 heure';

  @override
  String get cronEditInterval2h => '2 heures';

  @override
  String get cronEditInterval6h => '6 heures';

  @override
  String get cronEditInterval12h => '12 heures';

  @override
  String get cronEditInterval24h => '24 heures';

  @override
  String get cronEditMon => 'Lun';

  @override
  String get cronEditTue => 'Mar';

  @override
  String get cronEditWed => 'Mer';

  @override
  String get cronEditThu => 'Jeu';

  @override
  String get cronEditFri => 'Ven';

  @override
  String get cronEditSat => 'Sam';

  @override
  String get cronEditSun => 'Dim';

  @override
  String cronDisplayEveryMinutes(int minutes) {
    return 'Toutes les $minutes min';
  }

  @override
  String get cronDisplayEveryHour => 'Toutes les heures';

  @override
  String cronDisplayEveryHours(int hours) {
    return 'Toutes les $hours heures';
  }

  @override
  String cronDisplayDailyAt(String times) {
    return 'Chaque jour à $times';
  }

  @override
  String cronDisplayAt(String times) {
    return 'À $times';
  }

  @override
  String get skillsTitle => 'Compétences';

  @override
  String get skillsGithubUrl => 'URL GitHub';

  @override
  String get skillsGithubUrlHint =>
      'https://github.com/user/repo/blob/main/SKILL.md';

  @override
  String get skillsInstall => 'Installer';

  @override
  String get skillsNoSkills => 'Aucune compétence installée';

  @override
  String skillsInstalled(String name) {
    return 'Compétence installée : $name';
  }

  @override
  String skillsInstallFailed(String error) {
    return 'Échec de l\'installation : $error';
  }

  @override
  String get skillsUninstallTitle => 'Désinstaller la compétence';

  @override
  String skillsUninstallContent(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get skillsUninstall => 'Désinstaller';

  @override
  String skillsUninstalled(String name) {
    return 'Désinstallée : $name';
  }

  @override
  String skillsUninstallFailed(String error) {
    return 'Échec de la désinstallation : $error';
  }

  @override
  String get toolsTitle => 'Gérer les outils';

  @override
  String get toolWebSearch => 'Recherche web';

  @override
  String get toolWebSearchDesc => 'Recherche sur le web via l\'API Brave';

  @override
  String get toolWebScrape => 'Scraping web';

  @override
  String get toolWebScrapeDesc =>
      'Extraction légère de pages (HTTP + Markdown)';

  @override
  String get toolWebScrapeJs => 'Scraping web (JS)';

  @override
  String get toolWebScrapeJsDesc =>
      'Extraction lourde de pages avec rendu JS (WebView)';

  @override
  String get toolFile => 'Accès fichiers';

  @override
  String get toolFileDesc =>
      'Lire et écrire des fichiers dans l\'espace de travail';

  @override
  String get toolLocation => 'Localisation GPS';

  @override
  String get toolLocationDesc => 'Accéder aux coordonnées GPS de l\'appareil';

  @override
  String get toolAddress => 'Géocodage inversé';

  @override
  String get toolAddressDesc => 'Convertir des coordonnées GPS en adresse';

  @override
  String get toolSubagent => 'Sous-agent';

  @override
  String get toolSubagentDesc =>
      'Déléguer des sous-tâches pour les requêtes complexes';

  @override
  String get toolClipboard => 'Presse-papiers';

  @override
  String get toolClipboardDesc => 'Lire et écrire dans le presse-papiers';

  @override
  String get toolDatetime => 'Date et heure';

  @override
  String get toolDatetimeDesc =>
      'Date, heure, jour de la semaine, fuseau horaire';

  @override
  String get toolDeviceInfo => 'Info appareil';

  @override
  String get toolDeviceInfoDesc =>
      'Batterie, connectivité, modèle de l\'appareil';

  @override
  String get toolSpeak => 'Synthèse vocale';

  @override
  String get toolSpeakDesc =>
      'Lire du texte à voix haute (premier plan uniquement)';

  @override
  String get toolOpenApp => 'Ouvrir appli / URL';

  @override
  String get toolOpenAppDesc => 'Ouvrir des URL, téléphone, cartes, e-mail';

  @override
  String get toolAlarm => 'Alarme / Minuteur';

  @override
  String get toolAlarmDesc =>
      'Définir des alarmes et minuteurs via l\'appli Horloge';

  @override
  String get toolNotifications => 'Notifications';

  @override
  String get toolNotificationsDesc =>
      'Créer et planifier des notifications locales / rappels';

  @override
  String get toolContacts => 'Contacts';

  @override
  String get toolContactsDesc =>
      'Rechercher et lire les contacts de l\'appareil (lecture seule)';

  @override
  String get toolCalendar => 'Calendrier';

  @override
  String get toolCalendarDesc => 'Lire et créer des événements de calendrier';

  @override
  String get toolOcr => 'OCR';

  @override
  String get toolOcrDesc =>
      'Extraire du texte des images (ML Kit sur l\'appareil)';

  @override
  String get toolQrGenerate => 'Code QR';

  @override
  String get toolQrGenerateDesc =>
      'Générer des images de code QR à partir de texte ou d\'URL';

  @override
  String get toolPickImage => 'Sélection d\'image';

  @override
  String get toolPickImageDesc =>
      'Choisir des photos de la galerie ou prendre avec l\'appareil photo';

  @override
  String get toolVolumeControl => 'Contrôle du volume';

  @override
  String get toolVolumeControlDesc =>
      'Lire et ajuster les niveaux de volume (alarme, média, etc.)';

  @override
  String get toolGeocode => 'Géocodage';

  @override
  String get toolGeocodeDesc =>
      'Convertir une adresse en coordonnées GPS (OpenRouteService)';

  @override
  String get toolDirections => 'Itinéraires';

  @override
  String get toolDirectionsDesc =>
      'Calcul d\'itinéraire (voiture, vélo, piéton) via OpenRouteService';

  @override
  String get toolTransit => 'Transports en commun';

  @override
  String get toolTransitDesc => 'Métro, RER, bus, train (SNCF + IDFM)';

  @override
  String get toolWeather => 'Météo';

  @override
  String get toolWeatherDesc =>
      'Prévisions météo via Open-Meteo (modèles Météo-France)';

  @override
  String get toolRadio => 'Radio France';

  @override
  String get toolRadioDesc =>
      'Écouter les radios France en direct (France Inter, FIP, etc.)';

  @override
  String get weatherClearSky => 'Ciel dégagé';

  @override
  String get weatherMainlyClear => 'Peu nuageux';

  @override
  String get weatherPartlyCloudy => 'Partiellement nuageux';

  @override
  String get weatherOvercast => 'Couvert';

  @override
  String get weatherFog => 'Brouillard';

  @override
  String get weatherLightDrizzle => 'Bruine légère';

  @override
  String get weatherModerateDrizzle => 'Bruine modérée';

  @override
  String get weatherDenseDrizzle => 'Bruine dense';

  @override
  String get weatherFreezingDrizzle => 'Bruine verglaçante';

  @override
  String get weatherLightRain => 'Pluie légère';

  @override
  String get weatherModerateRain => 'Pluie modérée';

  @override
  String get weatherHeavyRain => 'Pluie forte';

  @override
  String get weatherFreezingRain => 'Pluie verglaçante';

  @override
  String get weatherLightSnow => 'Neige légère';

  @override
  String get weatherModerateSnow => 'Neige modérée';

  @override
  String get weatherHeavySnow => 'Neige forte';

  @override
  String get weatherSleet => 'Grésil';

  @override
  String get weatherLightShowers => 'Averses légères';

  @override
  String get weatherModerateShowers => 'Averses modérées';

  @override
  String get weatherViolentShowers => 'Averses violentes';

  @override
  String get weatherLightSnowShowers => 'Averses de neige légères';

  @override
  String get weatherHeavySnowShowers => 'Averses de neige fortes';

  @override
  String get weatherThunderstorm => 'Orage';

  @override
  String get weatherThunderstormLightHail => 'Orage avec grêle légère';

  @override
  String get weatherThunderstormHeavyHail => 'Orage avec grêle forte';

  @override
  String weatherUnknown(int code) {
    return 'Inconnu (code $code)';
  }

  @override
  String weatherToday(String date) {
    return 'Aujourd\'hui ($date)';
  }

  @override
  String get weatherTodayShort => 'Auj';

  @override
  String get weatherMorning => 'Matin (9h)';

  @override
  String get weatherAfternoon => 'Après-midi (15h)';

  @override
  String get weatherEvening => 'Soir (21h)';

  @override
  String weatherWind(int speed) {
    return 'vent $speed km/h';
  }

  @override
  String get transitTransfer => 'correspondance';

  @override
  String get transitWaiting => 'attente';

  @override
  String get transitDuration => 'Durée :';

  @override
  String get transitDeparture => 'Départ :';

  @override
  String get transitArrival => 'Arrivée :';

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
    return '$count correspondance$_temp0';
  }

  @override
  String transitOption(int index, String api) {
    return 'Option $index (via $api)';
  }

  @override
  String get transitSections => 'Sections :';

  @override
  String get transitNoRoutes =>
      'Aucun itinéraire en transport en commun trouvé entre ces lieux.';

  @override
  String get transitNoApiKey =>
      'Aucune clé API de transport configurée. Configurez la clé SNCF ou PRIM dans Paramètres > Itinéraires.';

  @override
  String transitInvalidKey(String api) {
    return 'La clé API $api est invalide. Vérifiez-la dans Paramètres > Itinéraires.';
  }

  @override
  String get transitRateLimit =>
      'Limite de requêtes de l\'API atteinte. Réessayez plus tard.';

  @override
  String get transitSncfRequired =>
      'Clé API SNCF nécessaire pour les trajets hors Île-de-France. Configurez-la dans Paramètres > Itinéraires.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String commonFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get commonEnterApiKey => 'Veuillez entrer une clé API';

  @override
  String get noProviderConfigured =>
      'Aucun fournisseur LLM configuré. Veuillez en configurer un dans les Paramètres.';

  @override
  String get telegramBotPrivate => 'Ce bot est privé.';

  @override
  String get localeSettingsTitle => 'Langue';

  @override
  String get localeSystem => 'Langue du système';

  @override
  String get localeEnglish => 'Anglais';

  @override
  String get localeFrench => 'Français';

  @override
  String get localeSpanish => 'Espagnol';

  @override
  String get localeGerman => 'Allemand';

  @override
  String get localeItalian => 'Italien';

  @override
  String get agentRespondInstructions =>
      'Réponds toujours en français, quelle que soit la langue utilisée dans les messages précédents.';

  @override
  String get batteryCharging => 'en charge';

  @override
  String get batteryDischarging => 'décharge';

  @override
  String get batteryFull => 'pleine';

  @override
  String get batteryConnectedNotCharging => 'connecté (pas en charge)';

  @override
  String get batteryUnknown => 'inconnu';

  @override
  String agentLlmError(String error) {
    return 'Échec de l\'appel LLM : $error';
  }

  @override
  String get agentMaxIterations =>
      'Nombre maximum d\'itérations d\'outils atteint.';

  @override
  String agentError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get telegramErrorGeneric =>
      'Désolé, j\'ai rencontré une erreur. Veuillez réessayer.';

  @override
  String get telegramErrorProcessing =>
      'Une erreur s\'est produite lors du traitement de votre message.';

  @override
  String get notifChannelName => 'Service d\'arrière-plan DroidClaw';

  @override
  String get notifChannelDesc =>
      'Service d\'arrière-plan pour le bot Telegram et les tâches planifiées';

  @override
  String get notifServiceActive => 'DroidClaw - Actif';

  @override
  String get notifServiceRunning => 'Service d\'arrière-plan actif';

  @override
  String get notifBotActive => 'Bot DroidClaw - Actif';

  @override
  String notifBotMessages(int count) {
    return 'Messages traités : $count';
  }

  @override
  String get notifBotError => 'Bot DroidClaw - Erreur';

  @override
  String get notifBotInvalidToken => 'Token du bot invalide';

  @override
  String get notifBotDisconnected => 'Bot DroidClaw - Déconnecté';

  @override
  String get notifBotRetrying => 'Nouvelle tentative...';

  @override
  String notifLastCron(String name) {
    return 'Dernière tâche : $name';
  }

  @override
  String cronLastRun(String date) {
    return 'Dernière : $date';
  }

  @override
  String get logsTitle => 'Journaux';

  @override
  String get logsEmpty => 'Aucune entrée de journal';

  @override
  String get logsFilterAll => 'Tous';

  @override
  String get logsFilterInfo => 'Info';

  @override
  String get logsFilterWarning => 'Avertissement';

  @override
  String get logsFilterError => 'Erreur';

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
  String get logsClearAll => 'Effacer tous les journaux';

  @override
  String get logsClearConfirm => 'Supprimer toutes les entrées de journal ?';

  @override
  String logsEntryCount(int count) {
    return '$count entrées';
  }

  @override
  String get logsCleared => 'Journaux effacés';

  @override
  String logsPurged(int count) {
    return '$count anciennes entrées purgées';
  }

  @override
  String get cronDeleteGroup => 'Supprimer toutes les exécutions de ce cron ?';

  @override
  String get cronDeleteExecution => 'Supprimer cette exécution ?';

  @override
  String cronDeleteGroupCount(int count) {
    return 'Cela supprimera $count sessions.';
  }

  @override
  String get chatListening => 'Écoute...';

  @override
  String chatSpeechError(String error) {
    return 'Erreur de reconnaissance vocale : $error';
  }

  @override
  String get chatSpeechUnavailable =>
      'Reconnaissance vocale non disponible sur cet appareil';

  @override
  String get agentSummarizeInstructions => 'Rédige le résumé en français.';
}
