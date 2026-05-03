# SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com>
# SPDX-License-Identifier: MIT

# Import blocks for resources that already exist on the provider side.
# Remove each block once the next apply has folded it into state.

import {
  to = github_repository.managed["blog.alunduil.com"]
  id = "blog.alunduil.com"
}
