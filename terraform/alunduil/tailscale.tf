# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Scaffold auth check. Terraform only configures a provider that something
# references, so this read-only data source is what makes `terraform plan`
# actually authenticate to Tailscale and prove the OAuth client works against
# the factory-default tailnet. The import issue (#96 step 3) replaces it with
# the real ACL/DNS/tag configuration.
data "tailscale_devices" "all" {}
