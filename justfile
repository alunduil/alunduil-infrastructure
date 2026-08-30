# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Every step is idempotent; safe to re-run after partial failure. The bootstrap
# layer still needs the master Grafana and Cloudflare tokens on every run — see
# docs/how-to/bootstrap.md.
[doc("Manual surface: state bucket → bootstrap layer → App credentials → CI secrets.")]
bootstrap:
    scripts/bootstrap-terraform-state.sh
    terraform -chdir=terraform/bootstrap init
    terraform -chdir=terraform/bootstrap apply
    scripts/configure-git-sync-secrets.sh
    scripts/configure-github-secrets.sh

# Credentials: gcloud CLI auth with secretAccessor for the secret fetches,
# gcloud application-default for the google provider and GCS backend, and an
# authenticated gh for the github provider. Command substitution strips the
# PEM's trailing newline, as the plan/apply workflows' GITHUB_ENV heredoc does.
# Restoring it would leave local and CI applies flipping the base64 that
# grafana.tf encodes.
[doc("Break-glass local apply for the alunduil environment.")]
alunduil:
    #!/usr/bin/env bash
    set -euo pipefail
    # Every credential below is assigned before being exported: folded into one
    # statement, export's own success becomes the exit status and a failed fetch
    # reaches terraform as an empty value.
    export_secret() {
        local value
        value="$(gcloud secrets versions access latest --secret="$2" --project=alunduil)"
        export "$1=${value}"
    }
    export_secret TF_VAR_cloudflare_api_token cloudflare-api-token-deployer-rw
    export_secret TF_VAR_grafana_service_account_token grafana-provisioner-token
    export_secret TF_VAR_grafana_git_sync_app_private_key grafana-git-sync-app-private-key
    export_secret TF_VAR_grafana_git_sync_app_id grafana-git-sync-app-id
    export_secret TF_VAR_grafana_git_sync_app_installation_id grafana-git-sync-app-installation-id
    # The github provider reads GITHUB_TOKEN. CI injects a deployer App token;
    # break-glass runs under the operator's identity.
    GITHUB_TOKEN="$(gh auth token)"
    export GITHUB_TOKEN
    terraform -chdir=terraform/alunduil init
    terraform -chdir=terraform/alunduil apply

[doc("Run bats unit tests for shell helpers.")]
test:
    bats github/projects/*.bats
