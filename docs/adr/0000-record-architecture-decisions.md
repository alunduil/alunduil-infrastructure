<!-- SPDX-FileCopyrightText: 2026 Alex Brandt <alunduil@gmail.com> -->
<!-- SPDX-License-Identifier: MIT -->

# 0. Record architecture decisions

## Status

Proposed

## Context

Architecturally significant, hard-to-reverse choices in this repo —
platform selection, dependency lock-in, cross-cutting conventions —
have so far lived only in commit messages and PR descriptions. That
scatters the reasoning: the *what* survives in the diff, but the *why*
and the *rejected alternative* are hard to reconstruct later. As the
personal-systems surface grows (see the C4 model in #84), the next
decision keeps re-litigating settled ground.

An Architecture Decision Record (ADR) captures one decision — its
context, the choice, and the consequences accepted — as a short,
immutable document. The collection becomes the durable record of *why*
the system is shaped the way it is.

## Decision

We will record architecturally significant decisions as ADRs under
`docs/adr/`, one file per decision, named `NNNN-kebab-title.md` with a
zero-padded sequence starting at `0000` (this record).

Substantive decisions use the **MADR** template
(<https://adr.github.io/madr/>) — its Decision Drivers and per-option
pros/cons carry a multi-alternative comparison better than Nygard's
lighter shape. This meta-record, which only establishes the practice,
stays in the lighter Nygard form.

A new ADR starts at `Status: Proposed`. It is promoted to `Accepted`
(or `Rejected` / `Superseded by NNNN` / `Deprecated`) once the decision
is actually settled, not at draft time.

`docs/adr/README.md` indexes the collection.

## Consequences

- The reasoning behind a hard-to-reverse choice outlives the PR that
  shipped it, and a superseding decision links back to what it
  replaced.
- Every significant decision now carries the cost of writing it down.
  This is deliberate friction, warranted only when the choice is
  significant *and* hard to reverse; tactical, easily-reversed choices
  stay in commit messages and PR descriptions.
- ADRs are immutable once `Accepted`. A changed decision is a new ADR
  that supersedes the old one, never an edit to the original.
