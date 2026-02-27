---
title: "fix: Agent still responds in English and offers unrequested calculations"
type: fix
date: 2026-02-27
---

# fix: Agent Still Responds in English and Offers Unrequested Calculations

## Problem

Screenshot evidence: user says "j'habite 9 rue Raimu à Montigny-le-Bretonneux" (FR locale active, flag visible). Agent responds:

> "OK. I have stored your address. Now, I still need your current location to calculate the walking time to your home. Can you share your current location?"

Two bugs:
1. **English response** despite FR locale set
2. **Offers to calculate walking time** — user only shared their address, never asked for any calculation

## Root Cause Analysis

### Bug 1: English response

**Most likely**: The conversation was started BEFORE the latest deploy (commit d0fce6c + KB-first prompt changes). The system prompt is rebuilt per API call, but if the conversation was already in progress with old English system prompt, the LLM may have "locked in" on English from the first exchange.

**Secondary risk**: The system prompt is ~90% English (tool descriptions, bootstrap, memory, KB context) with only the identity section and final line in FR. Weaker models may get overwhelmed.

**Verification needed**: Test with a brand-new conversation post-deploy. If it still responds in English, the language directives need further strengthening.

### Bug 2: Over-proactive behavior

The `agentKeyBehaviors` bullet says:
> "When the user shares new personal information, acknowledge it. Do NOT call location or geocoding tools for information the user is giving you."

This prevents calling GPS/geocode tools for the address itself, but does NOT prevent the agent from:
- Proactively offering to calculate walking time
- Asking for current location for a purpose the user never requested
- Suggesting next actions

The agent interprets "acknowledge it" as a minimum — it acknowledges AND then proactively plans what it could do next.

## Fix

### Change 1: Strengthen the "acknowledge only" bullet (5 ARB files)

Replace the bullet about sharing personal info to be explicit:

**EN**: `"When the user shares new personal information, ONLY acknowledge and store it. Do NOT suggest, offer, or perform any further action — wait for the user to ask."`

**FR**: `"Quand l'utilisateur partage de nouvelles informations personnelles, contente-toi de les prendre en note. Ne propose, ne suggère et n'effectue AUCUNE action supplémentaire — attends que l'utilisateur demande."`

**ES**: `"Cuando el usuario comparte nueva información personal, SOLO reconócela y guárdala. NO sugieras, ofrezcas ni realices ninguna acción adicional — espera a que el usuario lo pida."`

**DE**: `"Wenn der Benutzer neue persönliche Informationen teilt, nimm sie NUR zur Kenntnis und speichere sie. Schlage KEINE weiteren Aktionen vor und führe KEINE aus — warte, bis der Benutzer danach fragt."`

**IT**: `"Quando l'utente condivide nuove informazioni personali, SOLO prendine nota e memorizzale. NON suggerire, offrire o eseguire alcuna azione aggiuntiva — attendi che l'utente lo chieda."`

### Change 2: Verify language with new conversation

After deploying, start a **new conversation** (not resume an existing one) and test:
- "j'habite 9 rue Raimu à Montigny-le-Bretonneux" → should respond in French, only acknowledge
- "où est-ce que j'habite ?" → should answer from KB in French
- "où suis-je ?" → should call GPS, respond in French

## Files to Modify

1. `lib/l10n/app_en.arb` — strengthen acknowledge bullet in `agentKeyBehaviors`
2. `lib/l10n/app_fr.arb` — same
3. `lib/l10n/app_es.arb` — same
4. `lib/l10n/app_de.arb` — same
5. `lib/l10n/app_it.arb` — same

Then: `flutter gen-l10n && flutter analyze`

## Verification

1. `flutter analyze` — 0 issues
2. Build + deploy APK
3. Open **new** conversation with FR locale
4. Test: "j'habite 9 rue Raimu" → FR response, no tool suggestion
5. Test: "où est-ce que j'habite ?" → FR answer from KB, no GPS call
