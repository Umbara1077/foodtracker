import { mockAnalyze } from "./mockProvider";
import { openAIAnalyze } from "./openaiProvider";
import { consumeScan, remainingScans } from "./quota";
import type { AnalyzeRequestBody, AnalyzeResponseBody, Env, RemoteConfigResponse } from "./types";
import { validateDraft, ValidationError } from "./validate";

const MAX_IMAGE_BYTES = 2_500_000;

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function error(status: number, code: string, message: string): Response {
  return json({ error: { code, message } }, status);
}

function requireAuth(request: Request, env: Env): Response | null {
  if (!env.APP_API_TOKEN) return null;
  const header = request.headers.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match || match[1] !== env.APP_API_TOKEN) {
    return error(401, "unauthorized", "Valid app token required.");
  }
  return null;
}

function installId(request: Request): string {
  const raw = request.headers.get("x-install-id")?.trim();
  if (raw && raw.length >= 8 && raw.length <= 80) return raw;
  return "anonymous";
}

function decodeImage(body: AnalyzeRequestBody): Uint8Array {
  if (!body.image_base64 || typeof body.image_base64 !== "string") {
    throw new ValidationError("image_base64 required");
  }
  const cleaned = body.image_base64.replace(/^data:[^;]+;base64,/, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  if (bytes.length === 0) throw new ValidationError("empty image");
  if (bytes.length > MAX_IMAGE_BYTES) throw new ValidationError("image too large");
  return bytes;
}

function resolveProviderMode(env: Env): "mock" | "openai" {
  const mode = (env.PROVIDER_MODE || "auto").toLowerCase();
  if (mode === "mock") return "mock";
  if (mode === "openai") return "openai";
  return env.OPENAI_API_KEY ? "openai" : "mock";
}

async function handleAnalyze(request: Request, env: Env): Promise<Response> {
  const authError = requireAuth(request, env);
  if (authError) return authError;

  const requestId = request.headers.get("x-request-id") || crypto.randomUUID();
  const schemaHeader = request.headers.get("x-plate-schema-version");
  if (schemaHeader && schemaHeader !== "1") {
    return error(400, "unsupported_schema", "X-Plate-Schema-Version must be 1");
  }

  const id = installId(request);
  const quotaBefore = await remainingScans(env, id);
  if (quotaBefore.remaining <= 0) {
    return error(429, "quota_exceeded", "Daily free cloud scans are used up.");
  }

  let body: AnalyzeRequestBody;
  try {
    body = (await request.json()) as AnalyzeRequestBody;
  } catch {
    return error(400, "invalid_json", "Request body must be JSON.");
  }

  let imageBytes: Uint8Array;
  try {
    imageBytes = decodeImage(body);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Invalid image";
    return error(400, "invalid_image", message);
  }

  const mimeType = body.mime_type || "image/jpeg";
  const locale = body.locale || "en-US";
  const mealHint = body.meal_hint ?? null;
  const providerMode = resolveProviderMode(env);
  const started = Date.now();

  try {
    let draft;
    let model: string;
    let provider: string;

    if (providerMode === "openai") {
      const result = await openAIAnalyze(
        env,
        body.image_base64.replace(/^data:[^;]+;base64,/, ""),
        mimeType,
        locale,
        mealHint,
      );
      draft = result.draft;
      model = result.model;
      provider = "openai";
    } else {
      draft = mockAnalyze(imageBytes);
      model = "mock-fixture";
      provider = "mock";
    }

    // Defense in depth — never return unvalidated drafts.
    draft = validateDraft(draft);
    const quota = await consumeScan(env, id);

    const response: AnalyzeResponseBody = {
      request_id: requestId,
      provider,
      model,
      latency_ms: Date.now() - started,
      draft,
      quota: { remaining: quota.remaining, daily_limit: quota.dailyLimit },
    };
    return json(response);
  } catch (err) {
    if (err instanceof ValidationError) {
      return error(422, "invalid_structured_response", err.message);
    }
    console.error("analyze failed", err);
    return error(502, "provider_unavailable", "Meal analysis isn’t available right now.");
  }
}

function handleConfig(env: Env): Response {
  const payload: RemoteConfigResponse = {
    schema_version: 1,
    primary_model: env.PRIMARY_MODEL || "gpt-5.6-luna",
    escalation_model: env.ESCALATION_MODEL || "gpt-5.6-terra",
    free_daily_scans: Number(env.FREE_DAILY_SCANS || "5") || 5,
    provider_mode: resolveProviderMode(env),
    max_image_bytes: MAX_IMAGE_BYTES,
  };
  return json(payload);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/v1/health") {
      return json({
        ok: true,
        provider_mode: resolveProviderMode(env),
        service: "project-plate-api",
      });
    }

    if (request.method === "GET" && url.pathname === "/v1/config") {
      return handleConfig(env);
    }

    if (request.method === "POST" && url.pathname === "/v1/meal/analyze") {
      return handleAnalyze(request, env);
    }

    return error(404, "not_found", "Unknown route");
  },
} satisfies ExportedHandler<Env>;
