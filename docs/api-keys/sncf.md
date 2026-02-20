# SNCF API Key (National Trains)

Required for the `get_transit` tool when routing trips outside Ile-de-France (TGV, TER, Intercites). Also works as a fallback for IDF trips if no PRIM key is configured.

## Get a Key

1. Go to [numerique.sncf.com/startup/api](https://numerique.sncf.com/startup/api/)
2. Click **S'inscrire** (Sign Up) or **Se connecter** (Sign In)
3. Create an account (email + password)
4. Once logged in, go to your dashboard
5. Find the **Navitia / Calcul d'itineraires** API
6. Subscribe to the free plan
7. Copy your API token

Alternative direct link: [ressources.data.sncf.com](https://ressources.data.sncf.com/)

## Pricing

- **Free**: 5,000 requests/day
- No credit card required

## Configure in DroidClaw

**Settings > Routing & Transit** > SNCF section > paste the API key > Save

You can test with the built-in test button (Paris to Lyon route).

## Coverage

National rail network across all of France:
- **TGV**: high-speed trains (Paris-Lyon, Paris-Marseille, etc.)
- **TER**: regional trains
- **Intercites**: long-distance conventional trains
- **Transilien**: suburban trains (Paris region, as fallback)

## Notes

- The SNCF API uses Navitia technology. Authentication is via the `Authorization` header with the token directly (not Basic Auth).
- Coordinate format: `longitude;latitude` (semicolon separator, GeoJSON order)
- The API also covers IDF transit (Metro, RER, Bus) but with less precision than the dedicated PRIM API
