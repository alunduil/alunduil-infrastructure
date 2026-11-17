<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

<!--
Maintainer notes. Claude strips HTML comments, but Copilot also
reads this file and may not, so keep this block short.
- AGENTS.md is AI-targeted and loaded every session. Optimise for
  tokens; keep under ~75 lines.
- Add an entry only when an agent has made the same mistake twice
  or a non-obvious convention bit a session.
- Prefer pointers (README §..., file:line) over copies of content
  that already lives elsewhere.
- Human-facing context lives in [README](README.md); no
  CONTRIBUTING.md (single maintainer; outside contributions are
  not solicited).
-->

# Claude Code instructions for alunduil-infrastructure

@AGENTS.md

## Claude Code skills

- Adding a new repo to the org: run the `scaffold-repo` skill.
- Reviewing the estate's health: run the `estate-review` skill.
