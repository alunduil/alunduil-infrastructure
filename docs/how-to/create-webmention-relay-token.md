<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the webmention relay deploy token

blog.alunduil.com deploys a Cloudflare Worker that turns webmention.io's
callback into a rebuild of the blog. The Worker, its configuration, and
the workflow that deploys it all live in that repository; this token is
the only part of the arrangement that comes from the Cloudflare account.

The deployer tokens in `terraform/bootstrap/cloudflare_tokens.tf` can't
do this job. Every Workers permission is account-wide — there's no
zone-scoped form — so granting one to a token that exists to manage
alunduil.com's DNS would let any Terraform run overwrite every Worker on
the account. Same call as
[create-web-analytics-site.md](create-web-analytics-site.md): create a
separate credential by hand rather than widen a narrow one.

1. At <https://dash.cloudflare.com/profile/api-tokens> choose
   **Create Token**. Under the token templates pick **Edit Cloudflare
   Workers** — Cloudflare's documented template for deploying with
   Wrangler, which is what the blog's workflow runs.
2. Under **Account Resources** set `Include` → the alunduil account.
   Under **Zone Resources** set `Include` → `Specific zone` →
   `alunduil.com`, so the token reaches no other zone when it attaches
   the Worker's hostname.
3. Leave **TTL** open-ended. Unlike the master token, this one is
   long-lived by design — the blog redeploys the Worker whenever its
   source changes, so an expiry would break deploys rather than contain
   a leak.
4. Copy the value and store it as the `CLOUDFLARE_API_TOKEN` repository
   secret on blog.alunduil.com:

   ```sh
   gh secret set CLOUDFLARE_API_TOKEN --repo alunduil/blog.alunduil.com
   ```

   Cloudflare shows the value once. Replacing it means creating a new
   token and rerunning the command.

The token grants Worker deploys across the whole account, so treat a
suspected leak as account-wide: revoke it at the dashboard first, then
create its replacement.

## What this token doesn't cover

The Worker's own secrets — the GitHub token it dispatches with, and the
shared secret webmention.io signs callbacks with — are set on the Worker
itself, not here. blog.alunduil.com documents those alongside the
Worker.

`webmention.alunduil.com` has no record in
`terraform/alunduil/dns.tf`. Attaching the Worker's custom domain
creates the record and its certificate, the same way the TrueNAS DDNS
client owns `home.alunduil.com`. Adding a `cloudflare_dns_record` for it
would fight the blog's deploy on every plan.
