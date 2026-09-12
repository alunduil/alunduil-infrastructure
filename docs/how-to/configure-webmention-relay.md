<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Configure the webmention relay

`terraform/alunduil/webmention-relay.tf` deploys the Worker at
<https://webmention.alunduil.com> and attaches its domain, but leaves
both of its secrets unset. The Worker answers `503` until you finish the
three steps below, so run them once after the first apply.

Holding the secrets outside Terraform keeps them out of this layer's
state, which both deployer service accounts can read from the
`alunduil-tfstate` bucket. `keep_bindings` preserves them across every
later apply, so this is a one-time setup rather than something to redo
after each deploy.

## Create the GitHub token

The relay needs to POST a `repository_dispatch` to
blog.alunduil.com and nothing else.

1. At <https://github.com/settings/personal-access-tokens/new> create a
   fine-grained token. Name it `webmention-relay`.
2. Under **Repository access** choose **Only select repositories** and
   pick `blog.alunduil.com`.
3. Under **Repository permissions** set **Contents** to
   **Read and write**. That's the permission `POST /dispatches`
   checks; no other permission is needed.
4. Set an expiration you'll act on — the relay stops rebuilding the blog
   silently when the token lapses, since webmention.io doesn't surface
   the relay's response.
5. Copy the value. GitHub shows it once.

## Set the Worker secrets

Pick any long random string for the shared secret, for example
`openssl rand -hex 32`. Keep it to hand — webmention.io needs the same
value in the next section.

At <https://dash.cloudflare.com> open **Compute (Workers)** →
**webmention-relay** → **Settings** → **Variables and Secrets**. Add two,
each with type **Secret**:

| Name                     | Value                        |
| ------------------------ | ---------------------------- |
| `GITHUB_DISPATCH_TOKEN`  | the fine-grained token above |
| `WEBMENTION_SECRET`      | the random string            |

Deploy the change. The Worker reads both names verbatim, so a typo
leaves it answering `503`.

## Point webmention.io at the relay

At <https://webmention.io/settings> set the webhook to:

- **Callback URL**: `https://webmention.alunduil.com`
- **Secret**: the same random string

Confirm the wiring with a request that should be refused:

```sh
curl -i -X POST https://webmention.alunduil.com \
  -H 'content-type: application/json' \
  -d '{"secret":"wrong"}' # pragma: allowlist secret
```

`403` means the Worker is deployed and reading `WEBMENTION_SECRET`.
`503` means one of the two secrets is missing or misnamed. Repeating it
with the real secret returns `204` and starts a blog build, visible
under blog.alunduil.com's Actions tab.

## Rotate a secret

Replace the value in the Cloudflare dashboard, then replace its
counterpart: the GitHub token has none, and the shared secret has to
change at webmention.io in the same sitting. Terraform needs no run
either way.
