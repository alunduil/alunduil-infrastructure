# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "repository" {
  value       = github_repository.this
  description = "The github_repository resource."
}
