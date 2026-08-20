import type { Env } from "./types";

function dayKey(d = new Date()): string {
  return d.toISOString().slice(0, 10);
}

export async function remainingScans(
  env: Env,
  installId: string,
): Promise<{ remaining: number; dailyLimit: number; used: number }> {
  const dailyLimit = Math.max(0, Number(env.FREE_DAILY_SCANS || "5") || 5);
  const key = `install:${installId}:day:${dayKey()}`;
  const usedRaw = await env.SCAN_QUOTA.get(key);
  const used = Math.max(0, Number(usedRaw || "0") || 0);
  return { remaining: Math.max(0, dailyLimit - used), dailyLimit, used };
}

export async function consumeScan(
  env: Env,
  installId: string,
): Promise<{ remaining: number; dailyLimit: number }> {
  const { remaining, dailyLimit, used } = await remainingScans(env, installId);
  if (remaining <= 0) {
    return { remaining: 0, dailyLimit };
  }
  const key = `install:${installId}:day:${dayKey()}`;
  await env.SCAN_QUOTA.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
  return { remaining: remaining - 1, dailyLimit };
}
