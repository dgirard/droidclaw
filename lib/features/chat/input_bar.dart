import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Chat input bar with text field and dynamic right-side button (mic or send).
class InputBar extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback? onMicToggle;

  /// Fired on every user/IME edit of the text field — NOT on programmatic
  /// [InputBarState.setText] (speech-to-text fills). Used by the chat screen
  /// to stop narration and demote a pending voice turn to typed.
  final VoidCallback? onUserTyped;

  final bool enabled;
  final bool isListening;

  const InputBar({
    super.key,
    required this.onSend,
    this.onMicToggle,
    this.onUserTyped,
    this.enabled = true,
    this.isListening = false,
  });

  @override
  State<InputBar> createState() => InputBarState();
}

class InputBarState extends State<InputBar> {
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

  /// Replace entire text content (used by speech-to-text partial results).
  void setText(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  /// Insert text at cursor position.
  void insertText(String text) {
    final currentText = _controller.text;
    final selection = _controller.selection;
    // Clamp selection to valid range (can be stale after clear())
    final start = selection.start.clamp(0, currentText.length);
    final end = selection.end.clamp(0, currentText.length);
    final newText = currentText.replaceRange(start, end, text);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    setState(() {});
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
    final l = AppLocalizations.of(context);

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
          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              onChanged: (_) {
                widget.onUserTyped?.call();
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: l.chatInputHint,
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

          // Dynamic action button: send (when text) or mic (when empty)
          _buildActionButton(theme, l),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, AppLocalizations l) {
    if (_hasText) {
      return IconButton.filled(
        icon: const Icon(Icons.send),
        onPressed: widget.enabled ? _send : null,
        tooltip: l.chatSend,
      );
    }

    if (widget.onMicToggle == null) {
      // No mic support — show disabled send button
      return IconButton.filled(
        icon: const Icon(Icons.send),
        onPressed: null,
        tooltip: l.chatSend,
      );
    }

    // Mic button — green when idle, red when listening
    return IconButton.filled(
      icon: Icon(widget.isListening ? Icons.mic : Icons.mic_none),
      style: IconButton.styleFrom(
        backgroundColor: widget.isListening
            ? theme.colorScheme.error
            : Colors.green,
        foregroundColor: Colors.white,
      ),
      onPressed: widget.enabled ? widget.onMicToggle : null,
      tooltip: widget.isListening ? l.chatListening : l.chatVoiceInput,
    );
  }
}
