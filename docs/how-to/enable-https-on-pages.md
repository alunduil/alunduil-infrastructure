<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Enable HTTPS on a GitHub Pages site

GitHub provisions the certificate on its own once the apex CNAME
resolves; the toggle is set after that.

1. Wait for the CNAME to resolve and GitHub to provision a Let's
   Encrypt cert (usually minutes after the DNS record lands).
2. In the repo's "Settings → Pages", tick "Enforce HTTPS".

Once the cert is ready, `https_enforced = true` on the
`github_repository_pages` resource keeps the toggle locked in.
