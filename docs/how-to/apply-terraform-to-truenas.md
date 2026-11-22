<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Apply Terraform to TrueNAS

`just truenas` plans and applies `terraform/truenas/` against the TrueNAS API.
No workflow runs it, so a change there takes effect only when you run the
recipe. It authenticates with an API key (C-36) that you create in the
TrueNAS web UI and store in Secret Manager.

## Prerequisites

- A route to `192.168.68.63`, the address the provider connects to.
- `gcloud` authenticated with read access to the `truenas-api-key` secret,
  and application-default credentials for the state bucket.
- `just bootstrap` applied, so the secret exists.

## Create the key

The key carries its owner's privileges, and the recipe applies changes, so
create it under an administrator account.

1. Sign in to the TrueNAS web UI as that administrator.
2. Open the user menu in the top bar, then **API Keys**, and select **Add**.
3. Name it `terraform`, leave it without an expiry date, and save.
4. Copy the key from the dialog that follows.

## Store the key

Run `just bootstrap` and paste the key at its prompt. Input is hidden. To
store or rotate the key without the rest of the bootstrap:

```sh
TRUENAS_API_KEY=<key> scripts/configure-truenas-secrets.sh
```

A supplied key replaces the stored one. Revoke the old key in **API Keys**
after the next `just truenas` succeeds.

## Apply the configuration

```sh
just truenas
```

Terraform shows the plan and waits for `yes` before applying. A plan reporting
`No changes` with no error means the key authenticates and the configuration
matches TrueNAS. The plan doesn't read the Tailscale serve config back from the
box, so it misses an edit made there.

## Recover from a bad apply

If an apply cuts the tailnet path to TrueNAS, sign in to the web UI on the
home network at `https://192.168.68.63` and revert the change there. Revert it in
`terraform/truenas/` too, or the next `just truenas` reapplies it.

Disconnect Tailscale on the device you sign in from. A device that accepts
TrueNAS's subnet route sends that address through TrueNAS's own Tailscale node,
which is down.

If the `tailscale` app fails, the web UI's tailnet address fails with it.
Repair the app under **Apps** at the home-network address. The browser warns
about the certificate there, because TrueNAS's certificate doesn't name the IP.
