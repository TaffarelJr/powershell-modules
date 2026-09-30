---
name: public-function-contract
description: >-
  The required shape of an exported function in this repo: error boundary,
  -WhatIf, help, output types, parameters, with a skeleton to copy. Use when
  writing, changing or reviewing an exported function, or adding a parameter.
when_to_use: >-
  Trigger phrases: add a function, new command, add a parameter, ShouldProcess,
  comment-based help, OutputType, ThrowTerminatingError.
---

# The public function contract

Copy the skeleton, then change it. Formatting is in `AGENTS.md` (and the
owner's `powershell-style` and `powershell-pitfalls` skills, where installed),
secrets in `module-secrets`, tests in `module-tests`.

```powershell
function Remove-Thing {
    <#
    .SYNOPSIS
        Removes a thing from the store.
    .DESCRIPTION
        Looks the thing up by name and removes it. With -WhatIf nothing is
        changed and nothing is returned.
    .PARAMETER Name
        The thing to remove: its name, or an object with a Name property.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object. A name, or an object with a Name property.
    .OUTPUTS
        None. The thing is removed; nothing is written.
    .EXAMPLE
        Remove-Thing -Name 'old'

        Removes the thing named old.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Example/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Name
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            $resolved = ConvertTo-ThingName -Name $Name
            if (-not $PSCmdlet.ShouldProcess($resolved, 'Remove thing')) {
                return
            }

            Invoke-ThingCommand -Activity "Removing $resolved" -Argument @('remove', '--', $resolved)
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
```

Here `ConvertTo-ThingName` is the resolver: it accepts a string or an object,
and throws for a blank value and for a leading `-`, because `Mandatory` on an
`[object]` still accepts `''`.

- A read-only function that returns objects drops `SupportsShouldProcess`, its
  `-WhatIf` and `-Confirm` help and the guard, and declares
  `[OutputType([PSCustomObject])]` (or a type name) with `.OUTPUTS` naming it.
  A function that changes something and returns an object keeps the guard
  (`return` when skipped) and declares the type too.
- A function with no named block wraps its whole body after `param` in the same
  `try`. With `begin`, `process` and `end`, each block is its own `try`, and
  the pin goes only in the first.

## Failure

- Each of `begin`, `process` and `end` is exactly one `try`, and its `catch` is
  the call shown, with the converter inside the argument.
- Inside, statements and private helpers use a plain `throw` with a specific
  message. A private function never calls `ThrowTerminatingError`: that ends
  only its own call, and a caller without a handler carries on. A plain `throw`
  is skipped when a caller passes `-ErrorAction SilentlyContinue` or `Ignore`,
  which is why the boundary exists.
- `ConvertTo-CommandError` is a private function in every module, and the same
  text in all of them: copy
  `src/TaffarelJr.GitHub.Core/Private/ConvertTo-CommandError.ps1` byte for
  byte. The test fails a module whose copy differs.
- The first statement of the first block's `try` is
  `$ErrorActionPreference = 'Stop'`. A caller's `-ErrorAction` becomes the
  preference inside the function, so a cmdlet that fails without throwing
  (`Remove-Item` on a missing file) is otherwise ignored and the function
  reports a success that never happened. The pin reaches the module's own
  helpers and the later blocks; another module's functions pin their own.
- A failing record in a pipeline stops the pipeline. A command that gathers its
  input first and acts in `end` does nothing when one record fails. The
  README's `## Errors` section says which commands do which.
- Validate and resolve everything before the first change.

## -WhatIf and -Confirm

- Any function that changes something outside the process (a repository,
  GitHub, a file, an environment variable, an installed module, a launched
  process) declares `SupportsShouldProcess`. Validate, resolve and read first,
  so `-WhatIf` still refuses bad input and names the real target. Everything
  that changes something, and everything that only makes sense afterwards
  (polling, the returned object), goes inside the guard. A skipped function
  returns nothing.
- Never set `ConfirmImpact`: a prompt throws in a non-interactive host, so a
  caller in CI would fail. Where a function asks the user itself
  (`Confirm-Proceed` in UserInput), the default is No for anything that sends or
  installs, and a closed standard input takes the default.
- A caller's `-WhatIf` does not reach a module function on its own: it sets
  `$WhatIfPreference` in the caller's scope, which the module never sees, so a
  function called from a `-WhatIf` run would act. Right after the pin, copy
  `$WhatIfPreference` and `$ConfirmPreference` with
  `$PSCmdlet.GetVariableValue`, each guarded by `$PSBoundParameters.ContainsKey`
  so the function's own switch wins; the skeleton shows both, and the
  public-surface test checks for them.
- Plumbing that runs what the caller hands it (`Invoke-NativeCommand`,
  `Invoke-NativeRead`, `Invoke-GitHubCommand`, a test runner) does not declare
  `SupportsShouldProcess`: the caller that decided to change something holds
  the guard, and the plumbing's help says so.
- `-WhatIf` does not cross a module boundary outward either. A call into another
  module's changing function sits inside the guard, and the target text hides
  credentials. A built-in cmdlet inherits `$WhatIfPreference` inside the module
  and only prints `What if:`, so an inner command that must run (a read that
  feeds the guard) gets `-WhatIf:$false -Confirm:$false`. So does a changing
  call into one of this repo's own modules from inside the guard
  (`Invoke-GitHubApi -Method POST`): the callee copies the caller's preferences
  the same way, and under `-Confirm` would ask a second time for the change the
  guard already asked about.
- A function with a state-changing verb that touches nothing outside the
  process suppresses `PSUseShouldProcessForStateChangingFunctions` and says
  why.
- `Get-Help` leaves `-WhatIf` and `-Confirm` blank for a function: document both
  with the two sentences in the skeleton, exactly.

## Help

- `.SYNOPSIS` is a third-person verb phrase ("Returns the...", "Removes a...").
  `.DESCRIPTION` says, in a sentence or two, what the synopsis cannot: what the
  function reads, what it changes, and what it returns; the Gallery page and
  `Get-Help -Full` show it, and a function whose only description is the
  `-WhatIf` sentence has none. Every parameter has a `.PARAMETER`, however
  obvious. `.INPUTS` and `.OUTPUTS` are always present (`None` when there is
  nothing). `[OutputType()]` is
  declared exactly when `.OUTPUTS` is not `None`; `[OutputType([void])]` does
  not count.
- At least one `.EXAMPLE`: code that parses, with no blank line inside it,
  using only real parameters by exact name or alias, then a blank line and a
  sentence saying what it does. Use `OWNER/REPO` for placeholders. The first
  `.LINK` is the module's README URL.
- Help lines stay within 80 columns (a URL excepted). No help line starts with
  a dot-word: `.NET` or `.psm1` at the start of a line is read as a keyword
  and drops the whole block. A `.PARAMETER` for a parameter that does not
  exist is silently dropped.

## Parameters

- Singular for a parameter that takes one thing at a time; a natural plural
  stays (`-TimeoutSeconds`, a hashtable `-Inputs`).
- A `-Path` or `-LiteralPath` that binds by property name has
  `[Alias('PSPath')]`.
- More than one parameter set means `DefaultParameterSetName`, and at most one
  `ValueFromPipeline` per set. A value that must accept an object from
  another command is `[object]` plus a resolver, never `[string]`.
- `ValueFromPipeline` needs a `process` block, or only the last record runs. An
  empty pipeline must not turn into "all": decide "was anything given" from
  `$PSBoundParameters` and, for work done in `begin` or `end`,
  `$MyInvocation.ExpectingInput` (an empty pipeline never enters `process`).
- `Mandatory` rejects `$null` for any non-value type and an empty array for any
  array type, but rejects `''` only for `[string]` and `[string[]]`. When blank
  is legal add `[AllowEmptyString()]` at every layer the value crosses; when it
  is not, an `[object]` resolver rejects it.
- A value that becomes a command operand rejects a leading `-` with
  `[ValidatePattern('^(?!-)')]` (option injection), and travels after `--` only
  where the subcommand reads it as a plain operand (`wrapping-native-tools`).
  Give each validation attribute a specific `ErrorMessage` that says what is
  wrong.
- A path is resolved against PowerShell's location before .NET sees it:
  `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath`.
- A secret parameter has a `[securestring]` form (`-SecureToken`). A `[string]`
  twin exists only where callers have just text, and the help says it is the
  less preferred form (`module-secrets`).

## Output

- Stream results one at a time: `return $results`, never `return , $results`.
  "No result" is a bare `return`, never `return $null`. Callers wrap in `@()`.
  Compute under a lock, release it in `finally`, then emit; never write to the
  pipeline while holding one (`Get-Tally`).
- Display text goes through `TaffarelJr.ConsoleOutput`. `Write-Host` is for
  what that module cannot do (a prompt left open on its line) or where a
  module cannot depend on it (TestKit, RequiredModules), and carries a
  `SuppressMessage` whose Justification says the text is for the person at the
  console, not data. Diagnostics use `Write-Verbose`.
- A thrown message names the failing activity and the reason; for a native
  tool also the command line (credentials hidden), the exit code or status and
  the tool's own words. A message that echoes caller text hides credentials
  first.

## Verbose and dependencies

- A caller's local `$VerbosePreference` does not reach a module function. A
  public function that writes `Write-Verbose`, or runs a tool through an
  `Invoke-*` helper (whose verbose line is then its only diagnostic), itself or
  through a private helper of its own, copies it after the pin, without losing
  its own `-Verbose`; the public-surface test checks for the copy, following
  the module's private helpers to find the functions that need it:

  ```powershell
  if (-not $PSBoundParameters.ContainsKey('Verbose')) {
      $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
  }
  ```

- A helper that runs a tool through another module's `Invoke-Native*` passes
  `-Verbose:$false`, writes its own masked line, and passes any value that may
  be secret as `-Mask`; otherwise the layer below prints the raw command line.
- A module that lists `RequiredModules` imports each at the top of its `.psm1`
  into its own scope (`module-structure`), because a call into another module
  otherwise resolves through the global scope, where a later-loaded command of
  the same name wins.

## What is checked

`test/PublicSurfaceTestHelper.ps1` fails with one message per broken rule it
can check: the shape, the help, the manifest and the dependency loop. It does
not check message wording, masking, pipeline behavior, `-WhatIf` behavior or
the pipeline-stops claim: `module-tests` lists the tests for those, and a new
function needs them.
