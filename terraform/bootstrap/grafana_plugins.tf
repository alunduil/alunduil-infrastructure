# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# A Grafana Cloud stack carries only the core plugins, so the Cloud Logging data
# source in terraform/alunduil/ needs this installed first. Installation is a
# Cloud API operation, and only this layer's cloud_access_policy_token reaches
# that API.
#
# The version is pinned rather than tracking the provider's "latest" default: on
# "latest" a newly published release reads as drift, putting a plugin upgrade
# into an unrelated PR's plan that merging would apply.
resource "grafana_cloud_plugin_installation" "gcp_logging" {
  stack_slug = data.grafana_cloud_stack.this.slug
  slug       = "googlecloud-logging-datasource"
  version    = "1.7.2"
}
