# TaffarelJr.VSCode

Finds and launches Visual Studio Code, and authors multi-root
`.code-workspace` files: folders, settings (optionally mirrored from a
folder's own `.vscode/settings.json`), and recommended extensions.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.VSCode
```

## Usage

```powershell
Import-Module TaffarelJr.VSCode

$workspace = New-VSCodeWorkspaceFile -Path ./my-repo/my-repo.code-workspace `
    -Folder ./my-repo, ./shared-lib `
    -MirrorSettingsFrom ./my-repo `
    -Settings @{ 'editor.rulers' = @(80, 120) }

Start-VSCode -Path $workspace
```

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for parameters and examples.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
