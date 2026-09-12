<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the DDNS updater Cloudflare token

The credential the `ddns-updater` app on TrueNAS uses to write
`home.alunduil.com`'s A record. Operator-created and pasted straight
into the app — it never reaches Terraform or CI, which is why
`home.alunduil.com` is absent from `terraform/alunduil/dns.tf`. For the
app itself see
[configure-truenas-ddns-updater.md](configure-truenas-ddns-updater.md).

## Create

1. At <https://dash.cloudflare.com/profile/api-tokens> choose
   **Create Token** → **Create Custom Token**. Name it `ddns-updater`.
   Under **Permissions** add these rows:

   | Group | Permission | Access |
   | ----- | ---------- | ------ |
   | Zone  | Zone       | Read   |
   | Zone  | DNS        | Edit   |

   `DNS:Edit` covers creating the record as well as updating it; the
   app creates `home.alunduil.com` when it's missing.

   Under **Zone Resources** set `Include` → `Specific zone` →
   `alunduil.com`.

   Leave **TTL** without an expiration date. The app runs unattended,
   and an expired token stops DNS updates without an alert — the stale
   A record keeps resolving until the home IP changes.
2. Copy the value. Cloudflare shows it once.
3. Paste it into the app's **Token** field, following
   [configure-truenas-ddns-updater.md](configure-truenas-ddns-updater.md).

## Rotate

Create the replacement first, put it in the app config, save, and
confirm the app reports a successful update. Then delete the old token
in the dashboard. The app holds the only copy, so deleting first leaves
the record unmaintained until the new token is in place.
