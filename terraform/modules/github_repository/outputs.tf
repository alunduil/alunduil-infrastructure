# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

output "name" {
  value       = github_repository.this.name
  description = "Repository slug, for root-module resources that hang off this repo."
}
