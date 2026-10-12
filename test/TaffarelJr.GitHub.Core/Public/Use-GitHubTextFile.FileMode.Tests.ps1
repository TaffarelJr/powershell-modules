#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

if ($IsWindows) {
    exit (Skip-TestRun -Reason 'a Unix file mode exists only on Linux and macOS')
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$mode = Use-GitHubTextFile -Text 'a body' -ScriptBlock {
    param($Path)
    [System.IO.File]::GetUnixFileMode($Path)
}

# Assert
Assert-Equal -Expected ([System.IO.UnixFileMode]'UserRead, UserWrite') -Actual $mode `
    -Message 'The file is readable and writable by its owner alone, whatever the umask lets others see'

exit (Complete-TestRun)
