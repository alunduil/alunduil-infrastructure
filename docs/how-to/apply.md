<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Run an apply

Day-to-day `terraform plan`/`apply` against `terraform/alunduil/`, run
manually after merge to `main`. The shell environment (Terraform,
gcloud, pre-commit, REUSE) is prepared by chezmoi outside this repo.

```sh
cd terraform/alunduil
gcloud auth application-default login
export TF_VAR_cloudflare_api_token=...   # see reference/manual-operations.md
export GITHUB_TOKEN=...                  # scopes for repository administration

terraform init
terraform plan
terraform apply
```

The Cloudflare token's `TF_VAR_` form rather than `CLOUDFLARE_API_TOKEN`
works around an upstream bug in the v5 provider's import code path.
