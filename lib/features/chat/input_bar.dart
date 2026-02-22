import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Chat input bar with text field, send button, and mic button.
class InputBar extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback? onMicPressed;
  final bool enabled;

  const InputBar({
    super.key,
    required this.onSend,
    this.onMicPressed,
    this.enabled = true,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool get _hasText => _controller.text.trim().isNotEmpty;

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mic button
          if (widget.onMicPressed != null)
            IconButton(
              icon: const Icon(Icons.mic_outlined),
              onPressed: widget.enabled ? widget.onMicPressed : null,
              tooltip: AppLocalizations.of(context).chatVoiceInput,
            ),

          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).chatInputHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: _hasText && widget.enabled ? _send : null,
              tooltip: AppLocalizations.of(context).chatSend,
            ),
          ),
        ],
      ),
    );
  }

  /// Insert text at cursor position (used by voice input).
  void insertText(String text) {
    final selection = _controller.selection;
    final newText = _controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + text.length,
      ),
    );
    setState(() {});
  }
}
