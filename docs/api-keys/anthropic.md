# Anthropic API Key

Direct access to Claude models (Haiku, Sonnet, Opus) without going through OpenRouter.

## Get a Key

1. Go to [console.anthropic.com](https://console.anthropic.com/)
2. Create an account (email + phone verification)
3. Go to **Settings > API Keys**
4. Click **Create Key**
5. Copy the key (starts with `sk-ant-...`)

## Pricing

- **Free trial**: $5 credit on signup (valid 30 days)
- **Pay-as-you-go**: add credit via billing settings
- See [anthropic.com/pricing](https://www.anthropic.com/pricing) for per-model rates

## Configure in DroidClaw

- **Onboarding**: select "Anthropic" as provider, paste the key
- **Settings > Provider**: change key later

## Notes

- DroidClaw uses the Anthropic-native API format (not OpenAI-compatible), with the `x-api-key` header and `anthropic-version: 2023-06-01`
- Supports Claude 3.5 Haiku, Claude 4 Sonnet, Claude 4 Opus
