# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "repositories" {
  description = "Map of managed repositories keyed by name (full github_repository attributes)."
  value       = github_repository.managed
}
