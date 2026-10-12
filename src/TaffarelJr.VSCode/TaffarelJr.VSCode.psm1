#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Where each edition installs: the CLI shim on PATH, the exe it sits beside,
# and the usual install folder. Order matters - Stable is tried before
# Insiders.
$script:VSCodeEditions = @(
    @{
        Name   = 'Stable'
        Cli    = 'code'
        Exe    = 'Code.exe'
        Folder = 'Microsoft VS Code'
    }
    @{
        Name   = 'Insiders'
        Cli    = 'code-insiders'
        Exe    = 'Code - Insiders.exe'
        Folder = 'Microsoft VS Code Insiders'
    }
)

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Get-VSCodeExecutable'
    'New-VSCodeWorkspaceFile'
    'Start-VSCode'
)
