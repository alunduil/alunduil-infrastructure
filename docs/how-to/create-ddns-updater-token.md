<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the DDNS updater Cloudflare token

The credential the `ddns-updater` app on TrueNAS uses to write
`home.alunduil.com`'s A record. Operator-created and pasted straight
into the app — it never reaches Terraform or CI. For the app itself see
[configure-truenas-ddns-updater.md](configure-truenas-ddns-updater.md).

## Create

1. At <https://dash.cloudflare.com/profile/api-tokens> choose
   **Create Token** → **Create Custom Token**. Name it `ddns-updater`.
   Under **Permissions** add these rows:

   | Group | Permission | Access |
   | ----- | ---------- | ------ |
   | Zone  | Zone       | Read   |
   | Zone  | DNS        | Edit   |

   `Edit` rather than a narrower level: the app creates the record, not
   only updates it.

   Under **Zone Resources** set `Include` → `Specific zone` →
   `alunduil.com`.

   Leave **TTL** without an expiration date. An expired token stops
   updates silently: the stale A record keeps resolving until the home
   IP changes.
2. Copy the value — Cloudflare shows it once — and paste it into the
   app's **Token** field.

## Rotate

1. Create the replacement token.
2. Put it in the app config and save.
3. Confirm the app reports a successful update, then delete the old
   token in the dashboard.

The app holds the only copy, so deleting first leaves the record
unmaintained until the replacement is in place.
