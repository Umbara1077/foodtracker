# Foodtracker

Plain-language meal logging on **Cloudflare Workers + React + Hono + D1**, bootstrapped from the official [`vite-react-template`](https://github.com/cloudflare/templates/tree/main/vite-react-template).

Type what you ate → estimate macros from a local food library → save to D1 → see today’s calorie ring and macros.

## Develop

```bash
npm install
npx wrangler d1 migrations apply foodtracker --local
npm run dev
```

App: [http://localhost:5173](http://localhost:5173)

## Deploy

1. Create a D1 database and put its id in `wrangler.json` (`d1_databases[0].database_id`).
2. Apply migrations remotely: `npx wrangler d1 migrations apply foodtracker --remote`
3. Deploy: `npm run build && npm run deploy`

Requires `CLOUDFLARE_API_TOKEN` (and optionally `CLOUDFLARE_ACCOUNT_ID`).

## API

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Health check |
| GET | `/api/goals` | Daily macro goals |
| PUT | `/api/goals` | Update goals |
| GET | `/api/meals?date=YYYY-MM-DD` | Meals + totals for a day |
| POST | `/api/estimate` | Estimate macros from text |
| POST | `/api/meals` | Log a meal |
| DELETE | `/api/meals/:id` | Remove a meal |
