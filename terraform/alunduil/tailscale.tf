# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Nothing reads this. Terraform configures a provider only when something
# references it, so without a data source the credential is never exercised and
# a broken one reaches apply unnoticed.
data "tailscale_devices" "all" {}
