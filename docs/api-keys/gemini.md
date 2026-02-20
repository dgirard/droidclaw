# Google Gemini API Key

Access to Google's Gemini models (Gemini 2.0 Flash, Gemini 2.5 Pro, etc.).

## Get a Key

1. Go to [aistudio.google.com](https://aistudio.google.com/)
2. Sign in with your Google account
3. Click **Get API Key** in the left sidebar
4. Click **Create API key** and select a project (or create one)
5. Copy the key (starts with `AIza...`)

## Pricing

- **Free tier**: 15 requests/minute for Gemini Flash, 2 req/min for Gemini Pro
- **Pay-as-you-go**: enable billing in Google Cloud for higher limits
- See [ai.google.dev/pricing](https://ai.google.dev/pricing) for details

## Configure in DroidClaw

- **Onboarding**: select "Gemini" as provider, paste the key
- **Settings > Provider**: change key later

## Notes

- DroidClaw accesses Gemini via the OpenAI-compatible endpoint (`generativelanguage.googleapis.com/v1beta/openai`)
- Tool results must include the `name` field (Gemini returns 400 without it) -- DroidClaw handles this automatically
