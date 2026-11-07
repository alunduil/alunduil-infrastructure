<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Set the ACME token on TrueNAS

TrueNAS renews its web UI certificate, `truenas.alunduil.com`, through a
DNS-01 challenge on Cloudflare. Terraform creates the Cloudflare token (C-35)
and stores it in Secret Manager. You put it in TrueNAS's ACME DNS
authenticator by hand, because nothing here configures TrueNAS.

Run this after the first `just bootstrap` that creates the token, and after
any bootstrap re-run that replaces it.

## Prerequisites

- `just bootstrap` applied, so the secret holds a version.
- `gcloud` available, authenticated as an identity that can read the
  `cloudflare-api-token-truenas-acme` secret. The deployer service accounts
  can't read it.

## Read the token

```sh
gcloud secrets versions access latest \
  --secret=cloudflare-api-token-truenas-acme --project=alunduil
```

## Set it in the authenticator

In the TrueNAS web UI, open **Credentials → Certificates**. Under **ACME DNS
Authenticators**, edit the Cloudflare authenticator, paste the token into
**API Token**, and save. Leave **Cloudflare Email** and **API Key** empty: they
belong to Cloudflare's global key, which this token replaces.

## Renew the certificate

TrueNAS's daily `certificate.renew_certs` job picks up the new token. To renew
now, run this from a TrueNAS shell:

```sh
midclt call -job certificate.renew_certs
```

## Confirm it worked

```sh
openssl s_client -connect truenas.alunduil.com:443 \
  -servername truenas.alunduil.com </dev/null 2>/dev/null \
  | openssl x509 -noout -enddate
```

A `notAfter` date in the future confirms the renewal and that the web UI
serves the new certificate. `Invalid access token` in the job's error means
TrueNAS still holds the old token.
