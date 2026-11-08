---
name: repo-workflow
description: >-
  How work is tracked, committed and merged in this repo: the standing
  permission on the GitHub issues, rebase merges only, how a module is
  released, and what must hold before a change is done. Use when committing,
  opening or updating a pull request, opening or updating an issue, or
  releasing a module.
when_to_use: >-
  Trigger phrases: commit this, open a PR, open an issue, update the issue,
  release a module, is this done.
---

# Repository workflow

## Tracking work

- GitHub Issues hold the work. A standing permission covers ticking items and
  posting summary and status comments on the module-review issues as the work
  happens, without being asked, from the main session only and never from a
  delegated agent. It covers nothing else public: a pull request or a push
  needs the owner's request, and only the owner merges.
- A topic deferred "for later" becomes an issue straight away, linked from the
  status comment, so it is not forgotten.

## Commits

- One commit, one responsibility, with a Conventional Commit subject (`feat:`,
  `fix:`, `docs:`, `test:`, `chore:`) whose type matches the work and a body
  that says what the commit contains and why.
- The repository builds and its tests pass after every commit, and nothing
  churns: a pull request never adds a file in one commit only to move or
  delete it in a later one.

## Pull requests

- Pull requests here follow the owner's `stacked-pull-requests` skill where it
  is installed: drafts, fixes folded into the introducing commit while the PR
  is open, only the owner merges.
- The repository allows rebase merges only, so every commit lands as written
  and its message matters. A Conventional Commit scope, where one helps, is
  the module's lowercase short name (`feat(testkit):`, `fix(github.core):`).
- `CI complete` is the one check a pull request must pass; it passes when the
  analyzer, the affected modules' tests on both platforms, the coverage upload
  and the single-file build passed or were skipped as unaffected
  (`module-tests`, Running tests).

## Releases

- A module is released on its own: a pull request bumps its `ModuleVersion`
  and moves its CHANGELOG's `Unreleased` items under the version, and after
  the merge a GitHub Release is created in the UI on the tag
  `<ModuleName>/vX.Y.Z` at that commit. Publishing the
  release runs `publish.yml` (`publishing-modules`). Dependencies are released
  first, lowest in the chain first.

## Before you call a change done

- The changed module's tests pass (`module-tests`), and the analyzer is clean on
  every changed file, run file by file.
- `git status --short` shows only the files you meant to change, and each new
  or rewritten file is CRLF without a BOM, checked by bytes.
- A scan finds no token-shaped literal.
- Every README or help sentence you wrote or touched was probed, and the skill
  that owns the rule still agrees with the code.
- The issue is ticked and commented.
