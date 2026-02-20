# OpenRouteService API Key

Required for the `get_directions` tool. Provides route calculation (car, bike, walk) with turn-by-turn instructions and isochrone analysis.

## Get a Key

1. Go to [openrouteservice.org](https://openrouteservice.org/)
2. Click **Sign Up** (top right)
3. Create an account (email + password)
4. Confirm your email
5. Go to [openrouteservice.org/dev/#/home](https://openrouteservice.org/dev/#/home)
6. Click **Request a token** (or the "+" button)
7. Give it a name (e.g. "DroidClaw"), select **Free** plan
8. Copy the API key

## Pricing

- **Free**: 2,000 directions requests/day, 500 isochrone requests/day
- No credit card required
- More than enough for personal use

## Configure in DroidClaw

**Settings > Routing & Transit** > paste the ORS API key > Save

You can test with the built-in test button (Paris to Versailles route).

## Without This Key

The `get_directions` tool will return an error asking the user to configure the key. The agent can still use `get_transit` for public transit routes (separate API keys).
