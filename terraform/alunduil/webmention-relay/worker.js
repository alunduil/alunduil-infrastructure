// SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
// SPDX-License-Identifier: MIT

const DISPATCH_URL =
  "https://api.github.com/repos/alunduil/blog.alunduil.com/dispatches";
const EVENT_TYPE = "webmention";

// The supplied secret arrives in the request body, so comparing it is the whole
// authentication step. Digesting both sides first hands timingSafeEqual the
// equal-length buffers it needs, which also keeps the stored secret's length
// out of the comparison.
async function secretMatches(supplied, expected) {
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(supplied)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);

  return crypto.subtle.timingSafeEqual(a, b);
}

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("method not allowed\n", { status: 405 });
    }

    // Terraform deploys the script before either secret is set by hand, so an
    // unconfigured relay is a reachable state rather than an impossible one.
    // Answering 503 keeps that window from reading as a rejected secret.
    if (!env.WEBMENTION_SECRET || !env.GITHUB_DISPATCH_TOKEN) {
      return new Response("relay not configured\n", { status: 503 });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response("expected a JSON body\n", { status: 400 });
    }

    if (
      typeof payload?.secret !== "string" || // pragma: allowlist secret
      !(await secretMatches(payload.secret, env.WEBMENTION_SECRET))
    ) {
      return new Response("forbidden\n", { status: 403 });
    }

    // No branch on the `post` and `deleted` payload shapes: a withdrawn mention
    // has to refresh the display for the same reason a new one does, and the
    // rebuild refetches the whole mention list either way.
    const dispatch = await fetch(DISPATCH_URL, {
      method: "POST",
      headers: {
        accept: "application/vnd.github+json",
        authorization: `Bearer ${env.GITHUB_DISPATCH_TOKEN}`,
        "content-type": "application/json",
        "user-agent": "webmention-relay",
      },
      body: JSON.stringify({ event_type: EVENT_TYPE }),
    });

    if (!dispatch.ok) {
      return new Response(`dispatch failed: ${dispatch.status}\n`, {
        status: 502,
      });
    }

    return new Response(null, { status: 204 });
  },
};
