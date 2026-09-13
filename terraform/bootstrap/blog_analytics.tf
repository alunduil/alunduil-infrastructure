# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# blog.alunduil.com ranks its popular posts at build time from the Cloudflare
# Web Analytics RUM dataset. That query filters on viewer.accounts(accountTag),
# so it needs an account-level token; the deployer tokens in
# cloudflare_tokens.tf are scoped to the alunduil.com zone and return
# "authz: not authorized for that account".
data "cloudflare_api_token_permission_groups_list" "account_analytics_read" {
  name  = "Account Analytics Read"
  scope = "com.cloudflare.api.account"
}

locals {
  # The account the alunduil.com zone sits under, and the accountTag the blog's
  # GraphQL query names.
  alunduil_account_resource = jsonencode({
    "com.cloudflare.api.account.76626ec3f004e86f1a4d85faca9ac3a2" = "*" # pragma: allowlist secret
  })
}

resource "cloudflare_api_token" "blog_analytics_ro" {
  name = "blog.alunduil.com analytics (RO)"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = data.cloudflare_api_token_permission_groups_list.account_analytics_read.result[0].id },
    ]
    resources = local.alunduil_account_resource
  }]
}

resource "google_secret_manager_secret" "cloudflare_api_token_blog_analytics_ro" {
  project   = google_project.env.project_id
  secret_id = "cloudflare-api-token-blog-analytics-ro"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "cloudflare_api_token_blog_analytics_ro" {
  secret      = google_secret_manager_secret.cloudflare_api_token_blog_analytics_ro.id
  secret_data = cloudflare_api_token.blog_analytics_ro.value
}

# The provider's condition and the reader's binding have to keep naming the
# same repository, and a disagreement between them fails silently. Deriving
# both from one name is what stops them drifting apart.
locals {
  blog_repository         = "alunduil/blog.alunduil.com"
  blog_pages_workflow_ref = "${local.blog_repository}/.github/workflows/pages.yml@refs/heads/main"
  blog_wif_principal      = "${local.wif_pool_prefix}/blog/attribute.repository/${local.blog_repository}"
}

# A pool of its own rather than another provider in `github`. principalSet paths
# are pool-scoped and provider-agnostic, and that pool's RW deployer binding
# (local.wif_principal_main) is keyed on attribute.ref with no repository
# component — so admitting a second repository there would hand its default
# branch the apply identity. See #530.
resource "google_iam_workload_identity_pool" "blog" {
  project                   = google_project.env.project_id
  workload_identity_pool_id = "blog"
  display_name              = "blog.alunduil.com"
  description               = "Workload Identity Pool for blog.alunduil.com builds"
  disabled                  = false

  depends_on = [google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "blog" {
  project                            = google_project.env.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.blog.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub"
  description                        = "OIDC provider for blog.alunduil.com GitHub Actions"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Pinned to one workflow, not to a branch. Five workflows run on the blog's
  # default branch and labels.yml fires on `issues: opened`, which any stranger
  # can trigger; a branch-level condition would leave the boundary resting on
  # each of those files continuing to decline id-token: write.
  #
  # Renaming or moving pages.yml revokes access here, and the build degrades to
  # no Popular section rather than failing — so the symptom is a missing widget,
  # not a red run.
  attribute_condition = "assertion.job_workflow_ref == '${local.blog_pages_workflow_ref}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "blog_analytics_reader" {
  project      = google_project.env.project_id
  account_id   = "blog-analytics-reader"
  display_name = "blog.alunduil.com Analytics Reader"
  description  = "Identity the blog's Pages build federates into to read its Cloudflare analytics token"

  depends_on = [google_project_service.iam]
}

# workloadIdentityUser admits the federated identity; serviceAccountTokenCreator
# lets it mint the access token get-secretmanager-secrets calls with. Both are
# scoped to this one service account.
resource "google_service_account_iam_member" "blog_analytics_reader" {
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    "roles/iam.serviceAccountTokenCreator",
  ])

  service_account_id = google_service_account.blog_analytics_reader.name
  role               = each.key
  member             = local.blog_wif_principal

  depends_on = [google_iam_workload_identity_pool_provider.blog]
}

# The reader holds no project IAM at all: this one grant is its entire
# authority, matching the per-secret accessor pattern the deployer tokens use.
resource "google_secret_manager_secret_iam_member" "cloudflare_api_token_blog_analytics_ro_accessor" {
  project   = google_secret_manager_secret.cloudflare_api_token_blog_analytics_ro.project
  secret_id = google_secret_manager_secret.cloudflare_api_token_blog_analytics_ro.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.blog_analytics_reader.email}"
}
