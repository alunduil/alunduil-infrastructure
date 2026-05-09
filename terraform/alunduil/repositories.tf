# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

module "github_repositories" {
  source       = "../modules/github_repositories"
  repositories = var.repositories
}

# Migrate state addresses from the inline resources (pre-issue-#38) into the
# module. Resource-level moves implicitly carry every for_each instance, so
# five blocks cover all managed repos. Safe to delete once any state that
# pre-dates the move has been applied.
moved {
  from = github_repository.managed
  to   = module.github_repositories.github_repository.managed
}

moved {
  from = github_repository_pages.managed
  to   = module.github_repositories.github_repository_pages.managed
}

moved {
  from = github_branch_default.managed
  to   = module.github_repositories.github_branch_default.managed
}

moved {
  from = github_branch_protection.managed
  to   = module.github_repositories.github_branch_protection.managed
}

moved {
  from = github_repository_vulnerability_alerts.managed
  to   = module.github_repositories.github_repository_vulnerability_alerts.managed
}
