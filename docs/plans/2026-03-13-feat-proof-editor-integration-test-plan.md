---
title: "Integration test ProofEditorTool contre l'API r\u00e9elle"
type: feat
date: 2026-03-13
---

# Integration Test ProofEditorTool (Real API)

## Overview

Test d'int\u00e9gration du `ProofEditorTool` contre l'API r\u00e9elle de ProofEditor.ai (pas de mocks).
Le test ex\u00e9cute un sc\u00e9nario complet : cr\u00e9ation, lecture, append en bas, insertion en haut via edit_v2, suppression locale.

## Test Flow

```
create (titre + 2 sections)
  \u2193
read \u2192 valider le contenu
  \u2193
append sous "# Bas" \u2192 read \u2192 valider le texte ajout\u00e9
  \u2193
snapshot \u2192 extraire baseToken + ref du 1er bloc
  \u2193
edit_v2 (insert_after b0) \u2192 read \u2192 valider le texte ins\u00e9r\u00e9 en haut
  \u2193
delete (local) \u2192 valider que le store est vide
```

## Acceptance Criteria

- [ ] Le test utilise l'API r\u00e9elle (pas de `MockClient`)
- [ ] Skip automatique si ProofEditor.ai est injoignable (`markTestSkipped`)
- [ ] Cr\u00e9ation d'un document avec titre horodat\u00e9 + 2 sections markdown
- [ ] Read apr\u00e8s create valide le contenu original
- [ ] Append sous la section `# Bas` ajoute du texte, confirm\u00e9 par read
- [ ] Snapshot + edit_v2 `insert_after` sur le 1er bloc ins\u00e8re du texte en haut
- [ ] Read final valide que le texte ins\u00e9r\u00e9 en haut est pr\u00e9sent
- [ ] Delete local retire le doc du store
- [ ] Tag\u00e9 `@Tags(['integration'])` pour ne pas tourner dans `flutter test` standard
- [ ] Nettoyage du r\u00e9pertoire temp dans `tearDownAll`

## Technical Approach

### Fichier

`test/proof_editor_integration_test.dart`

### Setup

```dart
@Tags(['integration'])

late ProofDocumentStore store;
late ProofEditorTool tool;
late String createdSlug; // partag\u00e9 entre les \u00e9tapes

setUpAll(() async {
  // Pre-flight: v\u00e9rifier que l'API est joignable
  final client = http.Client();
  try {
    final response = await client.get(
      Uri.parse('https://www.proofeditor.ai'),
    ).timeout(Duration(seconds: 10));
    if (response.statusCode >= 500) {
      markTestSkipped('ProofEditor.ai indisponible');
    }
  } on Exception {
    markTestSkipped('ProofEditor.ai injoignable');
  } finally {
    client.close();
  }

  store = ProofDocumentStore('${tempDir.path}/docs.json');
  tool = ProofEditorTool(store: store); // PAS de httpClientFactory = client r\u00e9el
});
```

### \u00c9tape 1 : Create

```dart
test('1. create document', () async {
  final result = await tool.execute({
    'operation': 'create',
    'title': 'Test DroidClaw ${DateTime.now().toIso8601String()}',
    'content': '# Haut\n\nContenu initial en haut.\n\n# Bas\n\nContenu initial en bas.',
  });
  expect(result.isError, isFalse);
  // Extraire le slug du forLLM : "Slug: xxx"
  createdSlug = RegExp(r'Slug: (\S+),').firstMatch(result.forLLM)!.group(1)!;
  // V\u00e9rifier stock\u00e9
  expect(await store.getBySlug(createdSlug), isNotNull);
});
```

### \u00c9tape 2 : Read + validation

```dart
test('2. read document content', () async {
  final result = await tool.execute({
    'operation': 'read',
    'slug': createdSlug,
  });
  expect(result.isError, isFalse);
  expect(result.forLLM, contains('# Haut'));
  expect(result.forLLM, contains('# Bas'));
  expect(result.forLLM, contains('Contenu initial en haut'));
});
```

### \u00c9tape 3 : Append sous `# Bas`

```dart
test('3. append under Bas section', () async {
  final result = await tool.execute({
    'operation': 'append',
    'slug': createdSlug,
    'section': 'Bas',  // ou '# Bas' ? \u00c0 valider
    'content': 'Texte ajout\u00e9 en bas du document.',
  });
  expect(result.isError, isFalse);
});
```

### \u00c9tape 4 : Read apr\u00e8s append

```dart
test('4. read validates append', () async {
  final result = await tool.execute({
    'operation': 'read',
    'slug': createdSlug,
  });
  expect(result.isError, isFalse);
  expect(result.forLLM, contains('Texte ajout\u00e9 en bas du document'));
});
```

### \u00c9tape 5 : Snapshot + Edit V2 (insert en haut)

```dart
test('5. snapshot then edit_v2 insert_after first block', () async {
  // Snapshot pour obtenir les blocs + baseToken
  final snap = await tool.execute({
    'operation': 'snapshot',
    'slug': createdSlug,
  });
  expect(snap.isError, isFalse);

  // Parser le baseToken et le premier ref
  final baseToken = RegExp(r'mutationBase: (\S+)')
      .firstMatch(snap.forLLM)!.group(1)!;
  final firstRef = RegExp(r'\[(b\d+)\]')
      .firstMatch(snap.forLLM)!.group(1)!;

  // Insert apr\u00e8s le premier bloc (= en haut du doc)
  final result = await tool.execute({
    'operation': 'edit_v2',
    'slug': createdSlug,
    'base_token': baseToken,
    'ops': [
      {
        'op': 'insert_after',
        'ref': firstRef,
        'blocks': [
          {'markdown': 'Texte ins\u00e9r\u00e9 en haut du document.'},
        ],
      },
    ],
  });
  expect(result.isError, isFalse);
});
```

### \u00c9tape 6 : Read apr\u00e8s insert

```dart
test('6. read validates insert at top', () async {
  final result = await tool.execute({
    'operation': 'read',
    'slug': createdSlug,
  });
  expect(result.isError, isFalse);
  expect(result.forLLM, contains('Texte ins\u00e9r\u00e9 en haut du document'));
  // V\u00e9rifier l'ordre : le texte ins\u00e9r\u00e9 apparait AVANT le texte append\u00e9
  final insertIdx = result.forLLM.indexOf('Texte ins\u00e9r\u00e9 en haut');
  final appendIdx = result.forLLM.indexOf('Texte ajout\u00e9 en bas');
  expect(insertIdx, lessThan(appendIdx));
});
```

### \u00c9tape 7 : Delete local

```dart
test('7. delete removes from local store', () async {
  final result = await tool.execute({
    'operation': 'delete',
    'slug': createdSlug,
  });
  expect(result.isError, isFalse);
  expect(result.forLLM, contains('removed'));
  expect(await store.getBySlug(createdSlug), isNull);
});
```

## Points d'attention

### Format du param\u00e8tre `section`

L'API attend-elle `'Bas'` (texte seul) ou `'# Bas'` (markdown complet) ? La description du param\u00e8tre dit "Markdown heading text", ce qui sugg\u00e8re le texte seul. **\u00c0 valider empiriquement** lors de l'impl\u00e9mentation \u2014 si 409, essayer l'autre format.

### Parsing du snapshot

Le `forLLM` du snapshot est du texte format\u00e9, pas du JSON structur\u00e9 :
```
Document: "Title" (slug: xxx)
mutationBase: mut_abc123
---
[b0] # Haut
[b1] Contenu initial en haut.
[b2] # Bas
[b3] Contenu initial en bas.
```

Le test utilise des regex pour extraire `baseToken` et le premier `ref`. C'est fragile mais acceptable pour un test d'int\u00e9gration.

### Pas de suppression distante

L'op\u00e9ration `delete` ne supprime que du store local. Les documents cr\u00e9\u00e9s par les tests persistent sur ProofEditor.ai. Le titre horodat\u00e9 `"Test DroidClaw [timestamp]"` permet de les identifier.

La doc API (`/agent-docs`) retourne 502 actuellement \u2014 impossible de v\u00e9rifier s'il existe un endpoint DELETE non impl\u00e9ment\u00e9 dans le tool.

### Consistance \u00e9ventuelle

Apr\u00e8s un append/edit_v2, le read suivant pourrait retourner du contenu p\u00e9rim\u00e9 si l'API est \u00e9ventuellement consistante. Pas de d\u00e9lai initialement \u2014 en ajouter un (500ms) si le test devient flaky.

### Lancer le test

```bash
# Int\u00e9gration seulement (pas dans flutter test standard)
flutter test --tags integration test/proof_editor_integration_test.dart
```

## References

- Tool: `lib/core/tools/proof_editor_tool.dart`
- Store: `lib/core/tools/proof_document_store.dart`
- Unit tests: `test/proof_editor_tool_test.dart`
- API base: `https://www.proofeditor.ai`
- API docs: `https://www.proofeditor.ai/agent-docs` (502 au 2026-03-13)
