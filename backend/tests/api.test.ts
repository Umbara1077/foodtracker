import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import worker from "../src/index";
import type { Env } from "../src/types";
import { validateDraft, ValidationError } from "../src/validate";

class MemoryKV implements KVNamespace {
  private store = new Map<string, string>();

  async get(key: string, type?: "text" | "json" | "arrayBuffer" | "stream"): Promise<any> {
    const value = this.store.get(key) ?? null;
    if (value == null) return null;
    if (type === "json") return JSON.parse(value);
    return value;
  }

  async put(key: string, value: string): Promise<void> {
    this.store.set(key, value);
  }

  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  async list(): Promise<KVNamespaceListResult<unknown, string>> {
    return { keys: [], list_complete: true, cacheStatus: null };
  }

  getWithMetadata(): any {
    throw new Error("not implemented");
  }
}

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    PRIMARY_MODEL: "gpt-5.6-luna",
    ESCALATION_MODEL: "gpt-5.6-terra",
    FREE_DAILY_SCANS: "3",
    PROVIDER_MODE: "mock",
    SCAN_QUOTA: new MemoryKV() as unknown as KVNamespace,
    ...overrides,
  };
}

function tinyJpegBase64(): string {
  // Minimal valid-ish bytes; mock ignores pixels and keys off byte sum.
  return Buffer.from([0xff, 0xd8, 0xff, 0xd9, 1, 2, 3, 4]).toString("base64");
}

describe("validateDraft", () => {
  it("accepts a well-formed draft", () => {
    const draft = validateDraft({
      schema_version: 1,
      meal_name: "Test",
      overall_confidence: 0.9,
      items: [
        {
          display_name: "Rice",
          canonical_query: "white rice cooked",
          estimated_grams: 100,
          gram_range_low: 80,
          gram_range_high: 120,
          confidence: 0.8,
        },
      ],
    });
    expect(draft.items).toHaveLength(1);
    expect(draft.schema_version).toBe(1);
  });

  it("rejects inverted gram ranges", () => {
    expect(() =>
      validateDraft({
        schema_version: 1,
        meal_name: "Bad",
        overall_confidence: 0.5,
        items: [
          {
            display_name: "X",
            canonical_query: "x",
            estimated_grams: 100,
            gram_range_low: 150,
            gram_range_high: 50,
            confidence: 0.5,
          },
        ],
      }),
    ).toThrow(ValidationError);
  });
});

describe("worker routes", () => {
  it("health returns ok", async () => {
    const res = await worker.fetch(
      new Request("https://example.com/v1/health"),
      makeEnv(),
      {} as ExecutionContext,
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
  });

  it("config exposes model settings", async () => {
    const res = await worker.fetch(
      new Request("https://example.com/v1/config"),
      makeEnv(),
      {} as ExecutionContext,
    );
    const body = await res.json();
    expect(body.primary_model).toBe("gpt-5.6-luna");
    expect(body.free_daily_scans).toBe(3);
    expect(body.provider_mode).toBe("mock");
  });

  it("analyze returns validated mock draft and decrements quota", async () => {
    const env = makeEnv();
    const res = await worker.fetch(
      new Request("https://example.com/v1/meal/analyze", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-install-id": "test-install-001",
          "x-plate-schema-version": "1",
          "x-request-id": "req-1",
        },
        body: JSON.stringify({
          image_base64: tinyJpegBase64(),
          mime_type: "image/jpeg",
          locale: "en-US",
        }),
      }),
      env,
      {} as ExecutionContext,
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.request_id).toBe("req-1");
    expect(body.provider).toBe("mock");
    expect(body.draft.items.length).toBeGreaterThan(0);
    expect(body.quota.remaining).toBe(2);
    expect(body.quota.daily_limit).toBe(3);
  });

  it("enforces daily quota", async () => {
    const env = makeEnv({ FREE_DAILY_SCANS: "1" });
    const headers = {
      "content-type": "application/json",
      "x-install-id": "quota-user",
      "x-plate-schema-version": "1",
    };
    const body = JSON.stringify({ image_base64: tinyJpegBase64() });

    const first = await worker.fetch(
      new Request("https://example.com/v1/meal/analyze", { method: "POST", headers, body }),
      env,
      {} as ExecutionContext,
    );
    expect(first.status).toBe(200);

    const second = await worker.fetch(
      new Request("https://example.com/v1/meal/analyze", { method: "POST", headers, body }),
      env,
      {} as ExecutionContext,
    );
    expect(second.status).toBe(429);
    const err = await second.json();
    expect(err.error.code).toBe("quota_exceeded");
  });

  it("requires bearer token when APP_API_TOKEN is set", async () => {
    const env = makeEnv({ APP_API_TOKEN: "secret-token" });
    const res = await worker.fetch(
      new Request("https://example.com/v1/meal/analyze", {
        method: "POST",
        headers: { "content-type": "application/json", "x-install-id": "auth-user" },
        body: JSON.stringify({ image_base64: tinyJpegBase64() }),
      }),
      env,
      {} as ExecutionContext,
    );
    expect(res.status).toBe(401);
  });
});

// Keep package.json path stable for CI path checks.
describe("package metadata", () => {
  it("is version 0.5.0", () => {
    const pkg = JSON.parse(readFileSync(resolve(__dirname, "../package.json"), "utf8"));
    expect(pkg.version).toBe("0.5.0");
  });
});
