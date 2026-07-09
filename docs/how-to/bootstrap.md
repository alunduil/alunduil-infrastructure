<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Run the first-time bootstrap

Stands up CI authentication (Workload Identity Federation, deployer
service accounts, Cloudflare deployer tokens) and populates the GitHub
Actions secrets. Run when starting from scratch or rotating the core
credentials.

## Prerequisites

- A master Cloudflare API token — see
  [create-master-cloudflare-token.md](create-master-cloudflare-token.md).
- A GitHub App created and installed — see
  [create-github-app.md](create-github-app.md).

## Run

```sh
gcloud auth application-default login
export TF_VAR_billing_account_id=XXXXXX-XXXXXX-XXXXXX
export CLOUDFLARE_API_TOKEN=...

just bootstrap
```

## Stays manual

CI runs the routine `terraform apply` on merge to `main`. These steps
sit outside that automation and the operator owns them:

- **Bootstrap apply.** The `just bootstrap` run above — state bucket,
  bootstrap layer, then `scripts/configure-github-secrets.sh`. One
  time, or when rotating credentials.
- **Token creation and rotation.** The master Cloudflare token
  ([create-master-cloudflare-token.md](create-master-cloudflare-token.md))
  and the GitHub App ([create-github-app.md](create-github-app.md));
  re-run `just bootstrap` to refresh the derived deployer credentials.
- **Branch protection.** Require the `pre-commit` and `terraform-plan`
  status checks on `main` in the repository's branch-protection
  settings. Kept as click-ops, not Terraform-managed.
- **`develop` → `main` renames.** Terraform can't safely rename an
  existing default branch. Use GitHub's "Rename branch" so PR refs and
  forks are preserved, then let `github_branch_default` lock `main` in.
