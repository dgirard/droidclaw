---
date: 2026-06-12
topic: memoire-v2-et-interface-vocale
focus: "prochaines améliorations à fort impact (produit et technique) après livraison complète de la roadmap 2026-05-31"
mode: repo-grounded
---

# Ideation: DroidClaw — prochaines améliorations à fort impact

## Grounding Context

**Codebase Context** (première main, session du 2026-06-10/12) : Flutter 3.41/Dart 3.11, 31 outils, dual-isolate (UI + foreground service `remoteMessaging|location`), KG SQLite FTS5 + scan vectoriel paginé, sessions Hive lazy, multi-provider LLM/embedding, Telegram, cron, voix = push-button Groq Whisper. Roadmap sécurité/perf/qualité livrée (388 tests, analyze 0). Gaps : embeddings exigent une clé cloud (mémoire sémantique lobotomisée sinon, silencieusement) ; résultats d'outils éphémères (re-exécution inter-sessions) ; voix sans sortie parlée ni wake word ; KG invisible pendant l'usage ; autonomie = crons rédigés à la main.

**Past learnings** : le partage Hive dual-isolate est le générateur dominant d'incidents (6/16 docs — sortie structurelle nommée : sessions → SQLite) ; l'échec silencieux est le motif récurrent ; pas de harnais d'évals comportementales (la conformité linguistique a régressé deux fois) ; dérive d'API externe détectée seulement par test live manuel.

**External context (2026)** : EmbeddingGemma 308M ONNX (<200 Mo RAM, 768-dim MRL, top MTEB <500M) ; LiteRT-LM/Gemma 4 E2B + ML Kit GenAI (AICore) ; sqlite-vec mature ; microWakeWord sur Android (Home Assistant, prod) ; Voxtral streaming STT en maturation ; ChatGPT Pulse (digests proactifs) ; Android 16 : FGS `remoteMessaging|location` exempt des timeouts 6 h, type `microphone` restreint (pas de démarrage en arrière-plan sur 14+) ; moat concurrentiel : outils natifs téléphone + on-device-first (OpenClaw est cloud).

## Topic Axes

Decomposition skipped — surprise-me mode.

## Ranked Ideas

### 1. Embeddings locaux par défaut (EmbeddingGemma 308M ONNX)
**Description:** `LocalEmbeddingProvider` derrière `EmbeddingProviderFactory`. Téléchargement du modèle au premier usage (pas dans l'APK), troncature MRL à 256-dim (BLOBs ÷3, scan plus rapide), re-embed backfill nocturne sur chargeur. FFI natif → fonctionne dans l'isolate de service sans probe. Cloud = option qualité.
**Basis:** direct: `hasEmbedder == null` → entités stockées sans vecteurs, silencieusement ; external: EmbeddingGemma 308M (HF/Google 2025-26), chemin ONNX Android éprouvé.
**Rationale:** plus grand écart entre la promesse "tout on-device" et l'expérience par défaut ; rend chaque feature aval de similarité gratuite.
**Downsides:** intégration onnxruntime FFI ; tokenizer SentencePiece ; ~200 Mo RAM résidente modèle chargé ; qualité vs cloud à valider.
**Cadrage latence (spike, seuils décidés):** mesurer l'inférence par requête sur appareil réel — <150 ms → défaut local ; 150–300 ms → local opt-in ; >300 ms → local = fallback hors-ligne seulement. Golden test qualité : "Où est-ce que j'habite ?". Le chemin chaud actuel (embed cloud 150–400 ms réseau-dominé) devrait être battu ; les vrais coûts (cold-load 1–3 s, backfill minutes) sont hors du chemin chaud.
**Confidence:** 85% · **Complexity:** Medium · **Status:** Explored

### 2. Mémoire épisodique — les résultats d'outils deviennent des souvenirs
**Description:** tee sur `Stream<AgentEvent>` → table `episodes` Drift (outil, digest args, résumé redacté via TraceRedactor, ts, session, embedding via #1) ; TTL par outil (`AppConstants`) ; freshness-check avant invocation d'outils idempotents ; résumé de session routé par `IngestionPipeline.extractAndStore()` ; consolidation nocturne par dream (replay saillant).
**Basis:** direct: résultats d'outils jetés après chaque tour, substrat bi-temporel + decay + dream déjà livrés ; external: mem0 2026 nomme la mémoire épisodique comme LE gap des systèmes de prod.
**Rationale:** la différence ressentie entre chatbot-avec-outils et assistant qui se souvient ; chaque outil futur produit de la mémoire gratuitement ; latence nette en baisse (1 ms de check SQLite contre des appels d'outils entiers économisés).
**Downsides:** politique TTL/privacy à concevoir ; croissance du KG (weeding nécessaire en phase 2).
**Confidence:** 80% · **Complexity:** Medium · **Status:** Explored

### 3. Morning Pulse + crons auto-proposés
**Description:** digest quotidien intégré (toggle) composé par l'isolate de service : calendrier, météo-position, threads Telegram, entités KG en voie d'oubli (decay d'Ebbinghaus = score de saillance gratuit), crons échoués ; portillon "rien à dire → silence". Phase 2 : détection des demandes répétées → proposition de cron en un tap (desire paths).
**Basis:** direct: seule autonomie actuelle = crons rédigés à la main ; substrat complet livré ; external: ChatGPT Pulse a validé le pattern — avec signaux locaux que Pulse ne peut pas toucher.
**Rationale:** transforme "autonome" de capacité revendiquée en expérience du jour 1.
**Downsides:** première décision produit sur le proactif par défaut ; coût API quotidien.
**Confidence:** 75% · **Complexity:** Medium · **Status:** Unexplored

### 4. Le Docteur — santé unifiée + canaris d'API
**Description:** statut typé par composant de fond → health store ; écran Doctor ; notification en dégradation ; outil `health` pour introspection par l'agent ; canaris sentinelles hebdo (1 token par API configurée) alertant sur dérive.
**Basis:** direct: 16 docs d'incidents, motif "silencieux" ; `bgState.error` rendu nulle part ; dérive ProofEditor vue uniquement par test live manuel.
**Rationale:** la confiance dans l'autonomie meurt au premier cron silencieusement raté ; attrape clés expirées/quotas — ce que la CI ne verra jamais.
**Downsides:** contrat transversal d'émission de statut à décider une fois.
**Confidence:** 80% · **Complexity:** Medium-Low · **Status:** Unexplored

### 5. Unification du stockage — sessions → Drift/SQLite
**Description:** sessions + sidecars → tables Drift derrière l'API `SessionManager` inchangée (tests de caractérisation = contrat de migration) ; memory notes → entités KG ; suppression de la couche `isolate_persistence/`. Clé technique : SQLite WAL a un vrai verrouillage cross-connexion (Hive non) ; deux connexions Drift depuis les deux FlutterEngines = sûr par construction (les SendPorts ne traversent pas les engines — variante DriftIsolate exclue).
**Basis:** direct: 6/16 incidents tracent vers Hive cross-isolate, "chaque fix a engendré le bug suivant" ; sortie structurelle nommée dans les learnings.
**Rationale:** supprime la classe de bugs dominante ; efface du code de contournement ; FTS5 sur l'historique gratuit ; précondition des jointures mémoire riches.
**Downsides:** migration à risque réel ; le plus gros chantier.
**Confidence:** 70% · **Complexity:** High · **Status:** Explored

### 6. Boucle vocale mains-libres
**Description:** trois paliers indépendamment utiles — V1 : sortie TTS des tours initiés à la voix (narration de `ToolResult.forUser`, rédigés courts par construction ; 3e consommateur du stream d'événements) ; V2 : STT streaming (SpeechRecognizer on-device d'abord, Groq fallback, Voxtral à surveiller) + turn-taking auto ; V3 : microWakeWord ONNX dans le FGS, gated sur spike (type FGS `microphone` Android 14+ : pas de démarrage arrière-plan + posture permission ; budget batterie duty-cycle).
**Basis:** direct: voix = bouton-poussoir yeux-sur-écran, inutilisable dans les contextes canoniques (cuisine/voiture) ; `speak` tool existant ; external: microWakeWord en prod chez Home Assistant.
**Rationale:** la différence entre "app de chat avec micro" et "assistant" ; le wake word ne quitte jamais l'appareil — inégalable par les concurrents cloud.
**Downsides:** pipeline audio, batterie, posture micro-permanent ; V3 le plus incertain.
**Confidence:** 65% · **Complexity:** High · **Status:** Explored

### 7. Harnais d'évals comportementales par rejeu
**Description:** export d'une session réelle en fixture (messages + tool calls + résultats) ; rejeu dans l'AgentLoop avec les fakes existants ; assertions de comportement (langue, pas de re-appel, format) ; `flutter test --tags eval` local (conforme no-CI). Chaque incident devient une éval permanente.
**Basis:** direct: conformité linguistique régressée deux fois après correction ; 388 tests, zéro ne peut attraper "a répondu en anglais" ; traces LLM = matière à fixtures.
**Rationale:** change la pente de chaque changement futur pour un mainteneur solo sans CI.
**Downsides:** stratégie d'assertion (heuristiques vs LLM-judge) ; coût API par run.
**Confidence:** 75% · **Complexity:** Medium · **Status:** Unexplored

## Séquence d'exécution retenue (raffinement du 2026-06-12)

| # | Unité | Arc | Taille | Note |
|---|-------|-----|--------|------|
| 1 | V1 sortie vocale | Interface | S | Gain immédiat, risque ~nul |
| 2 | M1 embeddings locaux | Mémoire | M | Spike d'abord : latence/tokenizer, seuils 150/300 ms |
| 3 | M2 mémoire épisodique | Mémoire | M | S'appuie sur M1 |
| 4 | V2 STT streaming + turn-taking | Interface | M | Indépendant de la mémoire |
| 5 | M5 unification stockage | Mémoire | L | Termine la convergence, efface isolate_persistence/ |
| 6 | V3 wake word | Interface | L | Gated sur spike FGS-microphone + batterie |

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | Tier LLM local + ModelRouter | Séquencé : prouver le chemin ONNX avec les embeddings d'abord |
| 2 | Salience bus | Platformisation prématurée du Pulse |
| 3 | Actuateur AccessibilityService | Risque privacy/abus élevé, blowback documenté (Doubao) |
| 4 | Mode famille multi-utilisateur | Niche + partition privacy difficile |
| 5 | Phone-as-server LAN | Nouvelle surface d'attaque ; Telegram couvre déjà le distant |
| 6 | Méta-outils (3 schémas) | Bénéfice contingent à l'adoption d'un modèle local |
| 7 | Night Shift (budget + batch nocturne) | Pas encore de douleur coût constatée |
| 8 | Pocket witness (épisodique passif) | Après la mémoire épisodique active (#2) |
| 9 | Cluster confiance-mémoire (provenance Admiralty, weeding MUSTIE, codex, belief review) | Phase 2 naturelle après #2 + #5 |
| 10 | Métadonnées de capacités d'outils | DX interne, valeur moindre que les survivantes |
| 11 | Suppression ops dépréciées | Tactique, sous le plancher d'ambition |
| 12 | Mise-en-place pre-staging, ambient cards, auto-dream nocturne, one-timeline, self-evals on-device, sentinel/flight-recorder | Fusionnés dans les survivantes #2, #3, #4, #5, #7 |
