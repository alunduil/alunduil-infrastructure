# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# A Grafana Cloud stack carries only the core plugins, so the Cloud Logging data
# source in terraform/alunduil/ needs this installed first. Installation is a
# Cloud API operation, and only this layer's cloud_access_policy_token reaches
# that API.
#
# Pinned because, on the provider's "latest" default, a new release reads as
# drift and puts a plugin upgrade into an unrelated PR's plan.
resource "grafana_cloud_plugin_installation" "gcp_cloud_logging" {
  stack_slug = data.grafana_cloud_stack.this.slug
  slug       = "googlecloud-logging-datasource"
  version    = "1.7.2"
}
