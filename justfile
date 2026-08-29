# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# All three steps are idempotent; safe to re-run after partial failure.
# The bootstrap layer also needs the Grafana inputs — see
# docs/how-to/create-grafana-git-sync-token.md.
[doc("Manual surface: state bucket → bootstrap layer → CI secrets.")]
bootstrap:
    scripts/bootstrap-terraform-state.sh
    terraform -chdir=terraform/bootstrap init
    terraform -chdir=terraform/bootstrap apply
    scripts/configure-github-secrets.sh

# Requires gcloud credentials holding secretAccessor on the three secrets the
# plan/apply workflows read. Command substitution drops the PEM's trailing
# newline, which is also what the workflows' GITHUB_ENV heredoc yields, so the
# base64 the Grafana repository resource stores is the same either way.
[doc("Break-glass local apply for the alunduil environment.")]
alunduil:
    #!/usr/bin/env bash
    set -euo pipefail
    secret() { gcloud secrets versions access latest --secret="$1" --project=alunduil; }
    # Assign before exporting: export succeeds regardless, so folding the two
    # together hides a failed fetch from set -e and applies with no credentials.
    TF_VAR_cloudflare_api_token="$(secret cloudflare-api-token-deployer-rw)"
    TF_VAR_grafana_service_account_token="$(secret grafana-provisioner-token)"
    TF_VAR_grafana_git_sync_app_private_key="$(secret grafana-git-sync-app-private-key)"
    export TF_VAR_cloudflare_api_token TF_VAR_grafana_service_account_token
    export TF_VAR_grafana_git_sync_app_private_key
    terraform -chdir=terraform/alunduil init
    terraform -chdir=terraform/alunduil apply

[doc("Run bats unit tests for shell helpers.")]
test:
    bats github/projects/*.bats
