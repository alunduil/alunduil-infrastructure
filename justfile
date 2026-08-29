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

# Requires gcloud credentials with secretAccessor on these secrets, the same
# ones the plan/apply workflows read. Command substitution strips the PEM's
# trailing newline, as their GITHUB_ENV heredoc does. Restoring it would leave
# local and CI applies flipping the base64 grafana.tf stores.
[doc("Break-glass local apply for the alunduil environment.")]
alunduil:
    #!/usr/bin/env bash
    set -euo pipefail
    # Assign before exporting: folded together, a denied fetch returns export's
    # own success and terraform applies with an empty credential.
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
