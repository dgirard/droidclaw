// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'DroidClaw';

  @override
  String get chatTitle => 'DroidClaw';

  @override
  String get chatConversations => 'Conversaciones';

  @override
  String get chatNewSession => 'Nueva sesión';

  @override
  String get chatSettings => 'Ajustes';

  @override
  String get chatEmptyTitle => 'DroidClaw';

  @override
  String get chatEmptySubtitle =>
      'Tu asistente personal de IA.\nEscribe un mensaje para empezar.';

  @override
  String get chatInputHint => 'Mensaje a DroidClaw...';

  @override
  String get chatVoiceInput => 'Entrada de voz';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatCopied => 'Copiado al portapapeles';

  @override
  String chatCalling(String name) {
    return 'Llamando a $name...';
  }

  @override
  String get statusThinking => 'Pensando...';

  @override
  String statusThinkingStep(int step) {
    return 'Pensando (paso $step)...';
  }

  @override
  String get statusSummarizing => 'Resumiendo conversación...';

  @override
  String statusUsingTool(String name) {
    return 'Usando $name...';
  }

  @override
  String statusGotResult(String name) {
    return 'Resultado obtenido de $name';
  }

  @override
  String get statusProcessing => 'Procesando...';

  @override
  String get historyTitle => 'Conversaciones';

  @override
  String get historySectionChat => 'Chat';

  @override
  String get historySectionTelegram => 'Telegram';

  @override
  String get historyTabConversations => 'Conversaciones';

  @override
  String get historyTabScheduled => 'Tareas programadas';

  @override
  String get historyEmpty => 'Aún no hay conversaciones';

  @override
  String get historyEmptyScheduled => 'Sin tareas programadas';

  @override
  String historyExecutions(int count, String date) {
    return '$count ejecuciones - Última: $date';
  }

  @override
  String historyMessages(int count) {
    return '$count mensajes';
  }

  @override
  String get historyNewConversation => 'Nueva conversación';

  @override
  String get historyScheduledPrompt => 'Tarea programada';

  @override
  String get historyNoExecutions => 'Aún no hay ejecuciones';

  @override
  String get historyDeleteTitle => '¿Eliminar conversación?';

  @override
  String historyDeleteContent(String title) {
    return '¿Eliminar \"$title\"? Esta acción no se puede deshacer.';
  }

  @override
  String get historyToday => 'Hoy';

  @override
  String get historyYesterday => 'Ayer';

  @override
  String historyError(String error) {
    return 'Error: $error';
  }

  @override
  String get onboardWelcome => 'Bienvenido a DroidClaw';

  @override
  String get onboardSubtitle =>
      'Tu asistente personal de IA en Android.\nConfiguremos tu proveedor de LLM para empezar.';

  @override
  String get onboardGetStarted => 'Comenzar';

  @override
  String get onboardChooseProvider => 'Elige un proveedor';

  @override
  String get onboardChooseProviderSubtitle =>
      'Selecciona qué proveedor de LLM quieres usar.';

  @override
  String get onboardNext => 'Siguiente';

  @override
  String get onboardEnterApiKey => 'Introduce tu clave API';

  @override
  String get onboardApiKeySecure =>
      'Tu clave se almacena de forma segura en el dispositivo.';

  @override
  String get onboardApiKeyLabel => 'Clave API';

  @override
  String get onboardTestConnection => 'Probar Conexión';

  @override
  String get onboardFinishSetup => 'Finalizar Configuración';

  @override
  String onboardTestSuccess(String response) {
    return '¡Conectado! Respuesta: $response';
  }

  @override
  String get onboardEnterApiKeyError => 'Por favor introduce una clave API';

  @override
  String get providerOpenRouter => 'OpenRouter';

  @override
  String get providerOpenRouterDesc =>
      'Accede a muchos modelos con una sola clave API';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerAnthropicDesc => 'Acceso directo a los modelos Claude';

  @override
  String get providerOpenAI => 'OpenAI';

  @override
  String get providerOpenAIDesc => 'Acceso a los modelos GPT';

  @override
  String get providerGroq => 'Groq';

  @override
  String get providerGroqDesc => 'Inferencia rápida para modelos abiertos';

  @override
  String get providerGemini => 'Google Gemini';

  @override
  String get providerGeminiDesc => 'Modelos de IA de Google con nivel gratuito';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSectionProvider => 'Proveedor de LLM';

  @override
  String get settingsProvider => 'Proveedor';

  @override
  String get settingsModel => 'Modelo';

  @override
  String get settingsSectionAgent => 'Agente';

  @override
  String get settingsMaxTokens => 'Tokens máximos';

  @override
  String get settingsTemperature => 'Temperatura';

  @override
  String get settingsMaxToolIterations => 'Iteraciones máximas de herramientas';

  @override
  String get settingsSectionTools => 'Herramientas';

  @override
  String get settingsManageTools => 'Gestionar Herramientas';

  @override
  String get settingsManageToolsSubtitle =>
      'Activar o desactivar herramientas del agente';

  @override
  String get settingsWebSearch => 'Búsqueda Web';

  @override
  String get settingsWebSearchSubtitle => 'Configurar API de Brave Search';

  @override
  String get settingsRouting => 'Rutas';

  @override
  String get settingsRoutingSubtitle => 'Configurar APIs de rutas y transporte';

  @override
  String get settingsScheduledPrompts => 'Tareas Programadas';

  @override
  String get settingsScheduledPromptsSubtitle =>
      'Tareas recurrentes automatizadas';

  @override
  String get settingsSectionChannels => 'Canales';

  @override
  String get settingsTelegramBot => 'Bot de Telegram';

  @override
  String get settingsTelegramRunning => 'Activo';

  @override
  String get settingsTelegramDisabled => 'Desactivado';

  @override
  String get settingsSkills => 'Habilidades';

  @override
  String get settingsSkillsSubtitle => 'Gestionar habilidades instaladas';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get providerConfigTitle => 'Configuración del Proveedor';

  @override
  String get providerConfigProviderLabel => 'Proveedor';

  @override
  String get providerConfigApiKeyLabel => 'Clave API';

  @override
  String get providerConfigModelLabel => 'Modelo (opcional)';

  @override
  String get providerConfigModelHint => 'ej. claude-sonnet-4-20250514';

  @override
  String get providerConfigApiBaseLabel => 'URL Base de la API (opcional)';

  @override
  String get providerConfigApiBaseHint =>
      'Dejar vacío para usar la predeterminada';

  @override
  String get providerConfigTestConnection => 'Probar Conexión';

  @override
  String get providerConfigSave => 'Guardar';

  @override
  String get providerConfigSaved => 'Configuración guardada';

  @override
  String providerConfigTestSuccess(String response) {
    return '¡Conexión exitosa! Respuesta: $response';
  }

  @override
  String providerConfigTestFailed(String error) {
    return 'Conexión fallida: $error';
  }

  @override
  String get telegramTitle => 'Bot de Telegram';

  @override
  String get telegramBotToken => 'Token del Bot';

  @override
  String get telegramBotTokenHelper => 'Obtén uno desde @BotFather en Telegram';

  @override
  String get telegramTestConnection => 'Probar Conexión';

  @override
  String telegramTestSuccess(String username) {
    return '¡Conectado! Bot: @$username';
  }

  @override
  String get telegramEnableBot => 'Activar Bot';

  @override
  String get telegramBotRunning => 'Bot activo';

  @override
  String get telegramBotStarting => 'Iniciando...';

  @override
  String get telegramBotDisabled => 'Bot desactivado';

  @override
  String get telegramBotActive => 'Bot Activo';

  @override
  String telegramMessages(int count) {
    return '$count mensajes';
  }

  @override
  String telegramLastMessage(String time) {
    return 'Último: $time';
  }

  @override
  String get telegramAllowedUsers => 'IDs de usuario permitidos (obligatorio)';

  @override
  String get telegramAllowedUsersHelper =>
      'IDs numéricos de usuario de Telegram separados por comas (p. ej. de @userinfobot). El bot no responde a nadie hasta que se añada al menos un ID.';

  @override
  String get telegramAllowedUsersHint => '123456789, 987654321';

  @override
  String get telegramSaveUsers => 'Guardar Usuarios';

  @override
  String get telegramUsersUpdated => 'Usuarios permitidos actualizados';

  @override
  String get telegramEnterToken =>
      'Por favor introduce primero un token del bot';

  @override
  String get telegramEnterTokenError => 'Por favor introduce un token del bot';

  @override
  String get telegramHowToSetup => 'Cómo configurar';

  @override
  String get telegramSetupSteps =>
      '1. Abre Telegram y busca @BotFather\n2. Envía /newbot y sigue las instrucciones\n3. Copia el token del bot y pégalo arriba\n4. Prueba la conexión, luego activa el bot\n5. ¡Envía un mensaje a tu bot en Telegram!';

  @override
  String get webSearchTitle => 'Búsqueda Web';

  @override
  String get webSearchDescription =>
      'La búsqueda web funciona sin clave usando DuckDuckGo, pero Brave Search ofrece resultados más rápidos y de mayor calidad.';

  @override
  String get webSearchApiKeyLabel => 'Clave API de Brave Search';

  @override
  String get webSearchTestSearch => 'Probar Búsqueda';

  @override
  String get webSearchSave => 'Guardar';

  @override
  String get webSearchSaved => 'Clave API de Brave guardada';

  @override
  String get webSearchTestSuccess => '¡Búsqueda exitosa! Resultados recibidos.';

  @override
  String get routingTitle => 'Rutas y Transporte';

  @override
  String get routingSave => 'Guardar';

  @override
  String get routingSaved => 'Claves API guardadas';

  @override
  String get routingOrsTitle => 'OpenRouteService';

  @override
  String get routingOrsDesc =>
      'Clave API gratuita en openrouteservice.org para rutas en coche, bicicleta y a pie.';

  @override
  String get routingOrsKeyLabel => 'Clave API de ORS';

  @override
  String get routingOrsTestRoute => 'Probar Ruta (París → Versalles)';

  @override
  String get routingOrsTestGeocode =>
      'Probar Geocodificación (Torre Eiffel, París)';

  @override
  String get routingSncfTitle => 'SNCF (Trenes Nacionales)';

  @override
  String get routingSncfDesc =>
      'Clave API gratuita en ressources.data.sncf.com para rutas de TGV, TER e Intercités en toda Francia.';

  @override
  String get routingSncfKeyLabel => 'Clave API de SNCF';

  @override
  String get routingSncfTestTransit => 'Probar Transporte (París → Lyon)';

  @override
  String get routingPrimTitle => 'PRIM / IDFM (Île-de-France)';

  @override
  String get routingPrimDesc =>
      'Clave API gratuita en prim.iledefrance-mobilites.fr para Metro, RER, Bus y Tranvía en la región de París.';

  @override
  String get routingPrimKeyLabel => 'Clave API de PRIM';

  @override
  String get routingPrimTestTransit =>
      'Probar Transporte (Gare de Lyon → Châtelet)';

  @override
  String get cronTitle => 'Tareas Programadas';

  @override
  String get cronEmpty => 'No hay tareas programadas';

  @override
  String get cronEmptySubtitle =>
      'Pulsa + para crear una tarea recurrente.\nLa IA la ejecutará automáticamente según el horario.';

  @override
  String get cronServiceRunning => 'Servicio en segundo plano activo';

  @override
  String get cronServiceNotRunning => 'Servicio en segundo plano inactivo';

  @override
  String get cronNoPromptsEnabled => 'No hay tareas activadas';

  @override
  String get cronNeverRan => 'Nunca ejecutada';

  @override
  String get cronDeleteTitle => '¿Eliminar tarea programada?';

  @override
  String cronDeleteContent(String name) {
    return '¿Eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get cronViewExecutions => 'Ver ejecuciones';

  @override
  String get cronRunNow => 'Ejecutar ahora';

  @override
  String get cronEditTitle => 'Nueva Tarea';

  @override
  String get cronEditTitleEdit => 'Editar Tarea';

  @override
  String get cronEditSave => 'Guardar';

  @override
  String get cronEditName => 'Nombre';

  @override
  String get cronEditNameHint => 'ej., Resumen diario de noticias';

  @override
  String get cronEditPrompt => 'Instrucción';

  @override
  String get cronEditPromptHint => '¿Qué debe hacer la IA?';

  @override
  String get cronEditSchedule => 'Horario';

  @override
  String get cronEditInterval => 'Intervalo';

  @override
  String get cronEditSpecificTimes => 'Horas específicas';

  @override
  String get cronEditAddTime => 'Añadir hora';

  @override
  String get cronEditDays => 'Días';

  @override
  String get cronEditConversation => 'Conversación';

  @override
  String get cronEditNewEach => 'Nueva conversación cada vez';

  @override
  String get cronEditNewEachSubtitle => 'Cada ejecución es independiente';

  @override
  String get cronEditSameThread => 'Continuar en el mismo hilo';

  @override
  String get cronEditSameThreadSubtitle =>
      'La IA recuerda ejecuciones anteriores';

  @override
  String get cronEditNameRequired => 'Nombre e instrucción son obligatorios';

  @override
  String get cronEditTimeRequired => 'Añade al menos una hora';

  @override
  String get cronEditInterval15 => '15 min';

  @override
  String get cronEditInterval30 => '30 min';

  @override
  String get cronEditInterval1h => '1 hora';

  @override
  String get cronEditInterval2h => '2 horas';

  @override
  String get cronEditInterval6h => '6 horas';

  @override
  String get cronEditInterval12h => '12 horas';

  @override
  String get cronEditInterval24h => '24 horas';

  @override
  String get cronEditMon => 'Lun';

  @override
  String get cronEditTue => 'Mar';

  @override
  String get cronEditWed => 'Mié';

  @override
  String get cronEditThu => 'Jue';

  @override
  String get cronEditFri => 'Vie';

  @override
  String get cronEditSat => 'Sáb';

  @override
  String get cronEditSun => 'Dom';

  @override
  String cronDisplayEveryMinutes(int minutes) {
    return 'Cada $minutes min';
  }

  @override
  String get cronDisplayEveryHour => 'Cada hora';

  @override
  String cronDisplayEveryHours(int hours) {
    return 'Cada $hours horas';
  }

  @override
  String cronDisplayDailyAt(String times) {
    return 'Diariamente a las $times';
  }

  @override
  String cronDisplayAt(String times) {
    return 'A las $times';
  }

  @override
  String get skillsTitle => 'Habilidades';

  @override
  String get skillsGithubUrl => 'URL de GitHub';

  @override
  String get skillsGithubUrlHint =>
      'https://github.com/usuario/repo/blob/main/SKILL.md';

  @override
  String get skillsInstall => 'Instalar';

  @override
  String get skillsNoSkills => 'No hay habilidades instaladas';

  @override
  String skillsInstalled(String name) {
    return 'Habilidad instalada: $name';
  }

  @override
  String skillsInstallFailed(String error) {
    return 'Instalación fallida: $error';
  }

  @override
  String get skillsUninstallTitle => 'Desinstalar Habilidad';

  @override
  String skillsUninstallContent(String name) {
    return '¿Eliminar \"$name\"?';
  }

  @override
  String get skillsUninstall => 'Desinstalar';

  @override
  String skillsUninstalled(String name) {
    return 'Desinstalada: $name';
  }

  @override
  String skillsUninstallFailed(String error) {
    return 'Desinstalación fallida: $error';
  }

  @override
  String get toolsTitle => 'Gestionar Herramientas';

  @override
  String get toolWebSearch => 'Búsqueda Web';

  @override
  String get toolWebSearchDesc => 'Buscar en la web mediante la API de Brave';

  @override
  String get toolWebScrape => 'Extracción Web';

  @override
  String get toolWebScrapeDesc =>
      'Extracción ligera de páginas (HTTP + Markdown)';

  @override
  String get toolWebScrapeJs => 'Extracción Web (JS)';

  @override
  String get toolWebScrapeJsDesc =>
      'Extracción pesada de páginas renderizadas con JS (WebView)';

  @override
  String get toolFile => 'Acceso a Archivos';

  @override
  String get toolFileDesc =>
      'Leer y escribir archivos en el espacio de trabajo';

  @override
  String get toolLocation => 'Ubicación GPS';

  @override
  String get toolLocationDesc =>
      'Acceder a las coordenadas GPS del dispositivo';

  @override
  String get toolAddress => 'Geocodificación Inversa';

  @override
  String get toolAddressDesc => 'Convertir coordenadas GPS en dirección';

  @override
  String get toolSubagent => 'Sub-agente';

  @override
  String get toolSubagentDesc => 'Generar sub-tareas para consultas complejas';

  @override
  String get toolClipboard => 'Portapapeles';

  @override
  String get toolClipboardDesc =>
      'Leer y escribir en el portapapeles del dispositivo';

  @override
  String get toolDatetime => 'Fecha y Hora';

  @override
  String get toolDatetimeDesc =>
      'Obtener fecha, hora, día de la semana y zona horaria actuales';

  @override
  String get toolDeviceInfo => 'Info del Dispositivo';

  @override
  String get toolDeviceInfoDesc =>
      'Batería, conectividad, modelo del dispositivo';

  @override
  String get toolSpeak => 'Texto a Voz';

  @override
  String get toolSpeakDesc =>
      'Pronunciar texto en voz alta (solo en primer plano)';

  @override
  String get toolOpenApp => 'Abrir App / URL';

  @override
  String get toolOpenAppDesc =>
      'Abrir URLs, teléfono, mapas, email en el dispositivo';

  @override
  String get toolAlarm => 'Alarma / Temporizador';

  @override
  String get toolAlarmDesc =>
      'Configurar alarmas y temporizadores mediante la app Reloj del sistema';

  @override
  String get toolNotifications => 'Notificaciones';

  @override
  String get toolNotificationsDesc =>
      'Crear y programar notificaciones locales / recordatorios';

  @override
  String get toolContacts => 'Contactos';

  @override
  String get toolContactsDesc =>
      'Buscar y leer contactos del dispositivo (solo lectura)';

  @override
  String get toolCalendar => 'Calendario';

  @override
  String get toolCalendarDesc => 'Leer y crear eventos de calendario';

  @override
  String get toolOcr => 'OCR';

  @override
  String get toolOcrDesc =>
      'Extraer texto de imágenes (ML Kit en el dispositivo)';

  @override
  String get toolQrGenerate => 'Código QR';

  @override
  String get toolQrGenerateDesc =>
      'Generar imágenes de códigos QR desde texto o URLs';

  @override
  String get toolPickImage => 'Selector de Imágenes';

  @override
  String get toolPickImageDesc =>
      'Elegir fotos de la galería o tomar con la cámara';

  @override
  String get toolVolumeControl => 'Control de Volumen';

  @override
  String get toolVolumeControlDesc =>
      'Leer y ajustar niveles de volumen del dispositivo (alarma, multimedia, etc.)';

  @override
  String get toolGeocode => 'Geocodificación';

  @override
  String get toolGeocodeDesc =>
      'Convertir dirección en coordenadas GPS (OpenRouteService)';

  @override
  String get toolDirections => 'Indicaciones';

  @override
  String get toolDirectionsDesc =>
      'Cálculo de rutas (coche, bici, a pie) mediante OpenRouteService';

  @override
  String get toolTransit => 'Transporte Público';

  @override
  String get toolTransitDesc =>
      'Rutas de metro, RER, autobús, tren (SNCF + IDFM)';

  @override
  String get toolWeather => 'Tiempo';

  @override
  String get toolWeatherDesc =>
      'Previsión meteorológica mediante Open-Meteo (modelos Météo-France)';

  @override
  String get toolRadio => 'Radio France';

  @override
  String get toolRadioDesc =>
      'Escuchar emisoras de Radio France en directo (France Inter, FIP, etc.)';

  @override
  String get toolProofEditor => 'ProofEditor';

  @override
  String get toolProofEditorDesc =>
      'Edición colaborativa de documentos con ProofEditor.ai';

  @override
  String get proofDocCreated => 'Documento creado';

  @override
  String get proofActionApplied => 'Cambios aplicados';

  @override
  String proofDocRenamed(String title) {
    return 'Título actualizado: $title';
  }

  @override
  String proofDocTruncated(int max, int actual) {
    return '(Truncado a $max de $actual caracteres)';
  }

  @override
  String get toolKnowledgeSearch => 'Búsqueda de conocimiento';

  @override
  String get toolKnowledgeSearchDesc =>
      'Buscar conocimientos recordados de conversaciones anteriores';

  @override
  String get toolKnowledgeStore => 'Almacenamiento de conocimiento';

  @override
  String get toolKnowledgeStoreDesc =>
      'Guardar un dato para recordar entre conversaciones';

  @override
  String get toolKbQuery => 'Consulta de conocimiento';

  @override
  String get toolKbQueryDesc => 'Explorar y consultar la base de conocimiento';

  @override
  String get toolDream => 'Sueño';

  @override
  String get toolDreamDesc =>
      'Analizar y limpiar la KB encontrando y fusionando entidades duplicadas';

  @override
  String get weatherClearSky => 'Cielo despejado';

  @override
  String get weatherMainlyClear => 'Mayormente despejado';

  @override
  String get weatherPartlyCloudy => 'Parcialmente nublado';

  @override
  String get weatherOvercast => 'Nublado';

  @override
  String get weatherFog => 'Niebla';

  @override
  String get weatherLightDrizzle => 'Llovizna ligera';

  @override
  String get weatherModerateDrizzle => 'Llovizna moderada';

  @override
  String get weatherDenseDrizzle => 'Llovizna densa';

  @override
  String get weatherFreezingDrizzle => 'Llovizna helada';

  @override
  String get weatherLightRain => 'Lluvia ligera';

  @override
  String get weatherModerateRain => 'Lluvia moderada';

  @override
  String get weatherHeavyRain => 'Lluvia intensa';

  @override
  String get weatherFreezingRain => 'Lluvia helada';

  @override
  String get weatherLightSnow => 'Nevada ligera';

  @override
  String get weatherModerateSnow => 'Nevada moderada';

  @override
  String get weatherHeavySnow => 'Nevada intensa';

  @override
  String get weatherSleet => 'Aguanieve';

  @override
  String get weatherLightShowers => 'Chubascos ligeros';

  @override
  String get weatherModerateShowers => 'Chubascos moderados';

  @override
  String get weatherViolentShowers => 'Chubascos violentos';

  @override
  String get weatherLightSnowShowers => 'Nevadas ligeras';

  @override
  String get weatherHeavySnowShowers => 'Nevadas intensas';

  @override
  String get weatherThunderstorm => 'Tormenta';

  @override
  String get weatherThunderstormLightHail => 'Tormenta con granizo ligero';

  @override
  String get weatherThunderstormHeavyHail => 'Tormenta con granizo intenso';

  @override
  String weatherUnknown(int code) {
    return 'Desconocido (código $code)';
  }

  @override
  String weatherToday(String date) {
    return 'Hoy ($date)';
  }

  @override
  String get weatherTodayShort => 'Hoy';

  @override
  String get weatherMorning => 'Mañana (9h)';

  @override
  String get weatherAfternoon => 'Tarde (15h)';

  @override
  String get weatherEvening => 'Noche (21h)';

  @override
  String weatherWind(int speed) {
    return 'viento $speed km/h';
  }

  @override
  String get transitTransfer => 'trasbordo';

  @override
  String get transitWaiting => 'espera';

  @override
  String get transitDuration => 'Duración:';

  @override
  String get transitDeparture => 'Salida:';

  @override
  String get transitArrival => 'Llegada:';

  @override
  String get transitDirect => 'directo';

  @override
  String transitTransferCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trasbordos',
      one: '1 trasbordo',
    );
    return '$_temp0';
  }

  @override
  String transitOption(int index, String api) {
    return 'Opción $index (vía $api)';
  }

  @override
  String get transitSections => 'Secciones:';

  @override
  String get transitNoRoutes =>
      'No se encontraron rutas de transporte público entre estas ubicaciones.';

  @override
  String get transitNoApiKey =>
      'No hay clave API de transporte configurada. Establece una clave SNCF o PRIM en Ajustes > Rutas.';

  @override
  String transitInvalidKey(String api) {
    return 'La clave API de $api no es válida. Compruébala en Ajustes > Rutas.';
  }

  @override
  String get transitRateLimit =>
      'Límite de tasa de la API de transporte alcanzado. Inténtalo más tarde.';

  @override
  String get transitSncfRequired =>
      'Se necesita clave API de SNCF para viajes fuera de Île-de-France. Configúrala en Ajustes > Rutas.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonSave => 'Guardar';

  @override
  String commonFailed(String error) {
    return 'Falló: $error';
  }

  @override
  String get commonEnterApiKey => 'Por favor introduce una clave API';

  @override
  String get noProviderConfigured =>
      'No hay proveedor de LLM configurado. Por favor configura un proveedor en Ajustes.';

  @override
  String get telegramBotPrivate => 'Este bot es privado.';

  @override
  String get localeSettingsTitle => 'Idioma';

  @override
  String get localeSystem => 'Predeterminado del sistema';

  @override
  String get localeEnglish => 'Inglés';

  @override
  String get localeFrench => 'Francés';

  @override
  String get localeSpanish => 'Español';

  @override
  String get localeGerman => 'Alemán';

  @override
  String get localeItalian => 'Italiano';

  @override
  String get agentLanguageDirective =>
      'RESPONSE LANGUAGE: SPANISH. You MUST always respond in Spanish. DEBES responder siempre en español.';

  @override
  String get agentKeyBehaviors =>
      'Key behaviors:\n- BEFORE calling any tool, check the <knowledge_context> and memory above. If they already contain the answer (address, preference, contact, etc.), respond directly — do NOT call tools for information you already have.\n- Use knowledge data as tool input when chaining: if you know the user\'s home address from the knowledge context, pass it to geocode instead of calling get_location.\n- get_location returns the device CURRENT physical position only. Use it for \"where am I now\", \"nearest X\", \"from my current position\" — never for stored addresses or known places.\n- When you need information NOT in the knowledge context, call the appropriate tool(s) immediately without asking permission.\n- Chain tools when needed: if a tool requires coordinates but you have an address (from knowledge or the user), call geocode first.\n- When the user tells you personal information to remember (e.g. \"I live at...\", \"my dentist is...\"), just acknowledge and store it via knowledge_store. Do NOT call other tools or suggest actions in response.\n- Be concise and helpful. Use markdown formatting.';

  @override
  String get agentRespondInstructions =>
      'You MUST respond in Spanish. All your output text must be in Spanish. Responde siempre en español.';

  @override
  String get batteryCharging => 'cargando';

  @override
  String get batteryDischarging => 'descargando';

  @override
  String get batteryFull => 'completa';

  @override
  String get batteryConnectedNotCharging => 'conectada (no cargando)';

  @override
  String get batteryUnknown => 'desconocido';

  @override
  String agentLlmError(String error) {
    return 'Llamada al LLM fallida: $error';
  }

  @override
  String get agentMaxIterations =>
      'Se alcanzó el número máximo de iteraciones de herramientas.';

  @override
  String agentError(String error) {
    return 'Error: $error';
  }

  @override
  String get telegramErrorGeneric =>
      'Lo siento, encontré un error. Por favor inténtalo de nuevo.';

  @override
  String get telegramErrorProcessing =>
      'Ocurrió un error al procesar tu mensaje.';

  @override
  String get notifChannelName => 'Servicio en Segundo Plano de DroidClaw';

  @override
  String get notifChannelDesc =>
      'Servicio en segundo plano para el bot de Telegram y tareas programadas';

  @override
  String get notifServiceActive => 'DroidClaw - Activo';

  @override
  String get notifServiceRunning => 'Servicio en segundo plano activo';

  @override
  String get notifBotActive => 'Bot de DroidClaw - Activo';

  @override
  String notifBotMessages(int count) {
    return 'Mensajes procesados: $count';
  }

  @override
  String get notifBotError => 'Bot de DroidClaw - Error';

  @override
  String get notifBotInvalidToken => 'Token del bot inválido';

  @override
  String get notifBotDisconnected => 'Bot de DroidClaw - Desconectado';

  @override
  String get notifBotRetrying => 'Reintentando...';

  @override
  String notifLastCron(String name) {
    return 'Última tarea: $name';
  }

  @override
  String cronLastRun(String date) {
    return 'Última: $date';
  }

  @override
  String get logsTitle => 'Registros';

  @override
  String get logsEmpty => 'Sin entradas de registro';

  @override
  String get logsFilterAll => 'Todos';

  @override
  String get logsFilterInfo => 'Info';

  @override
  String get logsFilterWarning => 'Advertencia';

  @override
  String get logsFilterError => 'Error';

  @override
  String get logsSourceAgent => 'Agente';

  @override
  String get logsSourceCron => 'Cron';

  @override
  String get logsSourceService => 'Servicio';

  @override
  String get logsSourceTelegram => 'Telegram';

  @override
  String get logsSourceApp => 'App';

  @override
  String get logsClearAll => 'Borrar todos los registros';

  @override
  String get logsClearConfirm => '¿Eliminar todas las entradas de registro?';

  @override
  String logsEntryCount(int count) {
    return '$count entradas';
  }

  @override
  String get logsCleared => 'Registros borrados';

  @override
  String logsPurged(int count) {
    return '$count entradas antiguas purgadas';
  }

  @override
  String get cronDeleteGroup => '¿Eliminar todas las ejecuciones de este cron?';

  @override
  String get cronDeleteExecution => '¿Eliminar esta ejecución?';

  @override
  String cronDeleteGroupCount(int count) {
    return 'Esto eliminará $count sesiones.';
  }

  @override
  String get chatListening => 'Escuchando...';

  @override
  String chatSpeechError(String error) {
    return 'Error de reconocimiento de voz: $error';
  }

  @override
  String get chatSpeechUnavailable =>
      'Reconocimiento de voz no disponible en este dispositivo';

  @override
  String get voiceSpeaking => 'Leyendo en voz alta...';

  @override
  String get voiceStopSpeaking => 'Detener la lectura';

  @override
  String get voiceLinkWord => 'enlace';

  @override
  String voiceLanguageUnavailable(String language) {
    return 'No hay voz disponible para \"$language\" — se usará la voz predeterminada';
  }

  @override
  String get voiceTtsUnavailable =>
      'La síntesis de voz no está disponible en este dispositivo';

  @override
  String get voiceConvListening => 'Escuchando… habla ahora';

  @override
  String get voiceConvProcessing => 'Pensando…';

  @override
  String get voiceConvSpeaking => 'Hablando… toca para interrumpir';

  @override
  String get voiceConvExit => 'Terminar la conversación de voz';

  @override
  String get voiceClarificationPrompt =>
      'No te he entendido, ¿puedes repetirlo?';

  @override
  String get voiceConvNotUnderstood =>
      'Sigo sin entenderte — conversación de voz terminada';

  @override
  String get agentSummarizeInstructions => 'Write the summary in Spanish.';

  @override
  String get settingsExportConversations => 'Exportar conversaciones';

  @override
  String get settingsExportSubtitle =>
      'Compartir todas las conversaciones en JSON';

  @override
  String get settingsResetAll => 'Borrar todos los datos';

  @override
  String get settingsResetAllSubtitle =>
      'Claves API, conversaciones, conocimiento, programaciones, Telegram';

  @override
  String get resetConfirmTitle => '¿Borrar todos los datos?';

  @override
  String get resetConfirmBody =>
      'Elimina permanentemente todas las claves API, las conversaciones, la base de conocimiento, los avisos programados, la configuración de Telegram, las trazas y los registros. La aplicación vuelve a la configuración inicial.';

  @override
  String get resetConfirmButton => 'Borrar todo';

  @override
  String get resetDone => 'Todos los datos han sido borrados';

  @override
  String get exportProgress => 'Exportando...';

  @override
  String exportSuccess(int count) {
    return '$count conversaciones exportadas';
  }

  @override
  String get exportEmpty => 'No hay conversaciones para exportar';

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get knowledgeTitle => 'Grafo de conocimiento';

  @override
  String get knowledgeSubtitle => 'Memoria persistente entre conversaciones';

  @override
  String get knowledgeEnable => 'Activar grafo de conocimiento';

  @override
  String get knowledgeEnableDesc =>
      'Extraer y recordar conocimientos de las conversaciones automáticamente';

  @override
  String get knowledgeAutoExtract => 'Extracción automática';

  @override
  String get knowledgeAutoExtractDesc =>
      'Extraer entidades y hechos después de cada respuesta';

  @override
  String knowledgeStatsEntities(int count) {
    return '$count entidades';
  }

  @override
  String knowledgeStatsRelations(int count) {
    return '$count relaciones';
  }

  @override
  String knowledgeStatsSize(String size) {
    return 'Tamaño de la base: $size';
  }

  @override
  String get knowledgeForgetAll => 'Olvidar todo';

  @override
  String get knowledgeForgetAllDesc =>
      'Eliminar todo el conocimiento recordado';

  @override
  String get knowledgeForgetConfirmTitle => '¿Olvidar todo?';

  @override
  String get knowledgeForgetConfirmBody =>
      'Esto eliminará permanentemente todas las entidades, relaciones y hechos del grafo de conocimiento. Esta acción no se puede deshacer.';

  @override
  String get knowledgeForgetConfirmButton => 'Olvidar todo';

  @override
  String get knowledgeEmpty => 'Sin conocimientos almacenados';

  @override
  String get knowledgeForgotten => 'Todo el conocimiento eliminado';

  @override
  String get settingsKnowledge => 'Grafo de conocimiento';

  @override
  String get settingsKnowledgeSubtitle => 'Ajustes de memoria persistente';

  @override
  String get llmTracesTitle => 'Trazas LLM';

  @override
  String get llmTracesEmpty => 'No hay trazas registradas';

  @override
  String llmTracesStatsHeader(int count, String tokens, String latency) {
    return '$count llamadas · $tokens tokens · ${latency}s prom';
  }

  @override
  String get llmTracesLast24h => 'Últimas 24 horas';

  @override
  String get llmTracesFilterAll => 'Todos';

  @override
  String get llmTracesFilterChat => 'Chat';

  @override
  String get llmTracesFilterSummarize => 'Resumen';

  @override
  String get llmTracesFilterExtract => 'Extracción';

  @override
  String get llmTracesClearAll => 'Borrar todas las trazas';

  @override
  String get llmTracesClearConfirm => '¿Eliminar todas las trazas LLM?';

  @override
  String get llmTracesCleared => 'Trazas borradas';

  @override
  String get llmTraceDetailTitle => 'Detalle de la traza';

  @override
  String get llmTraceTokens => 'Tokens';

  @override
  String get llmTraceTokensIn => 'Entrada';

  @override
  String get llmTraceTokensOut => 'Salida';

  @override
  String get llmTraceTokensTotal => 'Total';

  @override
  String llmTraceLatency(int ms) {
    return 'Latencia: $ms ms';
  }

  @override
  String llmTraceSystemPrompt(int chars) {
    return 'Prompt del sistema ($chars car.)';
  }

  @override
  String llmTraceMessages(int count) {
    return 'Mensajes ($count)';
  }

  @override
  String llmTraceResponse(int chars) {
    return 'Respuesta ($chars car.)';
  }

  @override
  String get llmTraceToolsCalled => 'Herramientas usadas';

  @override
  String get llmTraceFinishReason => 'Razón de fin';

  @override
  String get llmTraceError => 'Error';

  @override
  String llmTraceIteration(int n) {
    return 'iter $n';
  }

  @override
  String llmTracesSessionCalls(int count) {
    return '$count llamadas';
  }

  @override
  String get llmTracesSessionChat => 'Chat';

  @override
  String get llmTracesSessionCron => 'Cron';

  @override
  String get llmTracesSessionExtract => 'Extracción';

  @override
  String get llmTracesUngrouped => 'Llamadas sin agrupar';

  @override
  String get llmTimelineTitle => 'Cronología de sesión';

  @override
  String get llmTimelineFinalResponse => 'Respuesta final';

  @override
  String get llmTimelineSummarize => 'Resumen del contexto';

  @override
  String get llmTimelineExtract => 'Extracción KG';

  @override
  String llmTimelineToolsCalled(String tools) {
    return 'Herramientas: $tools';
  }

  @override
  String get llmTimelineUserPrompt => 'Prompt';

  @override
  String llmTimelineLlmCall(int n) {
    return 'Llamada LLM #$n';
  }

  @override
  String get settingsLlmTraces => 'Trazas LLM';

  @override
  String get settingsLlmTracesSubtitle =>
      'Historial de llamadas API y uso de tokens';

  @override
  String get knowledgeBrowse => 'Explorar entidades';

  @override
  String get knowledgeBrowseSubtitle =>
      'Inspeccionar el conocimiento almacenado';

  @override
  String get knowledgeExport => 'Exportar base de conocimiento';

  @override
  String get knowledgeExportSubtitle => 'Exportar todas las entidades en JSON';

  @override
  String knowledgeExportSuccess(int count) {
    return '$count entidades exportadas';
  }

  @override
  String get knowledgeLanguageLabel => 'Idioma de la base de conocimiento';

  @override
  String knowledgeLanguageLocked(String language) {
    return 'Todo el conocimiento se almacena en $language. Cambiar mediante Olvidar todo.';
  }

  @override
  String get knowledgeRebuild => 'Reconstruir desde conversaciones';

  @override
  String get knowledgeRebuildDesc =>
      'Reprocesar todo el historial de conversaciones en la base de conocimiento';

  @override
  String get knowledgeRebuildConfirmTitle =>
      '¿Reconstruir la base de conocimiento?';

  @override
  String knowledgeRebuildConfirmBody(int count, int sessions) {
    return 'Se procesarán $count turnos de conversación en $sessions sesiones. Cada turno requiere una llamada API LLM. Esto puede tardar varios minutos.';
  }

  @override
  String knowledgeRebuildProgress(int current, int total) {
    return 'Procesando $current de $total...';
  }

  @override
  String knowledgeRebuildComplete(int processed, int failed) {
    return 'Reconstrucción completada: $processed turnos procesados, $failed fallidos';
  }

  @override
  String knowledgeRebuildCancelled(int processed) {
    return 'Reconstrucción cancelada tras $processed turnos';
  }

  @override
  String get knowledgeRebuildEmpty => 'No hay conversaciones para procesar';

  @override
  String get kgBrowserTitle => 'Explorador de conocimiento';

  @override
  String get kgBrowserSearch => 'Buscar entidades...';

  @override
  String get kgBrowserEmpty => 'No se encontraron entidades';

  @override
  String get kgFilterAll => 'Todos';

  @override
  String get kgFilterPerson => 'Persona';

  @override
  String get kgFilterPlace => 'Lugar';

  @override
  String get kgFilterOrg => 'Org';

  @override
  String get kgFilterEvent => 'Evento';

  @override
  String get kgFilterConcept => 'Concepto';

  @override
  String get kgFilterDate => 'Fecha';

  @override
  String get kgFilterHot => 'Caliente';

  @override
  String get kgFilterWarm => 'Tibio';

  @override
  String get kgFilterCool => 'Fresco';

  @override
  String get kgFilterCold => 'Frío';

  @override
  String get kgEntityFacts => 'Hechos';

  @override
  String get kgEntityRelations => 'Relaciones';

  @override
  String get kgEntityAliases => 'Alias';

  @override
  String get kgEntityDecay => 'Diagnóstico de deterioro';

  @override
  String get kgEntityDelete => 'Eliminar entidad';

  @override
  String get kgEntityDeleteConfirm =>
      '¿Desactivar esta entidad? Ya no aparecerá en las búsquedas.';

  @override
  String get kgEntityDeleted => 'Entidad desactivada';

  @override
  String kgFactCount(int count) {
    return '$count hechos';
  }

  @override
  String get kgRetentionScore => 'Puntuación de retención';

  @override
  String get kgLoadMore => 'Cargar más';

  @override
  String get settingsEmbedding => 'Embeddings';

  @override
  String get settingsEmbeddingSubtitle => 'Proveedor de vectores';

  @override
  String get embeddingTitle => 'Proveedor de Embeddings';

  @override
  String get embeddingDescription =>
      'Configure una API de embedding remota para búsqueda semántica en el Knowledge Graph. Gemini ofrece un generoso nivel gratuito.';

  @override
  String get embeddingProvider => 'Proveedor';

  @override
  String get embeddingProviderNone => 'Ninguno (desactivado)';

  @override
  String get embeddingModel => 'Modelo';

  @override
  String get embeddingDimensions => 'Dimensiones';

  @override
  String get embeddingUseOwnApiKey => 'Usar clave API dedicada';

  @override
  String get embeddingUseOwnApiKeySubtitle =>
      'Desactivado = reutilizar la clave del LLM';

  @override
  String get embeddingApiKey => 'Clave API de Embedding';

  @override
  String get embeddingTestButton => 'Probar Embedding';

  @override
  String embeddingTestSuccess(int dims, int ms) {
    return '¡Éxito! Vector de $dims dimensiones en ${ms}ms';
  }

  @override
  String get embeddingSave => 'Guardar';

  @override
  String get embeddingSaved => 'Proveedor de embedding guardado';

  @override
  String get embeddingProviderLocal => 'Local (en el dispositivo)';

  @override
  String get embeddingLocalSection => 'Modelo en el dispositivo';

  @override
  String get embeddingLocalConsent =>
      'EmbeddingGemma 300M se descargará desde Hugging Face (~330 MB). La descarga usa solo Wi-Fi a menos que permitas datos móviles. Una vez descargado, la búsqueda semántica funciona completamente sin conexión y sin clave API.';

  @override
  String get embeddingLocalDimensionsNote =>
      'Las dimensiones de salida están fijadas en 256 (truncamiento Matryoshka).';

  @override
  String get embeddingLocalAllowMetered => 'Permitir datos móviles';

  @override
  String get embeddingLocalAllowMeteredSubtitle => 'Desactivado = solo Wi-Fi';

  @override
  String get embeddingLocalDownload => 'Descargar modelo';

  @override
  String get embeddingLocalCancel => 'Cancelar descarga';

  @override
  String get embeddingLocalRetry => 'Reintentar descarga';

  @override
  String get embeddingLocalDelete => 'Eliminar modelo';

  @override
  String get embeddingLocalDeleteConfirm =>
      '¿Eliminar el modelo descargado (~330 MB)? La búsqueda semántica dejará de funcionar hasta que se descargue de nuevo.';

  @override
  String get embeddingLocalStateAbsent => 'Modelo no descargado';

  @override
  String embeddingLocalStateDownloading(int pct) {
    return 'Descargando… $pct%';
  }

  @override
  String get embeddingLocalStateVerifying =>
      'Verificando sumas de comprobación…';

  @override
  String get embeddingLocalStateReady => 'Modelo listo';

  @override
  String embeddingLocalStateFailed(String error) {
    return 'Error de descarga: $error';
  }

  @override
  String get embeddingLocalBenchmark => 'Ejecutar benchmark de latencia';

  @override
  String embeddingLocalBenchmarkResult(int ms, int runs, String verdict) {
    return 'Mediana $ms ms en $runs ejecuciones — $verdict';
  }

  @override
  String get embeddingLocalVerdictFast => 'rápido (apto como predeterminado)';

  @override
  String get embeddingLocalVerdictAcceptable => 'aceptable (opcional)';

  @override
  String get embeddingLocalVerdictSlow => 'lento (solo respaldo sin conexión)';

  @override
  String get embeddingBackfillSection =>
      'Recodificación de la base de conocimientos';

  @override
  String get embeddingBackfillHint =>
      'Recodifica el conocimiento almacenado en el espacio de embeddings del proveedor guardado. Hasta que termine, la búsqueda semántica sigue usando el espacio anterior. También se ejecuta automáticamente durante la carga cuando el proveedor local está seleccionado.';

  @override
  String embeddingBackfillStatus(int done, int total) {
    return '$done / $total entidades en el espacio activo';
  }

  @override
  String get embeddingBackfillComplete =>
      'Todas las entidades están en el espacio de embeddings activo';

  @override
  String get embeddingBackfillStart => 'Recodificar ahora';

  @override
  String get embeddingBackfillCancel => 'Detener';
}
