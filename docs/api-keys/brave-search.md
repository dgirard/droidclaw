# Brave Search API Key

Required for the `web_search` tool. The agent uses this to search the web and get real-time information.

## Get a Key

1. Go to [brave.com/search/api](https://brave.com/search/api/)
2. Click **Get Started**
3. Create an account or sign in
4. Subscribe to the **Free** plan (no credit card required)
5. Go to [api.search.brave.com/app/keys](https://api.search.brave.com/app/keys)
6. Copy the API key

## Pricing

- **Free**: 2,000 queries/month (1 query/second)
- **Base**: $5/month for 20,000 queries
- The free tier is sufficient for personal use

## Configure in DroidClaw

**Settings > Web Search** > paste the API key > Save

## Without This Key

The `web_search` tool will return an error asking the user to configure the key. The agent can still use `web_scrape` and `web_scrape_js` to fetch specific URLs directly, but cannot search the web.
