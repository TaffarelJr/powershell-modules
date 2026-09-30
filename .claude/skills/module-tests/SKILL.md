---
name: module-tests
description: >-
  Writes and reviews tests for a module in this repo: Arrange/Act/Assert
  form, a test tree that mirrors src/<Module>, and a lightweight assertion
  harness rather than Pester as the authoring framework. Use when adding a
  function that needs a test, writing a test file, or reviewing a module's
  test coverage.
when_to_use: >-
  Trigger phrases: write a test, add tests, test this function, review
  test coverage, does this have good coverage.
allowed-tools: Read Edit Write Glob Grep Bash
---

# Module tests

## Layout

Every function gets a test file at the mirrored path under
`test/<ModuleName>/` — see the module-structure skill for the folder shape.
A file split for size becomes `Verb-Noun.<Aspect>.Tests.ps1`, still under
the same mirrored path.

## Form

Write every case as Arrange / Act / Assert, each section marked as such. A
case with nothing to arrange may drop that section, but Act and Assert
never merge into one.

- Assert **behavior**, not implementation — a test that restates the
  function body breaks on every refactor and catches nothing.
- One reason to fail per test; name the case by what goes in, what comes
  out, and under what condition, not by the function's own name.
- No logic in a test — no loop or conditional deciding what to assert.
  Table-driven cases are fine; branching inside a case is not.
- Cover the error paths. Untested failure handling is usually broken
  failure handling.
- Tests are held to the same coding standard as the module code they
  test — no copy-pasted setup; shared fixtures live in one harness, not
  duplicated per file.

## Coverage

Coverage is a deliverable, not a by-product: every branch a function takes
needs a case reaching it. Say plainly what's left uncovered and why, rather
than writing a case purely to move the number.

## Harness

Pester is allowed only as a coverage collector
(`Invoke-Pester -CodeCoverage`), never as the authoring framework — don't
write cases as Pester `Describe`/`It` blocks. This repo doesn't have its
own assertion harness yet; one gets built (or ported from
`.github/scripts/tests/TestKit.psm1`) alongside the first module's tests,
not invented separately per file.
