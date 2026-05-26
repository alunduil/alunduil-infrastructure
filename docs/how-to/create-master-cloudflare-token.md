<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Create the master Cloudflare token

Required scopes are in
[reference/credentials.md#master-cloudflare-token](../reference/credentials.md#master-cloudflare-token).

1. Create at <https://dash.cloudflare.com/profile/api-tokens> with the
   scopes above.
2. Export as `CLOUDFLARE_API_TOKEN` before bootstrap apply.
3. Revoke afterwards if you don't keep it around for rotation.
