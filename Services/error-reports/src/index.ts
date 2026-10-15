// Takes the app's error reports and stores them in D1. The app groups repeats and sends at most
// every six hours, so each install costs a request or so a day. No IP address is stored.

interface Env {
  DB: D1Database;
  LIMITER: RateLimit;
}

const MAX_BODY = 64 * 1024;
const MAX_ITEMS = 50;
const KEEP_DAYS = 30;
const PLATFORMS = new Set(["macos", "ios", "tvos"]);

const text = (value: unknown, max: number) => (typeof value === "string" ? value.slice(0, max) : "");
const whole = (value: unknown, max: number) =>
  typeof value === "number" && Number.isFinite(value) ? Math.min(Math.max(Math.trunc(value), 0), max) : 0;

// One bug, many messages: ids, offsets, sizes and durations differ between occurrences. Status and
// error codes stay, so an HTTP 403 and a 500, or a timeout (-1001) and no network (-1009), stay apart.
// The same rules as `groupKey` in Sources/TVCore/ErrorReports.swift: keep them in step.
export function normalize(message: string) {
  return message
    .split("\n")[0]
    .replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, "<id>")
    .replace(/\b[0-9a-f]{12,}\b/gi, "<id>")
    .replace(/\b(offset|at|bytes|duration|length|chunk|aid|cid|room|id|page|elapsed|total|size|seconds)=-?[0-9.]+/g, "$1=#")
    .replace(/\b\d+(?:\.\d+)? ?(?:seconds|sec|ms|s)\b/g, "#s")
    .replace(/(?<![\w.-])\d{5,}\b/g, "#")
    .trim();
}

async function signature(category: string, message: string) {
  const data = new TextEncoder().encode(category + "\n" + normalize(message));
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  return [...digest.slice(0, 6)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function receive(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get("cf-connecting-ip") ?? "";
  if (!(await env.LIMITER.limit({ key: ip })).success) return new Response(null, { status: 429 });
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY) return new Response(null, { status: 413 });
  const raw = await request.text();
  if (raw.length > MAX_BODY) return new Response(null, { status: 413 });
  let body: any;
  try {
    body = JSON.parse(raw);
  } catch {
    return new Response(null, { status: 400 });
  }
  const install = text(body?.install, 36);
  const platform = text(body?.platform, 8);
  const items: any[] = Array.isArray(body?.items) ? body.items.slice(0, MAX_ITEMS) : [];
  if (!/^[0-9A-Fa-f-]{36}$/.test(install) || !PLATFORMS.has(platform) || items.length === 0) {
    return new Response(null, { status: 400 });
  }
  const now = Math.floor(Date.now() / 1000);
  const country = text((request as any).cf?.country, 2) || "XX";
  const insert = env.DB.prepare(
    `INSERT INTO reports (received, install, platform, os, model, lang, app, build, country, signature, category, message, count, first, last)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const rows = [];
  for (const item of items) {
    const category = text(item?.category, 80);
    const message = text(item?.message, 1000);
    if (!category || !message) continue;
    rows.push(
      insert.bind(
        now, install, platform, text(body.os, 24), text(body.model, 32), text(body.lang, 16), text(body.app, 16), text(body.build, 16), country,
        await signature(category, message), category, message,
        Math.max(whole(item.count, 1_000_000), 1), whole(item.first, now), whole(item.last, now),
      ),
    );
  }
  if (rows.length) await env.DB.batch(rows);
  return new Response(null, { status: 204 });
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname !== "/v1/reports") return new Response(null, { status: 404 });
    if (request.method !== "POST") return new Response(null, { status: 405, headers: { allow: "POST" } });
    return receive(request, env);
  },
  async scheduled(_controller, env) {
    await env.DB.prepare("DELETE FROM reports WHERE received < ?").bind(Math.floor(Date.now() / 1000) - KEEP_DAYS * 86400).run();
  },
} satisfies ExportedHandler<Env>;
