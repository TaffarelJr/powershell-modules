# TaffarelJr.FileText

Reads and writes text files
without disturbing their existing encoding or line ending,
and replaces a placeholder token across a whole directory tree -
file content, file names, and directory names.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.FileText
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.FileText

$file = Read-TextFile -Path ./README.md
Write-TextFile -Path ./README.md -Content ($file.Content -replace 'old', 'new')

Rename-Token -Path . -From 'Placeholder' -To 'MyProject'
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- Text that is not valid UTF-8 and has no byte order mark - Windows-1252, say -
  is refused rather than read with replacement characters that a rewrite would
  make permanent. Pass `-Encoding` to `Read-TextFile` and `Write-TextFile` to
  handle such a file as what it is. `-Encoding` takes a
  `System.Text.Encoding` object, not a name such as `utf8`.
- `Write-TextFile` encodes the whole text before it opens the file, so text
  the encoding cannot hold throws and leaves the file as it was. It writes an
  existing file in place, so a hidden file can be written and stays hidden.
  A folder that is missing is an error unless `-CreateDirectory` says to make
  it, and a file another program holds open or a read-only file is named in
  the error with the reason.
- `Read-TextFile`, `Get-FileEncoding`, and `Update-FileToken` take path
  strings, `Resolve-Path` output, and files from `Get-ChildItem` piped in.
  A folder in the pipeline throws and stops it,
  so list with `Get-ChildItem -File`.
- `Rename-Token` never follows a symbolic link or junction, and does not enter
  a folder named in `-Exclude` (whole names, no wildcards). A link whose
  target holds the token is named in its `Warning` output, since the target
  is never rewritten.
- With `-Verbose`, `Write-TextFile`, `Update-FileToken`, and `Rename-Token`
  name each file they write and each item they rename, never a file's text.
- `-WhatIf`, `-Confirm`, `-Verbose`, and the warning for a binary file show
  the text `Update-FileToken` is asked to replace (`-From`).
  `Rename-Token` shows `-From` in its previews, warnings, and errors,
  and the names `-To` makes in its previews and errors.
  A secret should not be given where that output is kept.

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
A piped value that fails to bind, such as an empty string,
is the exception: that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Read-TextFile`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

`Rename-Token` does not stop at the first failure:
it carries on with the other items,
and throws once at the end, naming each one it could not change.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified (`TaffarelJr.FileText\<Command>`)
or import the module with `-Prefix` to keep them apart.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
