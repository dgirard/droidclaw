---
title: "fix: Rendre les URLs cliquables dans les bulles de chat"
type: fix
date: 2026-03-13
---

# fix: Rendre les URLs cliquables dans les bulles de chat

Les URLs affich\u00e9es dans le chat (messages assistant et tool results) ne sont pas cliquables.

## Probl\u00e8me

Deux cas concern\u00e9s dans `lib/features/chat/message_bubble.dart` :

1. **Messages assistant** (ligne 59) : `MarkdownBody` g\u00e8re `onTapLink` pour les liens markdown `[text](url)`, mais les URLs brutes comme `https://www.proofeditor.ai/d/xxx` ne sont PAS auto-link\u00e9es (markdown standard ne le fait pas).

2. **Tool results** (ligne 133) : utilisent un simple `Text` widget \u2014 aucune d\u00e9tection d'URL.

## Solution

Pr\u00e9-traiter le texte avec une regex pour wrapper les URLs brutes en syntaxe markdown `[url](url)` avant le rendu. Cela r\u00e8gle les deux cas en un seul point :

### `lib/features/chat/message_bubble.dart`

```dart
/// Wrap bare URLs in markdown link syntax so MarkdownBody makes them tappable.
static String _linkifyUrls(String text) {
  // Match URLs not already inside markdown link syntax [...](...)
  return text.replaceAllMapped(
    RegExp(r'(?<!\]\()https?://[^\s\)<>]+'),
    (m) {
      final url = m.group(0)!;
      // Don't wrap if already part of markdown link [text](url)
      final before = m.start > 0 ? text[m.start - 1] : '';
      if (before == '(') return url;
      return '[$url]($url)';
    },
  );
}
```

**Pour les messages assistant** : appliquer `_linkifyUrls()` au `data` du `MarkdownBody`.

**Pour les tool results** : remplacer le `Text` widget par un petit `MarkdownBody` (d\u00e9j\u00e0 import\u00e9), ou bien utiliser `Linkify` du package `flutter_linkify`. L'approche `MarkdownBody` \u00e9vite une nouvelle d\u00e9pendance.

## Acceptance Criteria

- [ ] Les URLs brutes dans les messages assistant sont cliquables (ouvrent le navigateur)
- [ ] Les URLs dans les tool results sont cliquables
- [ ] Les liens markdown existants `[text](url)` continuent de fonctionner
- [ ] Les URLs ne sont pas doubl\u00e9es si le LLM envoie d\u00e9j\u00e0 `[text](url)`
- [ ] Pas de nouvelle d\u00e9pendance (utiliser MarkdownBody d\u00e9j\u00e0 pr\u00e9sent)

## Fichiers \u00e0 modifier

- `lib/features/chat/message_bubble.dart` : ajouter `_linkifyUrls()`, l'appliquer au MarkdownBody assistant et au widget tool result

## References

- `lib/features/chat/message_bubble.dart:59` \u2014 MarkdownBody assistant
- `lib/features/chat/message_bubble.dart:133` \u2014 Text widget tool result
- Package: `flutter_markdown: ^0.7.7+1` (d\u00e9j\u00e0 en d\u00e9pendance)
- Package: `url_launcher` (d\u00e9j\u00e0 import\u00e9 ligne 5)
