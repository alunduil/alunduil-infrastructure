# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The blog's build reads the Web Analytics RUM dataset through
# viewer.accounts(accountTag), which a zone-scoped token answers with
# "authz: not authorized for that account". Every token in cloudflare_tokens.tf
# is zone-scoped, hence a second one here.
data "cloudflare_api_token_permission_groups_list" "account_analytics_read" {
  name  = "Account Analytics Read"
  scope = "com.cloudflare.api.account"
}

locals {
  # The account the alunduil.com zone sits under.
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

# Pinned to the workflow, not the branch. Other workflows share the blog's
# default branch and one of them fires on `issues: opened`, which any stranger
# can trigger, so a branch-level condition would rest the boundary on each of
# those files continuing to decline id-token: write.
#
# Renaming or moving pages.yml revokes access, and the build treats a missing
# token as no data — so the symptom is a missing section on a green run.
module "blog_analytics_reader" {
  source = "../modules/workflow_secret_reader"

  project_id = google_project.env.project_id

  pool = {
    id                   = "blog"
    display_name         = "blog.alunduil.com"
    description          = "Workload Identity Pool for blog.alunduil.com builds"
    provider_description = "OIDC provider for blog.alunduil.com GitHub Actions"
  }

  caller = {
    workflow            = "alunduil/blog.alunduil.com/.github/workflows/pages.yml"
    ref                 = "refs/heads/main"
    principal_attribute = "repository"
  }

  service_account = {
    account_id   = "blog-analytics-reader"
    display_name = "blog.alunduil.com Analytics Reader"
    description  = "Identity the blog's Pages build federates into to read its Cloudflare analytics token"
  }

  secret_ids = [google_secret_manager_secret.cloudflare_api_token_blog_analytics_ro.secret_id]

  depends_on = [google_project_service.sts, google_project_service.iam]
}

moved {
  from = google_iam_workload_identity_pool.blog
  to   = module.blog_analytics_reader.google_iam_workload_identity_pool.this
}

moved {
  from = google_iam_workload_identity_pool_provider.blog
  to   = module.blog_analytics_reader.google_iam_workload_identity_pool_provider.this
}

moved {
  from = google_service_account.blog_analytics_reader
  to   = module.blog_analytics_reader.google_service_account.reader
}

moved {
  from = google_service_account_iam_member.blog_analytics_reader
  to   = module.blog_analytics_reader.google_service_account_iam_member.reader
}

moved {
  from = google_secret_manager_secret_iam_member.cloudflare_api_token_blog_analytics_ro_accessor
  to   = module.blog_analytics_reader.google_secret_manager_secret_iam_member.reader["cloudflare-api-token-blog-analytics-ro"]
}
