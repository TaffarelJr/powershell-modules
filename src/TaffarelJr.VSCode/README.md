# TaffarelJr.VSCode

Finds and launches Visual Studio Code, and authors multi-root
`.code-workspace` files: folders, settings (optionally mirrored from a
folder's own `.vscode/settings.json`), and recommended extensions.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.VSCode
```

Requires PowerShell 7.4 or later.

## Usage

```powershell
Import-Module TaffarelJr.VSCode

$workspace = New-VSCodeWorkspaceFile -Path ./my-repo/my-repo.code-workspace `
    -Folder ./my-repo, ./shared-lib `
    -MirrorSettingsFrom ./my-repo `
    -Setting @{ 'editor.rulers' = @(80, 120) }

Start-VSCode -Path $workspace
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.

## Good to know

- A relative path is taken from PowerShell's current location, and
  `Start-VSCode` starts the editor there too. A blank path, or one outside the
  file system, such as one under `Env:\` or the registry, is refused.
- `Start-VSCode` does not wait for the editor, and does not hand it the
  session's console streams, so a caller whose output is captured is not kept
  waiting either.
- Past `PATH`, the install folders searched are Windows ones: under
  `LOCALAPPDATA\Programs`, `ProgramFiles`, `ProgramW6432`, and
  `ProgramFiles(x86)`. On macOS and Linux the `code` command has to be on
  `PATH`. Other builds of the editor, such as VSCodium or code-oss, are not
  looked for.
- When only VS Code's `bin\code.cmd` shim is found, with no `Code.exe` beside
  its bin folder, a path holding a character `cmd.exe` would misread
  (`& | < > ^ % " !`) is refused rather than launched.
- A VS Code extracted from a downloaded `.zip` carries the mark of the web,
  which Windows will not start from `Start-VSCode`; the error names the
  `Unblock-File` call that fixes it.
- A workspace folder has to be an existing folder, given once; a blank one is
  refused. Folders are stored relative to the workspace file, except one on
  another drive or share.
- A multi-line `-Comment` becomes one `//` line per line.
- A `-Setting` value has to be something JSON can hold; values read with
  `ConvertFrom-Json` qualify, and a whole settings file read with
  `ConvertFrom-Json -AsHashtable` passes in. Pass an `[ordered]` dictionary to
  control the key order written.
- `-MirrorSettingsFrom` copies the object in `.vscode/settings.json` as text,
  comments and key order intact; a brace inside a note or a string is not taken
  for its edge. Workspace settings apply to every folder in the workspace, so
  the copied settings reach the other folders too, wherever they do not set
  the same key themselves. A file that is not valid UTF-8 text (Windows-1252,
  say), a file PowerShell's JSON reader cannot parse, or a key also given in
  `-Setting` is refused; looseness VS Code itself flags, such as unquoted keys
  or single-quoted strings, is copied as written. A `-Setting` with a blank
  name is refused too.

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

`New-VSCodeWorkspaceFile` and `Start-VSCode` gather their pipeline input first
and act on it at the end,
so a failing record means no file was written and nothing was launched.
A piped value that fails to bind, such as `$null` for a path,
is the exception: that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,New-VSCodeWorkspaceFile`;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.

## Name collisions

Another module may export a command with the same name,
and the last one imported wins.
Call the command module-qualified (`TaffarelJr.VSCode\<Command>`)
or import the module with `-Prefix` to keep them apart.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
