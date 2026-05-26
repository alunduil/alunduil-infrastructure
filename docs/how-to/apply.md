<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Run an apply

From `terraform/alunduil/`:

```sh
gcloud auth application-default login
export TF_VAR_cloudflare_api_token=...
export GITHUB_TOKEN=...

terraform init
terraform plan
terraform apply
```

Required scopes for both tokens are in
[reference/credentials.md](../reference/credentials.md).
