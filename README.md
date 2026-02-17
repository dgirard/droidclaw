# DroidClaw

> Personal AI assistant on Android — agent loop + tool calling + dual Chat & Telegram interface

![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart)
![Android](https://img.shields.io/badge/Android-API_24+-3DDC84?logo=android)

---

## What is DroidClaw?

DroidClaw is a personal AI assistant that runs **entirely on an Android phone**, with no external server.

- **Agent-based**: agentic LLM loop + iterative tool calling
- **Multi-provider**: Anthropic (Claude), OpenRouter, OpenAI, Groq, Google Gemini
- **Dual interface**: built-in Flutter chat **+ Telegram bot**
- **On-device only**: everything runs on the phone — LLM API calls, tool execution, session management

---

## Origin — From PicoClaw to DroidClaw

DroidClaw is a port of [PicoClaw](https://github.com/sipeed/picoclaw), a Go-based AI assistant (~16K lines) designed to run as a CLI/gateway on lightweight Linux hardware.

### What Was Kept

- **Agent Loop**: the agentic loop (LLM -> tool calls -> iteration)
- **LLM Providers**: multi-provider abstraction (Anthropic, OpenAI, OpenRouter, Groq, Gemini)
- **Tools**: web_search (Brave), web_scrape (HTTP+Markdown), web_scrape_js (WebView), file (sandboxed), get_location (GPS), get_address (reverse geocoding), subagent, message
- **Sessions**: conversation history with Hive persistence
- **Memory**: long-term MEMORY.md + daily notes
- **Skills**: three-tier loading (builtin -> global -> workspace)
- **Summarization**: automatic summarization of long conversations

### What Was Removed

- Shell/exec tools (no shell execution on Android)
- I2C/SPI/USB monitoring (Linux hardware only)
- HTTP health server (no server on mobile)
- Gateway/CLI (replaced by Flutter UI)

### What Was Added

- **Flutter chat UI**: main interface with Markdown rendering, real-time tool indicators, conversation history
- **Telegram bot via Android foreground service**: a DroidClaw innovation. PicoClaw had a server-side Telegram channel (webhook). DroidClaw runs polling **directly on the Android phone** via a foreground service with long polling, with no external server whatsoever. This is a fundamental architecture shift.
- **Scheduled Prompts (Cron)**: define recurring prompts that execute automatically (fixed interval or specific times of day, with day-of-week filtering). Each cron can use a fresh session or continue in the same thread. Managed via Settings > Scheduled Prompts.
- **Reverse Geocoding**: `get_address` tool chains with `get_location` to resolve GPS coordinates into a street address (Nominatim/OpenStreetMap, no API key needed).

---

## Architecture

### Overview

```mermaid
graph TB
    subgraph "Android App"
        subgraph "Main Isolate"
            UI["Flutter Chat UI"]
            TM["TelegramBotManager"]
            AL["AgentLoop"]
            CB["ContextBuilder"]
            SM["SessionManager"]
            TR["ToolRegistry"]
            LP["LLMProvider"]
            RP["Riverpod Providers"]
        end
        subgraph "TaskHandler Isolate"
            TH["TelegramTaskHandler"]
            TA["TelegramApi"]
        end
    end

    User1["User (app)"] --> UI
    User2["User (Telegram)"] --> TG["Telegram API"]
    TG --> TH
    TH <-->|"port comm"| TM
    UI --> AL
    TM --> AL
    AL --> LP
    AL --> TR
    AL --> SM
    AL --> CB
    LP --> LLM["LLM APIs (Anthropic, OpenRouter, ...)"]
    TR --> Tools["web_search / web_scrape / web_scrape_js / file / get_location / get_address / subagent"]
```

### Agent Loop

```mermaid
sequenceDiagram
    participant U as User
    participant AL as AgentLoop
    participant LLM as LLM Provider
    participant T as Tools
    participant S as Session

    U->>AL: message
    AL->>S: add user message
    loop max N iterations
        AL->>LLM: chat(messages, tools)
        LLM-->>AL: response
        alt no tool calls
            AL->>S: add assistant response
            AL-->>U: final response
        else has tool calls
            AL->>S: add assistant + tool_calls
            AL->>T: execute(tool_name, args)
            T-->>AL: ToolResult (forLLM / forUser)
            AL->>S: add tool result
        end
    end
```

### Telegram Dual-Isolate Architecture

```mermaid
graph LR
    subgraph "TaskHandler Isolate (Foreground Service)"
        GP["getUpdates\n(long poll 30s)"]
        SM2["sendMessage"]
    end

    subgraph "Main Isolate"
        BM["TelegramBotManager\nper-chat queues\nmax 3 concurrent"]
        AL2["AgentLoop"]
    end

    TG2["Telegram Server"] <-->|"HTTPS"| GP
    TG2 <-->|"HTTPS"| SM2
    GP -->|"sendDataToMain"| BM
    BM -->|"processMessage"| AL2
    AL2 -->|"response"| BM
    BM -->|"sendDataToTask"| SM2
```

---

## Project Structure

```
lib/
├── main.dart                    # Entry point, init Hive + SharedPrefs
├── app.dart                     # MaterialApp, routing, Material 3 theme
│
├── core/                        # Business logic (no Flutter UI imports)
│   ├── agent/                   # Agent loop, context builder, memory
│   ├── config/                  # AppConfig, ConfigStorage, CronConfig
│   ├── providers/               # LLM abstraction (Anthropic, HTTP, factory)
│   ├── session/                 # Conversation persistence (Hive)
│   ├── skills/                  # Three-tier loader and installer
│   └── tools/                   # Tool interface + 8 implementations
│
├── features/                    # Screens and platform features
│   ├── chat/                    # Main screen, message bubbles, history
│   ├── onboarding/              # First-launch setup
│   ├── settings/                # Provider, tools, skills, cron, Telegram
│   ├── telegram/                # Bot API, task handler, bot manager, rate limiter
│   └── voice/                   # Voice input (STT via Groq Whisper)
│
├── providers/                   # Riverpod state management
├── data/local/                  # Unified StorageService
└── shared/                      # Constants
```

**53 Dart files** in total.

---

## Dual Interface — Chat + Telegram

### Why Two Interfaces?

- **Flutter chat**: direct on-device interaction with Markdown rendering, real-time tool indicators, and session history
- **Telegram bot**: remote access from any device (PC, tablet, another phone), even when the Android phone is in a pocket or turned off. The user sends a message on Telegram, the phone processes it in the background and replies.

Both interfaces use the **same AgentLoop**. Telegram uses separate session keys (`telegram_<chat_id>`) so conversations don't mix. Other users (family, team) can also talk to the bot if the whitelist allows it.

### Why Telegram and Not WhatsApp?

Three concrete reasons:

1. **No public API**: WhatsApp Business API requires Meta verification, a hosted server, and webhook endpoints (HTTPS with a public IP). An Android phone behind NAT/4G cannot receive webhooks.

2. **Long polling doesn't exist**: WhatsApp has no equivalent to Telegram's `getUpdates`. It's webhook-only.

3. **Complexity vs. value**: WhatsApp Business Cloud API requires OAuth registration, webhook validation, message templates, and a server to receive callbacks. This negates the principle of a 100% on-device app.

Telegram won because: simple HTTP long polling (works behind any NAT), no server needed, open Bot API, free, and widely used.

---

## Android Constraints and Technical Choices

### No Server on Android

Android cannot reliably host an HTTP server:

- No fixed public IP (NAT, cellular networks, dynamic IPs)
- Android aggressively kills background processes
- Even foreground services have restrictions (Android 12+ limits, `dataSync` 6h cap on Android 15)

**Solution**: long polling (client-initiated HTTP requests) instead of webhooks (server-side). The phone asks Telegram "any new messages?" every 30 seconds — no inbound port, no server, works behind any NAT.

```
Webhook model (impossible):       Long polling model (DroidClaw):
Telegram -> phone:8443            Phone -> Telegram API
(blocked by NAT/firewall)         (works from anywhere)
```

### Foreground Service: `remoteMessaging` Not `dataSync`

- `dataSync` has a **6-hour execution limit per 24h** on Android 15+
- `remoteMessaging` has **no time limit** — designed for messaging apps
- The foreground service displays a persistent notification ("DroidClaw Bot - Active")
- The service survives backgrounding and app kill

---

## Key Technical Patterns

### Dual ToolResult (Pattern from the Go Codebase)

```dart
class ToolResult {
  final String forLLM;   // Context for the model (complete data)
  final String forUser;  // UI display (formatted, truncated)
}
```

The LLM receives the raw data it needs to reason. The user sees a clean, formatted version.

### Automatic Summarization

Triggered when: **20+ messages** OR **estimated tokens > 75% of maxTokens**.
Keeps the last 4 messages intact, summarizes the rest via an LLM call, prepends as system context.
Prevents context window overflow in long conversations.

### Sealed Event Stream

```dart
sealed class AgentEvent {}
class ThinkingEvent extends AgentEvent { ... }
class ToolCallEvent extends AgentEvent { ... }
class ToolResultEvent extends AgentEvent { ... }
class ResponseEvent extends AgentEvent { ... }
```

Both interfaces (chat UI and Telegram) consume the same `Stream<AgentEvent>`. The chat UI renders each event in real time. Telegram only sends the final `ResponseEvent`.

### Scheduled Prompts (Cron)

```dart
class CronDefinition {
  final String name;
  final String prompt;
  final CronSchedule schedule;      // interval or timeOfDay
  final SessionStrategy sessionStrategy; // newEach or sameThread
}
```

Users define recurring prompts from Settings > Scheduled Prompts. Each cron runs on its configured schedule (fixed interval with min 15 minutes, or specific times of day with optional day-of-week filtering). The agent processes the prompt like a normal user message, with full tool access.

---

## Tools

The agent has access to 8 tools. The LLM decides autonomously when to call each tool based on the conversation context. Each tool returns a `ToolResult.dual()` — full data for the LLM, clean summary for the user.

Users can **enable or disable** individual tools from Settings > Tools > Manage Tools.

| Tool | Name | Description |
|------|------|-------------|
| **Web Search** | `web_search` | Searches the web via the Brave Search API. Returns titles, URLs, and snippets. Requires a Brave API key configured in settings. |
| **Web Scrape** | `web_scrape` | Lightweight HTTP scraper. Fetches a page via HTTP GET, parses the HTML DOM with `package:html`, converts to structured Markdown via `html2md` (preserves headings, links, lists). Max 15K chars. Fast, low resources. If the result is empty, the page likely requires JavaScript. |
| **Web Scrape (JS)** | `web_scrape_js` | Heavy WebView scraper. Loads the page in a headless `flutter_inappwebview` that executes JavaScript, waits for rendering, then extracts the DOM and converts to Markdown. For SPAs, React/Vue apps, and dynamic sites. Images disabled, 30s timeout, WebView disposed after use. |
| **File** | `file` | Sandboxed file operations within the app workspace: `read_file`, `write_file`, `list_dir`. Path validation prevents directory traversal outside the sandbox. |
| **GPS Location** | `get_location` | Returns the device's current GPS coordinates (latitude, longitude, accuracy, altitude). Uses Android's `FusedLocationProviderClient` via the `geolocator` package, with automatic fallback from GPS to network location. Handles permission requests and service availability checks. |
| **Reverse Geocoding** | `get_address` | Converts GPS coordinates (latitude, longitude) into a human-readable street address using the Nominatim (OpenStreetMap) reverse geocoding API. Free, no API key required. The LLM chains this with `get_location`: first get GPS coords, then resolve to an address. |
| **Sub-agent** | `subagent` | Spawns a sub-task with a fresh session. The main agent delegates a focused task to a sub-agent, which processes it independently and returns the result. The sub-agent session is cleaned up after completion. |
| **Message** | `message` | Internal tool for sending messages directly to the user interface. Always enabled (not toggleable). Returns a silent result — the LLM sees no output, but the user sees the message. |

### Dual Scraping Strategy

The LLM is guided by the tool descriptions to use a two-step approach:
1. **Try `web_scrape` first** — fast, lightweight, works for most static sites
2. **Fall back to `web_scrape_js`** — only when `web_scrape` returns empty (JS-rendered SPA)

Both tools share a common `htmlToMarkdown()` utility that strips noise elements (`<nav>`, `<footer>`, `<aside>`, `<script>`, `<style>`) and produces clean Markdown with ATX headings and fenced code blocks.

### Tool Registration Flow

```
AppConfig.tools.disabledTools (persisted in SharedPreferences)
    ↓
toolRegistryProvider (rebuilds on config change)
    ↓ only registers enabled tools
ToolRegistry
    ↓
ContextBuilder (system prompt lists available tools)
AgentLoop (sends tool definitions to LLM, executes tool calls)
```

---

## Getting Started

### Prerequisites

- Flutter 3.38+
- Android SDK (API 24+)

### Build

```bash
flutter pub get
flutter analyze
flutter build apk --release --split-per-abi
```

### Install

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### First Launch

1. Onboarding: choose your LLM provider (OpenRouter, Anthropic, OpenAI, Groq, Gemini)
2. Enter the API key
3. Test the connection
4. Start chatting

### Configure Telegram (Optional)

1. Open Telegram and search for @BotFather
2. Send `/newbot` and follow the instructions
3. Copy the bot token
4. In DroidClaw: Settings -> Telegram Bot -> paste the token -> Test -> Enable

---

## Stats

| | |
|---|---|
| **Dart files** | 53 |
| **Analysis issues** | 0 |
| **APK size (arm64)** | 19.9 MB |
| **Native code** | None (pure Dart/Flutter) |
| **minSdkVersion** | 24 (Android 7.0) |
| **targetSdkVersion** | 34 (Android 14) |

## Why ARaccoon?

<p align="center">
  <img src="assets/ic_launcher_512.png" alt="ARaccoon — DroidClaw mascot" width="200">
</p>

DroidClaw is pronounced **"ARaccoon"** — The Raccoon. This is the name shown in the Android launcher and the project's mascot.

### The Raccoon as a Metaphor for the AI Agent

- **The claws**: raccoons are famous for their extremely dexterous front paws, capable of manipulating objects, picking locks, and rummaging everywhere. They are the perfect embodiment of **iterative tool calling** — the agent that calls web_search, parses the results, follows up with web_scrape, extracts the info, and loops until it finds the answer.

- **Intelligence and resourcefulness**: clever, adaptable, they always find a solution. Exactly what an AI agent does when it loops, fails, adjusts its strategy, and eventually solves the problem.

- **The nocturnal and discreet side**: active at night, a bit "bandit-like" (in the cute sense). This evokes the **off-grid** nature of the application — everything runs locally on the phone, no data is sent to a central server, total privacy.


