# Project Plate API

Managed cloud AI gateway for meal photo analysis. OpenAI keys stay **server-side only**.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/v1/health` | Liveness |
| `GET` | `/v1/config` | Remote model / quota settings |
| `POST` | `/v1/meal/analyze` | Vision draft (no authoritative nutrition) |

## Auth & quota

- Optional `Authorization: Bearer <APP_API_TOKEN>` when the secret is configured.
- `X-Install-ID` identifies the anonymous install for daily free-scan quota (KV).
- `X-Plate-Schema-Version: 1` and `X-Request-ID` recommended.

## Provider modes

| `PROVIDER_MODE` | Behavior |
|-----------------|----------|
| `auto` (default) | OpenAI if `OPENAI_API_KEY` is set, else deterministic mock |
| `mock` | Always mock fixtures (CI / Simulator) |
| `openai` | Require OpenAI |

Photos are not stored. Request bodies are processed in memory and discarded.

## Local

```bash
cd backend
npm install
npm test
npx wrangler dev
```

Deploy (requires Cloudflare account):

```bash
npx wrangler kv namespace create SCAN_QUOTA
# update wrangler.jsonc ids, then:
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put APP_API_TOKEN   # optional
npx wrangler deploy
```
