# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# The provider's condition and the reader's binding must agree, or the token
# exchange fails silently.

mock_provider "google" {
  override_resource {
    target = google_iam_workload_identity_pool.this
    values = { name = "projects/123/locations/global/workloadIdentityPools/example" }
  }

  override_resource {
    target = google_service_account.reader
    values = {
      name  = "projects/example/serviceAccounts/reader@example.iam.gserviceaccount.com"
      email = "reader@example.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id      = "example"
  pool            = { id = "example", display_name = "Example", description = "Example", provider_description = "Example" }
  service_account = { account_id = "example-reader", display_name = "Example", description = "Example" }
  secret_ids      = ["first", "second"]
}

run "owner_principal_admits_any_ref" {
  variables {
    caller = { workflow = "owner/shared/.github/workflows/reusable.yml", principal_attribute = "repository_owner" }
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.this.attribute_condition == "assertion.repository_owner == 'owner' && assertion.job_workflow_ref.startsWith('owner/shared/.github/workflows/reusable.yml@')"
    error_message = google_iam_workload_identity_pool_provider.this.attribute_condition
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.this.attribute_mapping == tomap({ "google.subject" = "assertion.sub", "attribute.repository_owner" = "assertion.repository_owner" })
    error_message = "attribute_mapping doesn't map repository_owner"
  }

  assert {
    condition     = google_service_account_iam_member.reader["roles/iam.workloadIdentityUser"].member == "principalSet://iam.googleapis.com/projects/123/locations/global/workloadIdentityPools/example/attribute.repository_owner/owner"
    error_message = google_service_account_iam_member.reader["roles/iam.workloadIdentityUser"].member
  }
}

run "repository_principal_admits_any_ref" {
  variables {
    caller = { workflow = "owner/repo/.github/workflows/test.yml", principal_attribute = "repository" }
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.this.attribute_condition == "assertion.repository == 'owner/repo' && assertion.job_workflow_ref.startsWith('owner/repo/.github/workflows/test.yml@')"
    error_message = google_iam_workload_identity_pool_provider.this.attribute_condition
  }

  assert {
    condition     = google_service_account_iam_member.reader["roles/iam.serviceAccountTokenCreator"].member == "principalSet://iam.googleapis.com/projects/123/locations/global/workloadIdentityPools/example/attribute.repository/owner/repo"
    error_message = google_service_account_iam_member.reader["roles/iam.serviceAccountTokenCreator"].member
  }
}

run "exact_ref_admits_only_that_ref" {
  variables {
    caller = { workflow = "owner/repo/.github/workflows/deploy.yml", ref = "refs/heads/main", principal_attribute = "repository" }
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.this.attribute_condition == "assertion.repository == 'owner/repo' && assertion.job_workflow_ref == 'owner/repo/.github/workflows/deploy.yml@refs/heads/main'"
    error_message = google_iam_workload_identity_pool_provider.this.attribute_condition
  }
}

run "extra_conditions_follow_the_derived_clauses" {
  variables {
    caller           = { workflow = "owner/repo/.github/workflows/test.yml", principal_attribute = "repository" }
    extra_conditions = ["assertion.actor_id == '1'", "assertion.event_name == 'pull_request'"]
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.this.attribute_condition == "assertion.repository == 'owner/repo' && assertion.job_workflow_ref.startsWith('owner/repo/.github/workflows/test.yml@') && assertion.actor_id == '1' && assertion.event_name == 'pull_request'"
    error_message = google_iam_workload_identity_pool_provider.this.attribute_condition
  }
}

run "reader_accesses_each_secret" {
  variables {
    caller = { workflow = "owner/repo/.github/workflows/test.yml", principal_attribute = "repository" }
  }

  assert {
    condition     = toset(keys(google_secret_manager_secret_iam_member.reader)) == toset(["first", "second"])
    error_message = "the reader isn't granted exactly the listed secrets"
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.reader["second"].member == "serviceAccount:reader@example.iam.gserviceaccount.com"
    error_message = google_secret_manager_secret_iam_member.reader["second"].member
  }
}

run "workflow_outside_workflows_dir_rejected" {
  command = plan

  variables {
    caller = { workflow = "owner/repo/build.yml", principal_attribute = "repository" }
  }

  expect_failures = [var.caller]
}
