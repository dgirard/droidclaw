# PRIM / IDFM API Key (Ile-de-France Transit)

Required for the `get_transit` tool when routing trips within Ile-de-France. Provides higher precision and real-time data for the Paris region transit network.

## Get a Key

1. Go to [prim.iledefrance-mobilites.fr](https://prim.iledefrance-mobilites.fr/)
2. Click **Inscription** (Sign Up) or **Connexion** (Sign In)
3. Create an account (email + password)
4. Once logged in, go to **Mes API** (My APIs) or browse the API catalog
5. Find **Navitia - Calcul d'itineraire** (or "Idfm navitia general v2")
6. Subscribe to the API (free)
7. Go to your profile / subscriptions to find your API key

## Pricing

- **Free**: 1,000 requests/day
- No credit card required

## Configure in DroidClaw

**Settings > Routing & Transit** > PRIM / IDFM section > paste the API key > Save

You can test with the built-in test button (Gare de Lyon to Chatelet route).

## Coverage

All public transit in Ile-de-France (Paris region):
- **Metro**: lines 1-14
- **RER**: lines A, B, C, D, E
- **Tramway**: T1-T13
- **Bus**: RATP + Optile network
- **Transilien**: suburban rail (lines H, J, K, L, N, P, R, U)
- **Noctilien**: night buses

## Auto-Routing

DroidClaw automatically selects the best API for each trip:
- **Both origin and destination in IDF** --> uses PRIM (higher precision)
- **At least one point outside IDF** --> uses SNCF (national coverage)
- **Only PRIM key configured** --> IDF-only trips work, national trips return an error
- **Only SNCF key configured** --> all trips work (SNCF covers IDF too, just less precise)

The Ile-de-France bounding box: latitude 48.1-49.25, longitude 1.4-3.6.

## Notes

- The PRIM API uses Navitia technology (same response format as SNCF). Authentication is via the `apiKey` header.
- Coordinate format: `longitude;latitude` (semicolon separator, GeoJSON order)
