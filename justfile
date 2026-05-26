# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# All three steps are idempotent; safe to re-run after partial failure.
[doc("Manual surface: state bucket → bootstrap layer → CI secrets.")]
bootstrap:
    scripts/bootstrap-terraform-state.sh
    terraform -chdir=terraform/bootstrap init
    terraform -chdir=terraform/bootstrap apply
    scripts/configure-github-secrets.sh

# Requires TF_VAR_cloudflare_api_token in env (or terraform will prompt).
[doc("Local post-merge apply for the alunduil environment.")]
alunduil:
    terraform -chdir=terraform/alunduil init
    terraform -chdir=terraform/alunduil apply
