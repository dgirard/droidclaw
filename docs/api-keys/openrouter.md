# OpenRouter API Key

OpenRouter gives access to 200+ models (Claude, GPT, Gemini, Llama, Mistral, etc.) through a single API key. This is the recommended provider for DroidClaw.

## Get a Key

1. Go to [openrouter.ai](https://openrouter.ai/)
2. Click **Sign Up** (Google, GitHub, or email)
3. Go to [openrouter.ai/keys](https://openrouter.ai/keys)
4. Click **Create Key**
5. Copy the key (starts with `sk-or-v1-...`)

## Pricing

- **Free tier**: some models are free (marked `free` in the model list)
- **Pay-as-you-go**: add credit via the [Credits page](https://openrouter.ai/credits). $5 is enough for weeks of normal use.
- No monthly subscription required

## Configure in DroidClaw

- **Onboarding**: select "OpenRouter" as provider, paste the key
- **Settings > Provider**: change key or switch provider later

## Recommended Models

| Model | Speed | Quality | Cost |
|-------|-------|---------|------|
| `anthropic/claude-sonnet-4-20250514` | Fast | Excellent | ~$3/$15 per 1M tokens |
| `google/gemini-2.0-flash-001` | Very fast | Good | ~$0.10/$0.40 per 1M tokens |
| `meta-llama/llama-4-maverick` | Fast | Good | Free on some providers |

The default model is `anthropic/claude-sonnet-4-20250514`.
