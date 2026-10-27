# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The DORA and SPACE dashboards in docs/reference/delivery-metrics.md query
# GitHub live through this data source. A GitHub App installation has its own
# rate limit, so dashboard refreshes stay off the account's shared GraphQL
# budget. terraform/bootstrap/ installs the plugin.
resource "grafana_data_source" "github" {
  type = "grafana-github-datasource"
  name = "GitHub"
  uid  = "github"

  json_data_encoded = jsonencode({
    selectedAuthType = "github-app"
    appId            = var.grafana_github_app_id
    installationId   = var.grafana_github_app_installation_id
  })

  lifecycle {
    # The private key would persist in bucket-readable state, so
    # scripts/set-grafana-github-credentials.sh sets it instead. Grafana
    # preserves secure fields omitted from an update, so applies leave it in
    # place.
    ignore_changes = [secure_json_data_encoded]
  }
}
