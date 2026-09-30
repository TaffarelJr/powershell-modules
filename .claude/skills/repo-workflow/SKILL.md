---
name: repo-workflow
description: >-
  How work is tracked, committed and merged in this repo: the standing
  permission on the GitHub issues, the commit shapes of a module, the 0.1.0
  version policy, rebase merges only, and what must hold before a change is
  done. Use when committing, opening or updating a pull request, opening or
  updating an issue, or deciding whether to bump a version.
when_to_use: >-
  Trigger phrases: commit this, open a PR, open an issue, update the issue,
  version bump, is this done.
---

# Repository workflow

## Tracking work

- GitHub Issues hold the work. A standing permission covers ticking items and
  posting summary and status comments on the module-review issues as the work
  happens, without being asked, from the main session only and never from a
  delegated agent. It covers nothing else public: a pull request, a push or a
  merge needs the owner's request.
- A topic deferred "for later" becomes an issue straight away, linked from the
  status comment, so it is not forgotten.

## Commits

- One commit, one responsibility, with a Conventional Commit subject (`feat:`,
  `fix:`, `docs:`, `test:`, `chore:`) whose type matches the work and a body
  that says what the commit contains and why.
- The repository builds and its tests pass after every commit, and nothing
  churns: a pull request never adds a file in one commit only to move or
  delete it in a later one.
- A new module is usually three commits, each subject a Conventional Commit:
  `feat: add the TaffarelJr.<Name> module` (source),
  `docs: document the TaffarelJr.<Name> module` (README, CHANGELOG, the row in
  the root README) and `test: add TaffarelJr.<Name>'s tests` (tests, including
  its `PublicSurface.Tests.ps1`).
- Every module stays `0.1.0` until real Gallery publishing starts: no version
  bumps (`module-structure`, `publishing-modules`).

## Pull requests

- Pull requests here follow the owner's `stacked-pull-requests` skill where it
  is installed: drafts, fixes folded into the introducing commit while the PR
  is open, stacks linked bottom to top, only the owner merges.
- The repository allows rebase merges only, so every commit lands as written
  and its message matters.

## Before you call a change done

- The changed module's tests pass (`module-tests`), and the analyzer is clean on
  every changed file, run file by file.
- `git status --short` shows only the files you meant to change, and each new
  or rewritten file is CRLF without a BOM, checked by bytes.
- A scan finds no token-shaped literal.
- Every README or help sentence you wrote or touched was probed, and the skill
  that owns the rule still agrees with the code.
- The issue is ticked and commented.
