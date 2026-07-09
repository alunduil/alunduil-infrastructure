<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# Manual surface

Steps that sit outside both the CI `terraform apply` on merge to `main`
and the `just bootstrap` recipe. Check here before assuming a concern
is Terraform-managed.

## Branch protection on `main`

Requires the `pre-commit` and `terraform-plan` status checks. Set in
the repository's branch-protection settings; click-ops, not
Terraform-managed.

## `develop` → `main` renames

Terraform can't safely rename an existing default branch. Use GitHub's
"Rename branch" so PR refs and forks are preserved; `github_branch_default`
then holds `main` in.
