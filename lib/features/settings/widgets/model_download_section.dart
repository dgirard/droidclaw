import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/model_download_manager.dart';
import '../../../l10n/l10n.dart';

/// Reusable model-download UI for a single [ModelSpec]: status line + progress
/// bar + allow-metered switch + download/retry/cancel buttons over a
/// [ModelDownloadManager].
///
/// Owns the status-stream subscription, the on-startup [refreshStatus], and the
/// download/cancel/metered local state — so screens that need an on-device
/// model (embedding U2, wake word U7) share one implementation instead of
/// reimplementing it. Screens supply their own section header/consent text
/// above this widget and may inject extra buttons (e.g. the embedding screen's
/// benchmark/delete) via [extraButtonsBuilder], which receives the current
/// [ModelState] so the buttons can react to readiness.
class ModelDownloadSection extends StatefulWidget {
  /// The model to download. May be null while the parent resolves the manager;
  /// the widget renders nothing until both [manager] and [spec] are available.
  final ModelSpec spec;

  /// Resolved manager (the parent reads it from
  /// `modelDownloadManagerProvider`); null disables the action buttons.
  final ModelDownloadManager? manager;

  /// Optional extra buttons appended to the action row, given the current
  /// model state (the embedding screen injects benchmark + delete here).
  final List<Widget> Function(BuildContext context, ModelState state)?
      extraButtonsBuilder;

  /// Called whenever the model status changes (the embedding screen uses it to
  /// gate its "test embedding" button on model readiness).
  final ValueChanged<ModelStatus>? onStatusChanged;

  const ModelDownloadSection({
    super.key,
    required this.spec,
    required this.manager,
    this.extraButtonsBuilder,
    this.onStatusChanged,
  });

  @override
  State<ModelDownloadSection> createState() => _ModelDownloadSectionState();
}

class _ModelDownloadSectionState extends State<ModelDownloadSection> {
  StreamSubscription<ModelStatus>? _statusSub;
  ModelStatus? _status;
  bool _allowMetered = false;

  @override
  void initState() {
    super.initState();
    _bind(widget.manager);
  }

  @override
  void didUpdateWidget(ModelDownloadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent resolves the manager asynchronously; bind once it arrives.
    if (oldWidget.manager != widget.manager) {
      _statusSub?.cancel();
      _bind(widget.manager);
    }
  }

  Future<void> _bind(ModelDownloadManager? manager) async {
    if (manager == null) return;
    _statusSub = manager.statusStream.listen((status) {
      if (status.modelId == widget.spec.id && mounted) {
        setState(() => _status = status);
        widget.onStatusChanged?.call(status);
      }
    });
    final status = await manager.refreshStatus(widget.spec);
    if (mounted) {
      setState(() => _status = status);
      widget.onStatusChanged?.call(status);
    }
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    final manager = widget.manager;
    if (manager == null) return;
    try {
      await manager.download(widget.spec, allowMetered: _allowMetered);
    } on ModelDownloadException {
      // Failure state is already reflected on the status stream.
    }
  }

  Future<void> _cancel() async {
    await widget.manager?.cancel(widget.spec);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = _status;
    final state = status?.state ?? ModelState.absent;

    final extraButtons =
        widget.extraButtonsBuilder?.call(context, state) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status line.
        Row(
          children: [
            Icon(
              switch (state) {
                ModelState.ready => Icons.check_circle,
                ModelState.failed => Icons.error,
                ModelState.unverified => Icons.gpp_maybe,
                ModelState.downloading ||
                ModelState.verifying =>
                  Icons.downloading,
                ModelState.absent => Icons.cloud_download_outlined,
              },
              size: 20,
              color: switch (state) {
                ModelState.ready => Colors.green,
                ModelState.failed => theme.colorScheme.error,
                ModelState.unverified => theme.colorScheme.error,
                _ => theme.colorScheme.onSurfaceVariant,
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(switch (state) {
                ModelState.absent => l.modelDownloadStateAbsent,
                ModelState.downloading => l.modelDownloadStateDownloading(
                    ((status?.progress ?? 0) * 100).round()),
                ModelState.verifying => l.modelDownloadStateVerifying,
                ModelState.ready => l.modelDownloadStateReady,
                ModelState.unverified => l.modelDownloadStateUnverified,
                ModelState.failed =>
                  l.modelDownloadStateFailed(status?.error ?? ''),
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
            title: Text(l.modelDownloadAllowMetered),
            subtitle: Text(l.modelDownloadAllowMeteredSubtitle),
            value: _allowMetered,
            onChanged: (v) => setState(() => _allowMetered = v),
            contentPadding: EdgeInsets.zero,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (state == ModelState.absent)
              FilledButton.icon(
                onPressed: widget.manager == null ? null : _download,
                icon: const Icon(Icons.download),
                label: Text(l.modelDownloadDownload),
              ),
            if (state == ModelState.failed || state == ModelState.unverified)
              FilledButton.icon(
                onPressed: widget.manager == null ? null : _download,
                icon: const Icon(Icons.refresh),
                label: Text(l.modelDownloadRetry),
              ),
            if (state == ModelState.downloading)
              OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.close),
                label: Text(l.modelDownloadCancel),
              ),
            ...extraButtons,
          ],
        ),
      ],
    );
  }
}
