---
name: module-tests
description: >-
  How to write, run and review a module's tests here: Arrange / Act / Assert,
  the mirrored test tree, the test files each function and module needs, the
  TestKit assertions, fakes, unit versus integration tests, and running one
  module's tests. Use when adding or changing a function, writing a test,
  fixing a bug or reviewing coverage.
when_to_use: >-
  Trigger phrases: write a test, add tests, test coverage, red first, fake gh,
  ErrorBoundary, flaky test, why does this test pass, integration test, live
  test.
---

# Module tests

Tests are held to the standard of the code they test: no copy-pasted setup, no
logic, behavior not implementation. A bug is a missing test: write the failing
test first and watch it fail for the reason you expect, then fix. A new test
that passes against the old code proves nothing.

## Layout

`test/<ModuleName>/` mirrors `src/<ModuleName>/`: `Public/`, `Private/` and
`Scripts/` hold `Verb-Noun.Tests.ps1`, split for size as
`Verb-Noun.<Aspect>.Tests.ps1` (`.WhatIf`, `.Errors`, `.Verbose`,
`.Parameters`).

- Every file under `Public/` and `Private/` needs its mirrored test file: the
  public-surface test fails without one.
- Every test file is CRLF without a BOM, opens with `#Requires -Version 7.4`,
  strict mode and `$ErrorActionPreference = 'Stop'`, imports each module by the
  path of its `.psd1` (never by name, dependencies first) and ends with
  `exit (Complete-TestRun)`. Only the dependency-throw test imports a `.psm1`.
- A platform file is `*.Windows.Tests.ps1`; after the TestKit import it starts
  with `if (-not $IsWindows) { exit (Skip-TestRun -Reason '...') }`.
- A test that calls the real tool is `*.Live.Tests.ps1`; one that checks our
  parsing against the real tool is `*.Contract.Tests.ps1`.
- Module-wide fixtures live in `<Name>TestHelper.ps1` (the module name without
  `TaffarelJr.` and dots).

## What a function and a module need

Each function: behavior for every parameter set, every error path with its
specific message, `-WhatIf` (`Get-WhatIfOutput`: names the real target, changes
nothing, returns nothing), and the odd inputs that found bugs here: empty and
blank text, a leading `-`, wildcard characters, Unicode, a relative path
(`Use-SplitLocation`), pipeline objects whose property is numeric, an empty
pipeline, and a dictionary with a key named `Count`, `Keys` or `Values`.

Each new module also has, at the module's test root (some older modules lack
some of these):

- `PublicSurface.Tests.ps1`: copy `test/TaffarelJr.Tally/PublicSurface.Tests.ps1`
  and change the module name.
- `ErrorBoundary.Tests.ps1` (models: `test/TaffarelJr.Tally/ErrorBoundary.Tests.ps1`
  for the preference matrix, `test/TaffarelJr.Git/ErrorBoundary.Tests.ps1` for
  the block kinds): one case per block kind the module has (`begin`,
  `process`, `end`, no named block), each under `SilentlyContinue`, `Ignore`,
  `Stop` and `Continue`; the
  error's ID, category and target pinned; no change made after the failure; a
  failing record stops the pipeline; and the case that matters most, the call
  made outside every handler (a fresh runspace, as `Invoke-CallerScript` in
  `GitHubCoreTestHelper.ps1` does, or a child `pwsh`), because inside any `try`
  the difference between a plain `throw` and the boundary disappears.
- `DependencyScope.Tests.ps1` (model: `test/TaffarelJr.Git/DependencyScope.Tests.ps1`)
  if the manifest has `RequiredModules`: global stand-ins for the commands the
  module really calls, defined after the imports and never called; again after
  `Import-Module -Force` of the module and of the dependency; and the throw when
  a dependency is not loaded. That throw is reached only by importing the
  `.psm1`: PowerShell's own `RequiredModules` check fires first on the manifest.
- `Private/ConvertTo-CommandError.Tests.ps1`, and `OutputType.Tests.ps1`, which
  compares each `[OutputType()]` with what a real call returns (through the
  fake for a module that wraps a tool).
- `CredentialHiding.Tests.ps1` where the module takes a secret or a URL, or
  echoes caller text that could hold one, and `ValueMasking.Tests.ps1` where
  `-Mask` is used (`module-secrets`).
- A `*Verbose*.Tests.ps1` where the module writes verbose output or runs a tool
  through an `Invoke-*` helper, itself or through a private helper: the
  command's own `-Verbose`, the same call from `Invoke-VerboseCaller` (a
  function with `$VerbosePreference = 'Continue'` in its scope; the copy after
  the pin carries it across the module boundary), a call from another module,
  `-Verbose:$false`, one line per call, no secret, each read with
  `Get-VerboseLine`. A `SupportsShouldProcess` function also gets the engine's
  own `Performing the operation` line under an explicit `-Verbose`.
- `WhatIfPropagation.Tests.ps1` where the module has `SupportsShouldProcess`
  functions: for each, `Invoke-WhatIfCaller -Call { ... } -WhatIf` runs it from
  a function that was given `-WhatIf`, and nothing changed (the fake recorded no
  call, no file was written, no ref moved). The case fails when the two
  preference copies after the pin are removed.
- The three fixtures above live in `test/PreferenceTestHelper.ps1`, dot-sourced
  by the test file; a copy inside a module's own helper is a duplicate.

## Form

Mark every section of a case: `# Arrange`, `# Act`, `# Assert`. A case with
nothing to arrange drops that section, and Act and Assert stay separate. Two
shapes may mark the sections together on one line (`# Act / Assert`, or
`# Arrange / Act / Assert` when the case builds its input inline): a single
call used directly as an assertion's `-Actual` or as the block `Assert-Throws`
takes, and a table-driven loop that calls and asserts once per row.

Separate cases with a divider: `#` followed by box-drawing characters (U+2500)
out to column 80, counting the indent and the `#` (79 of them at indent 0, 75
inside a 4-space `try`). One also follows the file's setup. A case split across
comments is still one case: the divider goes before it, not inside.

- A test file may pack several short, similar lines together (a run of
  one-line assignments or assertions, a short hashtable on one line) where the
  same code in a module would be spread out.
- Name a case by what goes in, what comes out and under what condition, not by
  the function.
- No logic: no loop or condition decides what to assert. Table-driven cases are
  fine, branching in a case is not.
- Assert behavior, one reason to fail per assertion. A test that restates the
  function body breaks on every refactor and catches nothing.
- Cover the error paths: untested failure handling is usually broken.

## The harness

The runner `test/Invoke-Tests.ps1` uses Pester only to collect coverage and
write reports, and only when `-Coverage` is given; never write `Describe` or
`It`. Use `TaffarelJr.TestKit`:

- `Assert-Equal -Expected -Actual -Message`: strict (case, `$null`, type, deep
  comparison of arrays, dictionaries and objects; the built-in number types
  compare by value). Compare the whole value; do not loosen it with `-like` or
  a cast.
- `Assert-That -Condition -Message`: any other check. `-Condition` is a
  `[bool]`, and a number, a string or an object is refused rather than read as
  truthy: evaluate the condition first.
- `Assert-Throws -ScriptBlock -Message` with `-MessageLike` or `-ExceptionType`,
  always: without either, a typo in a command name passes. A message pattern is
  a wildcard, so escape literal text with `[WildcardPattern]::Escape()` (`*` and
  `[` in a mask or a path).
- `Get-HostOutput`, `Get-WarningOutput` and `Get-WhatIfOutput` (what a block
  wrote, and the `What if:` lines a transcript catches; the last returns an
  object with Output, Messages and Error, where `Error` is `$null` unless
  `-CaptureError` is given). The first two stream strings, so
  wrap them in `@()`. `Use-SplitLocation` separates PowerShell's location from
  the process directory.
- A file that cannot run here ends `exit (Skip-TestRun -Reason '...')` before
  its first case. A file with no assertions fails; one whose checks do not go
  through the kit ends `exit (Complete-TestRun -AllowEmpty)`.

A private function is tested through its module (`& $module { ... }`); follow
what the module's own private tests do where they dot-source the file instead.

## Fakes and fixtures

- Outside `*.Live` and `*.Contract` files, never the real tool, the real user
  config or the real network. For `gh`, `test/GitHubTestHelper.ps1`:
  `New-FakeGitHubCli -Output -ErrorOutput -ExitCode -Sequence` puts a shim first
  on `PATH`; read calls with `Get-FakeGitHubCall -Fixture`; remove it with
  `Remove-FakeGitHubCli -Fixture` in `finally`; `Use-FakePollClock` (with
  `-Module <module>`) makes waits instant. For `git`, throwaway repositories from
  `GitTestHelper.ps1`, which pins `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_NOSYSTEM`,
  strips the repository variables and skips below the minimum git
  (`Get-GitTestSkipReason`). A test that writes git config uses
  `New-GitTestGlobalConfig`, never `/dev/null`: git on Windows reads it as
  empty, but a write fails, or creates `\dev\null` where a `\dev` folder
  exists.
- A `GitHub.*` module run executes the `*.Live` files with the real `gh`
  (read-only calls; the token test looks only at a length and prints nothing)
  and the `*.Contract` files with the real `gh` against a loopback server.
  That is the one place the real tool runs: an ad-hoc probe never does.
- A fake only pins the argument vector the code builds, so it can pin a wrong
  one. Check a flag against `<tool> --help` and the tool's source, and add a
  `*.Contract.Tests.ps1` (a loopback server, `Start-FakeGitHubServer`, with the
  real `gh`) where the tool's own parsing is the oracle. Never skip a live test
  on an error the module itself caused.
- Define a fixture once. Search `test/*.ps1` and `test/**/*TestHelper.ps1`
  first. A fixture a new module needs that exists only hard-wired to another
  module's manifests (`Invoke-CallerScript`, `Get-LeakingSurface`) goes into
  `TaffarelJr.TestKit` with the manifests as a parameter and tests of its own;
  do not make another copy.
- Install and remove stubs in `finally`; restore every environment variable and
  location you change; scratch folders under `[IO.Path]::GetTempPath()`, removed
  in `finally`; paths with the multi-segment `Join-Path`, no drive letters.

## Unit tests and integration tests

Most paths are unit-tested: fakes stand in at the seams (the fake `gh` on
`PATH`, a throwaway git repository, `Use-FakePollClock`), so a case is fast,
deterministic and runs anywhere. Integration tests are few. Each one proves a
connection that no fake can, against the real thing: the real `gh` and its
parsing, a real GitHub or Gallery call. They do not repeat what the unit tests
already cover, and they read only: an integration test that writes needs a
throwaway target and cleans it up in `finally`.

The file name is the tag. `*.Live.Tests.ps1` calls the real tool against the
real service and `*.Contract.Tests.ps1` runs the real tool against a loopback
server; both are integration tests, and every other `*.Tests.ps1` is a unit
test. An integration file skips, with `Skip-TestRun` and a reason, when what it
needs is not there (no tool, no login), and never on an error the module itself
caused.

`Invoke-Tests.ps1` leaves both suffixes out unless `-Integration` is given
(it passes `-Exclude '*.Live', '*.Contract'` to `Invoke-TestRun`), so
`-Module <Name>` stays fast and offline, and CI runs once with `-Integration`.
A case that needs a child process, a timeout or a nested test run belongs in
an aspect file of its own (`Verb-Noun.Process.Tests.ps1`,
`Verb-Noun.Timeout.Tests.ps1`) rather than in the function's unit file, so
the unit file stays fast; which aspects the default run skips is decided per
suffix in `Invoke-Tests.ps1`, never inside the runner module.

## Traps that make a test pass for the wrong reason

- A fake that returns what the code wants to read pins the code, not the tool.
- A table row that changes two things at once cannot say which one failed.
- A global function or variable that is never removed leaks into the next case
  in the file.
- Anything timing-based (thread jobs, waits) fails under load: wait on a
  condition with a generous deadline rather than a fixed sleep, and re-run a
  failure alone on an idle machine before calling it a defect.
- State that outlives a call (a counter store, a cache) is process-wide: clear
  it before the case.

## Running tests

- Run only the module you changed, as
  `pwsh -NoProfile -File test\Invoke-Tests.ps1 -Module Git` (no `TaffarelJr.`
  prefix). Two modules: `-Module Git,Tally`, no space after the comma. One
  file: `-Filter 'Get-GitLog*'`, or `pwsh -NoProfile -File <the .Tests.ps1>`.
  Never the whole suite.
- Changing `TaffarelJr.TestKit`, `ProcessInvocation`, `GitHub.Core` or another
  module that others list in `RequiredModules`: run its own tests, then each
  module that calls what you changed (search `src` and `test`), one at a time as
  background tasks.
- Each file runs in its own `pwsh`, so a test that passes only because an
  earlier file left a module loaded fails here. By default that is a plain
  `pwsh -File`: no Pester, no reports, the file's exit code and tally line are
  the verdict. `-Coverage` runs each file under Pester's coverage tracer
  instead and writes the Cobertura and JUnit reports; it costs about ten
  seconds a file, so it is for CI and for a run you will measure, not for the
  edit-and-run loop. The runner exits with the number of failed files;
  `-ThrottleLimit` sets how many run at once and defaults to the processor
  count. The suite is run one module at a time; a run over every module is
  for CI, where the shared disk, not the CPU, decides how many slots pay.
- A filtered `-Coverage` run overwrites only the matching files' reports.
  Reports of other files, and of files that no longer exist, stay: clear a
  module's old reports before a run you will measure.
- A run over every module measures each module by its own tests: a file's
  coverage is scoped to the source folder named by the first segment of its
  display name. Coverage of a dependency comes from the dependency's tests.
- Never set `TAFFARELJR_TEST_BROKEN_EXE`. Starting a broken `.exe` opens a
  blocking dialog, so the `*.NotExecutable.Tests.ps1` files skip without it. If
  a dialog ever appears during a run, stop the run and tell the owner.

## Coverage

Coverage is a deliverable: every branch a function takes has a case reaching
it. Say plainly what is left uncovered and why (a defensive guard the tool's
output cannot trigger, code in another runspace the tracer cannot see) rather
than writing a case to move the number. The reports come from a `-Coverage`
run: one Cobertura file per test file, each measuring all of that module's
source, so a module's figure is the union of the lines hit across the reports
of one run, not any single report's figure.
