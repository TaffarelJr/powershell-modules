# TaffarelJr.UserInput

Small, composable interactive-prompting primitives for PowerShell scripts:
read a value or a secret, validate it, retry on failure, confirm yes/no,
pick from a menu, and check or persist an environment variable.
Each piece does one job - assemble them per prompt
instead of configuring one do-everything function.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.UserInput
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.UserInput

$name = Read-Input -Prompt 'Repo name' -Default 'my-repo'
if (Confirm-Proceed -Action "create $name") {
    # ...
}

$visibility = Select-Choice -Prompt 'Visibility' -Option 'Public', 'Private' `
    -Default 'Private'
```

The pieces compose.
This one looks in the environment first,
then asks until the answer is valid, up to a bounded number of times:

```powershell
$name = Get-EnvironmentVariable -Name 'REPO_NAME'
if (-not $name) {
    $name = Invoke-InputRetry -ScriptBlock {
        Read-Input -Prompt 'Repo name' | Assert-Input -Require
    }
}
```

A secret can be persisted so the next run does not ask again,
but `Set-EnvironmentVariable` keeps it in the User settings as plain text,
readable by every program that user runs,
so a secret kept this way is only as safe as the account:

```powershell
$token = Get-EnvironmentVariable -Name 'MY_TOKEN'
if (-not $token) {
    $token = Read-Secret -Prompt 'Token'
    if ($token) { $token | Set-EnvironmentVariable -Name 'MY_TOKEN' }
}
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- A prompt needs someone to answer it. A session started with `-NonInteractive`
  makes every prompt fail with `Read-Host`'s own error. Otherwise an answer
  piped in is read, and with the input closed a prompt gives its default
  (`Read-Secret` an empty string, `Confirm-Input` no unless `-Default`).
- `Test-InteractiveHost` is false on CI, under `-NonInteractive`, and in a
  Windows service or session-0 process.
  Then `Invoke-InputRetry` does not re-ask and `Wait-KeyPress` does not wait;
  the prompts still read what is piped in.
  With the input merely closed, `Invoke-InputRetry` asks again up to
  `-MaxAttempt` times before it fails.
- `Invoke-InputRetry` asks again after any failure the answer causes,
  including one an `[int]` or `[ValidateRange]` parameter reports. A block
  that is mistyped - an unknown command, or a parameter that is unknown,
  ambiguous, repeated, or missing - fails at once.
- On Windows, `Set-EnvironmentVariable` keeps the value in the User settings
  as plain text, and `Get-EnvironmentVariable` finds it there even in
  a terminal that was opened before it was saved;
  elsewhere it sets it for the current session only
  and prints the `export` line to add to a shell profile.
  The value comes back exactly as it was saved;
  one of only spaces counts as unset.
- `Select-Choice` is a numbered menu that reads its answer the way
  `Read-Input` does, so it works in any host and answers can be piped in.
  With the input closed it takes its default,
  or fails at once when it has none, instead of asking again.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Errors

A failing call is a terminating error for that call:
the function stops where it failed,
and `-ErrorAction SilentlyContinue` and `Ignore` neither skip nor hide the error.
It ends the call, not the caller's script,
unless the script sets `$ErrorActionPreference = 'Stop'`
(the `pwsh` shell of GitHub Actions already does)
or catches the error with `try` and `catch`.

A failing record in a pipeline stops the pipeline,
and the records before it were processed.
A piped value that fails to bind, such as a value that cannot become a string,
is the exception: that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Assert-Input,Invoke-InputRetry`
for an answer that fails validation inside a retry;
most failures share the `InvalidOperation` category,
so the message is what says what failed.
PowerShell's default error view quotes the line of the calling script,
so a secret written literally in that line is shown there;
give a secret by variable.

`Invoke-InputRetry` repeats the text of the block's error in its warning
between attempts and in the final error.
A block that converts a secret read with `Read-Secret`, such as `[int]`,
can therefore echo it when the conversion fails:
do the conversion outside the block,
or make the block throw a message of its own.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified (`TaffarelJr.UserInput\<Command>`)
or import the module with `-Prefix` to keep them apart.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
