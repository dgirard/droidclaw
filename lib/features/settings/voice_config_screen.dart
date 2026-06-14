import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/services/model_download_manager.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_providers.dart';
import '../../providers/background_service_provider.dart';
import '../../shared/constants.dart';

/// Settings screen for voice / wake word (U7). The wake word is an explicit
/// opt-in, OFF by default. When disabled, nothing about the app changes — no
/// mic service, no model requirement (verified by
/// test/services/wake_word_arbitration_test.dart default-off cases).
class VoiceConfigScreen extends ConsumerStatefulWidget {
  const VoiceConfigScreen({super.key});

  @override
  ConsumerState<VoiceConfigScreen> createState() => _VoiceConfigScreenState();
}

class _VoiceConfigScreenState extends ConsumerState<VoiceConfigScreen> {
  final _keywordController = TextEditingController();
  bool _wakeWordEnabled = false;

  // KWS model download state (reuses the ModelDownloadManager UI pattern from
  // embedding_config_screen).
  ModelDownloadManager? _modelManager;
  StreamSubscription<ModelStatus>? _statusSub;
  ModelStatus? _modelStatus;
  bool _allowMetered = false;

  static const _modelSpec = ModelSpec.wakeWordKws;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _initModelManager();
  }

  void _loadConfig() {
    final config = ref.read(appConfigProvider);
    _wakeWordEnabled = config.voice.wakeWordEnabled;
    _keywordController.text = config.voice.wakeWordKeyword;
  }

  Future<void> _initModelManager() async {
    final manager = await ref.read(modelDownloadManagerProvider.future);
    if (!mounted) return;
    _modelManager = manager;
    _statusSub = manager.statusStream.listen((status) {
      if (status.modelId == _modelSpec.id && mounted) {
        setState(() => _modelStatus = status);
      }
    });
    final status = await manager.refreshStatus(_modelSpec);
    if (mounted) setState(() => _modelStatus = status);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final configStorage = ref.read(configStorageProvider);

    final config = ref.read(appConfigProvider);
    final newConfig = config.copyWith(
      voice: VoiceConfig(
        wakeWordEnabled: _wakeWordEnabled,
        wakeWordKeyword: _keywordController.text.trim().isEmpty
            ? AppConstants.wakeWordDefaultKeyword
            : _keywordController.text.trim(),
      ),
    );

    await configStorage.save(newConfig);
    // Mirror the (non-secret) flags so the service isolate can read them.
    await configStorage.mirrorWakeWordFlags(newConfig);
    ref.read(appConfigProvider.notifier).update(newConfig);

    // The wake word is a background-service consumer: keep the shared service
    // alive while enabled, stop it cleanly when disabled with no other
    // consumer.
    final bg = ref.read(backgroundServiceProvider.notifier);
    if (newConfig.voice.wakeWordEnabled) {
      await bg.ensureServiceRunning();
    } else {
      await bg.stopServiceIfIdle();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.voiceSaved)),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _downloadModel() async {
    final manager = _modelManager;
    if (manager == null) return;
    try {
      await manager.download(_modelSpec, allowMetered: _allowMetered);
    } on ModelDownloadException {
      // Failure state is already reflected on the status stream.
    }
  }

  Future<void> _cancelDownload() async {
    await _modelManager?.cancel(_modelSpec);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.voiceTitle),
        actions: [
          TextButton(onPressed: _save, child: Text(l.voiceSave)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.voiceWakeWordDescription,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Opt-in toggle (OFF by default).
          SwitchListTile(
            title: Text(l.voiceWakeWordEnable),
            subtitle: Text(l.voiceWakeWordEnableSubtitle),
            value: _wakeWordEnabled,
            onChanged: (v) => setState(() => _wakeWordEnabled = v),
            contentPadding: EdgeInsets.zero,
          ),

          if (_wakeWordEnabled) ..._buildEnabledSection(l, theme),
        ],
      ),
    );
  }

  List<Widget> _buildEnabledSection(AppLocalizations l, ThemeData theme) {
    return [
      const SizedBox(height: 8),

      // Free-text keyword field.
      TextField(
        controller: _keywordController,
        decoration: InputDecoration(
          labelText: l.voiceWakeWordKeyword,
          hintText: l.voiceWakeWordKeywordHint,
          helperText: l.voiceWakeWordKeywordHelp,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),

      const SizedBox(height: 24),

      // KWS model download section.
      Text(l.voiceWakeWordModelSection, style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        l.voiceWakeWordModelConsent,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      ..._buildModelControls(l, theme),

      const SizedBox(height: 24),

      // Persistent mic indicator explanation.
      _InfoCard(
        icon: Icons.mic,
        color: Colors.green,
        text: l.voiceWakeWordMicIndicator,
      ),
      const SizedBox(height: 12),

      // Post-reboot limitation (R5) + current status surfaced.
      _InfoCard(
        icon: Icons.restart_alt,
        color: theme.colorScheme.onSurfaceVariant,
        text: l.voiceWakeWordRebootLimitation,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.voiceWakeWordRebootStatus,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),

      const SizedBox(height: 24),

      // Spike guidance (the engine binding is spike-gated — point the user at
      // the on-device guidance doc / harness).
      _InfoCard(
        icon: Icons.science_outlined,
        color: theme.colorScheme.primary,
        text: l.voiceWakeWordSpikeNote,
      ),
    ];
  }

  List<Widget> _buildModelControls(AppLocalizations l, ThemeData theme) {
    final status = _modelStatus;
    final state = status?.state ?? ModelState.absent;

    return [
      Row(
        children: [
          Icon(
            switch (state) {
              ModelState.ready => Icons.check_circle,
              ModelState.failed => Icons.error,
              ModelState.downloading ||
              ModelState.verifying =>
                Icons.downloading,
              ModelState.absent => Icons.cloud_download_outlined,
            },
            size: 20,
            color: switch (state) {
              ModelState.ready => Colors.green,
              ModelState.failed => theme.colorScheme.error,
              _ => theme.colorScheme.onSurfaceVariant,
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(switch (state) {
              ModelState.absent => l.embeddingLocalStateAbsent,
              ModelState.downloading => l.embeddingLocalStateDownloading(
                  ((status?.progress ?? 0) * 100).round()),
              ModelState.verifying => l.embeddingLocalStateVerifying,
              ModelState.ready => l.embeddingLocalStateReady,
              ModelState.failed =>
                l.embeddingLocalStateFailed(status?.error ?? ''),
            }),
          ),
        ],
      ),
      if (state == ModelState.downloading) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(value: status?.progress ?? 0),
      ],
      if (state == ModelState.absent || state == ModelState.failed) ...[
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(l.embeddingLocalAllowMetered),
          subtitle: Text(l.embeddingLocalAllowMeteredSubtitle),
          value: _allowMetered,
          onChanged: (v) => setState(() => _allowMetered = v),
          contentPadding: EdgeInsets.zero,
        ),
      ],
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          if (state == ModelState.absent)
            FilledButton.icon(
              onPressed: _modelManager == null ? null : _downloadModel,
              icon: const Icon(Icons.download),
              label: Text(l.embeddingLocalDownload),
            ),
          if (state == ModelState.failed)
            FilledButton.icon(
              onPressed: _modelManager == null ? null : _downloadModel,
              icon: const Icon(Icons.refresh),
              label: Text(l.embeddingLocalRetry),
            ),
          if (state == ModelState.downloading)
            OutlinedButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.close),
              label: Text(l.embeddingLocalCancel),
            ),
        ],
      ),
    ];
  }
}

/// Small bordered card with an icon + explanatory text (mic indicator,
/// reboot limitation, spike note).
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
