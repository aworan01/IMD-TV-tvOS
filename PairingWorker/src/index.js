const json = (body, status = 200, origin = "*") => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json", "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,PUT,OPTIONS", "access-control-allow-headers": "content-type" }
});

const code = () => Array.from(crypto.getRandomValues(new Uint8Array(6)), n => "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[n % 32]).join("");

export default {
  async fetch(request, env) {
    const origin = env.ALLOWED_ORIGIN || "*";
    if (request.method === "OPTIONS") return json({}, 204, origin);
    const url = new URL(request.url);
    const match = url.pathname.match(/^\/pair(?:\/([A-Z2-9]{6}))?$/);
    if (!match) return json({ error: "not_found" }, 404, origin);

    if (request.method === "POST" && !match[1]) {
      const pairingCode = code();
      await env.PAIRINGS.put(pairingCode, JSON.stringify({ state: "waiting" }), { expirationTtl: 600 });
      return json({ code: pairingCode, expiresIn: 600 }, 201, origin);
    }

    const pairingCode = match[1];
    if (!pairingCode) return json({ error: "invalid_code" }, 400, origin);

    if (request.method === "PUT") {
      const existing = await env.PAIRINGS.get(pairingCode);
      if (!existing) return json({ error: "expired" }, 404, origin);
      const payload = await request.json();
      if (!["M3U Playlist", "Xtream Codes"].includes(payload.provider) || !payload.name)
        return json({ error: "invalid_payload" }, 422, origin);
      await env.PAIRINGS.put(pairingCode, JSON.stringify({ state: "ready", payload }), { expirationTtl: 600 });
      return json({ accepted: true }, 200, origin);
    }

    if (request.method === "GET") {
      const raw = await env.PAIRINGS.get(pairingCode);
      if (!raw) return json({ error: "expired" }, 404, origin);
      const value = JSON.parse(raw);
      if (value.state !== "ready") return new Response(null, { status: 204, headers: { "access-control-allow-origin": origin } });
      await env.PAIRINGS.delete(pairingCode);
      return json(value.payload, 200, origin);
    }
    return json({ error: "method_not_allowed" }, 405, origin);
  }
};

