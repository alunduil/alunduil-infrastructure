# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# One-time reconciliation for the github_branch_protection -> ruleset
# migration (#162). These three repositories already carried a
# server-side ruleset named "default" (created by hand before the
# migration), so the apply's fresh create collided with "Name must be
# unique" and the main apply failed. Adopt the existing rulesets into
# state; the next apply then reconciles each to the module's config.
# Safe to remove once the import has landed in state.
import {
  to = module.alunduil_chezmoi.github_repository_ruleset.default_branch
  id = "alunduil-chezmoi:15615310"
}

import {
  to = module.alunduil_infrastructure.github_repository_ruleset.default_branch
  id = "alunduil-infrastructure:15541031"
}

import {
  to = module.woodland_generators.github_repository_ruleset.default_branch
  id = "woodland-generators:6845434"
}
