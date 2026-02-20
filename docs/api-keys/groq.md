# Groq API Key

Groq provides extremely fast inference for open models (Llama, Mixtral, Gemma). Also powers DroidClaw's voice input (Whisper STT).

## Get a Key

1. Go to [console.groq.com](https://console.groq.com/)
2. Create an account (Google or email)
3. Go to **API Keys** ([console.groq.com/keys](https://console.groq.com/keys))
4. Click **Create API Key**
5. Copy the key (starts with `gsk_...`)

## Pricing

- **Free tier**: generous rate limits (30 req/min for most models)
- **Pay-as-you-go**: available for higher throughput
- See [groq.com/pricing](https://groq.com/pricing) for details

## Configure in DroidClaw

- **As LLM provider** (onboarding): select "Groq", paste the key, choose a model (e.g. `llama-4-maverick-17b-128e-instruct`)
- **For voice input**: the Groq key is also used for Whisper STT (speech-to-text). Configure the same key in Settings > Provider.

## Notes

- Groq is the fastest provider available, but models are limited to open-source (no Claude or GPT)
- Voice input uses Groq's Whisper endpoint for real-time speech transcription
