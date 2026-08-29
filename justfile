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
    # The bare assignment carries the fetch's exit status, so a denied secret
    # aborts here; assigning through export would report export's own success
    # and leave terraform to apply with an empty credential.
    export_secret() {
        local value
        value="$(gcloud secrets versions access latest --secret="$2" --project=alunduil)"
        export "$1=${value}"
    }
    export_secret TF_VAR_cloudflare_api_token cloudflare-api-token-deployer-rw
    export_secret TF_VAR_grafana_service_account_token grafana-provisioner-token
    export_secret TF_VAR_grafana_git_sync_app_private_key grafana-git-sync-app-private-key
    terraform -chdir=terraform/alunduil init
    terraform -chdir=terraform/alunduil apply

[doc("Run bats unit tests for shell helpers.")]
test:
    bats github/projects/*.bats
