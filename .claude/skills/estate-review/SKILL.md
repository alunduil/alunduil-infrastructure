---
name: estate-review
description: Review the personal estate's health over a recent window — outages, failing jobs, telemetry gaps, CI and dependency failures, expiring credentials — across every asset in the asset register and every repository this repo manages, then match findings to existing issues and file the rest. Use when asked to review the last week (or any window), look for outages or infrastructure issues across the estate, run a health check, or confirm problems have issues filed.
---

# Estate review

Survey every source read-only, report ranked findings marked tracked or
untracked, then file only what alunduil approves. Default window: the last 7
days, with 30 days of history to tell a recurrence from a one-off.

Runs on alunduil's workstation only: the TrueNAS MCP server answers on the
LAN, and `gcx` and the other MCP servers are host configuration. In a web or
cloud session, say so and stop.

## 1. Load context

- `docs/reference/asset-register.md` — the scope. Every asset, entry point,
  dependency and credential should be covered by some source below, or named
  as a blind spot.
- Open issues in `alunduil/alunduil-infrastructure` and
  `alunduil/alunduil-chezmoi` through REST
  (`gh api 'repos/<r>/issues?state=open&per_page=100' --paginate`), saved to
  the scratchpad. Step 3 matches findings against them.
- The previous estate review's issues (search `"weekly estate review"`), so
  the report can say recurred, fixed, or still open.

## 2. Probe, then fan out

Probe each source with one cheap call before spawning agents: a TrueNAS
`system_info`, an UptimeRobot `list-monitors`, a `gcx api /api/health`, a
`gh api rate_limit`. Name any unreachable source in the report's first lines
and leave it out; never fill its gap from another source.

Spawn one read-only background agent per source in `sources.md`, in a single
message. Each prompt is that file's "Every brief" section followed by the
source's section, both verbatim.

If an agent dies on a transport error, resume it with `SendMessage` once the
network is back, rather than starting a fresh one that loses its context.

## 3. Verify before reporting

- An all-zero count or an empty result: check the raw response before
  believing it.
- A cause inferred from logs: name it as inferred, and say which
  configuration would confirm it.
- An alarm alunduil can settle from what they already know — a domain's
  renewal, a scheduled router restart — goes in as a question, not a
  finding. Known answers so far:
  - `alunduil.com` renews automatically at Squarespace.
  - The Deco restarts every Saturday at 06:00 on its own clock, so a short
    Saturday blip at ~05:00Z (BST) or ~06:00Z (GMT) is most likely the
    restart. Anything longer, or at another hour, is a finding.
- Search both repos (open and closed) for each finding before calling it
  untracked.

## 4. Report

Send partial results as agents finish, then one consolidated report:

1. Lead sentence: the worst current problem, and whether anything is down now.
2. **Broken**, numbered and ranked by impact. Each item: what, evidence, and
   either the tracking issue (`#N`, repo-qualified outside this repo) or
   "untracked".
3. **Due soon**: credentials, certificates, keys, domains expiring within 30
   days.
4. **Blind spots**: assets or failure modes no source could see this run.
5. **Working**: one line per source, with numbers.
6. A closing ask, by number: which to file, which become comments on
   existing issues, which questions alunduil can answer.

Numbering stays stable across follow-up messages, so replies like "all
except 2" stay unambiguous. Stop after the report and wait for the answer.

## 5. File what's approved

- New issues: the `issue-create` skill. Cite "the YYYY-MM-DD weekly estate
  review" in Motivation, so the next review can find them.
- Evidence for an existing issue: a comment carrying only what's new — read
  the body first.
- Edges: the `issue-links` skill. Read both issues and the code they touch
  before adding a blocked-by; a mention is the default.
- Before filing infrastructure scope, check it against recorded decisions in
  the Terraform it would change (for example, CI never holds `billing.*`).
- Finish with what was filed, commented, skipped as a duplicate, and still
  waiting on alunduil.
