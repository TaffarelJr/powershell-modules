# TaffarelJr.ProcessInvocation

Runs an external command with its output captured and consistently decoded,
throwing a clear, detailed error when it fails -
or, for a tolerated failure, reporting what happened instead of throwing.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.ProcessInvocation
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.ProcessInvocation

$root = Invoke-NativeCommand -Activity 'Finding the repository' -Command 'git' `
    -Argument @('rev-parse', '--show-toplevel')

$read = Invoke-NativeRead -Command 'git' `
    -Argument @('rev-parse', '--show-toplevel')
$read.Ok        # True inside a repository, False outside one
$read.Output    # one string per line git printed: the repository's folder
```

`Invoke-NativeCommand` returns the output and throws when the command fails.
`Invoke-NativeRead` never throws for what the command does: it returns a
hashtable with `Ok`, `Started`, `ExitCode`, `Output`, `ErrorOutput`,
and `TimedOut`.

Both also take `-StdIn`, `-WorkingDirectory`, `-SeparateStderr` (keep stderr
out of the output you parse), and - for a command that must be an executable -
`-Environment` and `-TimeoutSeconds`. `-TimeoutSeconds` bounds the whole call,
including output held open by a process the command started.

For a command whose output should stream straight to the console,
run it yourself and check the result afterwards:

```powershell
& dotnet build
Assert-ExitCode 'Building'
```

To show text that may hold a URL a caller gave, hide its credential first:

```powershell
Hide-UrlCredential -Text 'Cloning https://x-access-token:ghs_abc@github.com/o/r'
# Cloning https://***@github.com/o/r
```

A secret that is not part of a URL, and has to travel as an argument,
is hidden by naming it. `Hide-MaskedValue` replaces each given value with `***`:

```powershell
Hide-MaskedValue -Text "Signing in with $password" -Mask $password
# Signing in with ***
```

`Invoke-NativeCommand` and `Invoke-NativeRead` take the same values as `-Mask`
and hide them wherever the call shows them. `-Mask` takes plain text:
a `SecureString` is refused, since it would hide only its type name.

For a tool that may echo a configuration or a credential it was not given,
`Invoke-NativeCommand -HideOutput` leaves what the tool printed out of the
failure message; the message still names the activity, the command line,
and the exit code.

## Good to know

- `-Argument` is also accepted as `-Arguments`. The arguments of a PowerShell
  function, cmdlet, or script are positional: `@('-Y', 'why')` binds `-Y` as
  the first positional value, not as the parameter `-Y`.
- A wildcard character in `-Command` is part of the name: only a command of
  exactly that name, or a file at exactly that path, is run, never another one
  the name would match as a pattern.
- `-Verbose` writes the command line to the verbose stream before the
  command runs, with the credential a URL carries and the `-Mask` values
  hidden. What goes to `-StdIn` and the values of `-Environment` are never
  shown. A caller's own `-Verbose`, or its `$VerbosePreference`, reaches the
  call even from another module.
- Every failure message hides the credential a URL carries, as in
  `https://x-access-token:<token>@github.com/o/r`, through
  `Hide-UrlCredential` - in the activity, in each word of the command
  line, in each line the command printed, and in a path. A secret that is
  not part of a URL is shown as it is unless `-Mask` names it, and it belongs
  in `-StdIn` where the tool allows. `-Mask` hides each value wherever the
  message shows it, and does not change what the command returns or what an
  error raised by a PowerShell function run as the command says. A very short
  value is not masked; the command's help says how short. What
  `Invoke-NativeRead` returns is kept exactly as printed; only its verbose
  line hides the `-Mask` values.
- `Hide-UrlCredential` errs toward hiding too much: an @ after a colon,
  such as in an e-mail address after `HOST:PORT` or a drive letter, hides
  everything up to it. A password holding `://` and a user name holding a
  slash are hidden only after them.
- The command never reads the console. Without `-StdIn` its input is
  already at its end, so a tool that asks a question gets no answer
  instead of hanging, unseen, on one.
- Output is decoded as UTF-8, and the console's code pages are pinned to
  UTF-8 for the call, so a tool that writes to the console's code page
  writes UTF-8, and one that reads `-StdIn` through it reads UTF-8. A tool
  that always writes UTF-16 or a legacy code page comes back garbled.
- Merged output keeps the order the lines arrived in. With `-Environment`
  or `-TimeoutSeconds` the command runs as a process of its own, and merged
  output is then all of stdout followed by all of stderr.
- Without `-Environment` or `-TimeoutSeconds`, a PowerShell function or
  alias with the command's name runs ahead of the executable,
  as it would at the prompt.
- Without `-Environment` or `-TimeoutSeconds`, an argument that is exactly
  `--%` is refused for a program, because PowerShell drops it there even
  quoted. With either, it is passed as it is.
- A Windows batch file (`.cmd`, `.bat`) has its arguments parsed again by
  cmd.exe. Without `-Environment` or `-TimeoutSeconds` an empty one is
  dropped. An argument holding any of `"` `&` `|` `<` `>` `^` `%` -
  even a single `%` - is refused with a throw, because there those
  characters would run commands, redirect, or expand variables; the
  arguments are joined into one command line, so a `%` in one can pair
  with a `%` in the next. Call the program's real `.exe`, or pass the
  value through `-StdIn`, `-Environment`, or a file.

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

A piped value that fails to bind, such as a value that cannot become a string,
is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that value without a word;
the values before it were already handled.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Invoke-NativeCommand`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

`Invoke-NativeRead` returns a result with `Ok = $false` instead of throwing
for anything the command does:
a non-zero exit, a command that cannot be started, or a timeout.
A mistake in the call itself still throws.

PowerShell's default error view quotes the line of the calling script,
so a secret written literally in that line is shown there;
give a secret by variable.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.ProcessInvocation\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
