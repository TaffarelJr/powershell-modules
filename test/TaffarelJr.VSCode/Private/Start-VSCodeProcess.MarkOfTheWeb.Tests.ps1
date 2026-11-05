#Requires -Version 7.4
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Management.Automation.Language

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')

# The mark of the web is an NTFS stream that only Windows' shell honors.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the mark of the web is a Windows shell check')
}

# A stand-in for a downloaded Code.exe: a copy of a harmless program, marked
# as coming from the internet, the way Explorer marks every file it extracts
# from a downloaded .zip. The apostrophe stands for a per-user install under
# a profile such as C:\Users\O'Brien.
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$install = Join-Path $root "Microsoft VS Code (O'Brien)"
New-Item -ItemType Directory -Path $install | Out-Null
$standIn = Join-Path $install 'Code.exe'
Copy-Item -LiteralPath (Join-Path ([Environment]::SystemDirectory) 'whoami.exe') -Destination $standIn
Set-Content -LiteralPath $standIn -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3"

# Only a machine whose policy enforces the mark can show the refusal.
$probe = [ProcessStartInfo]::new($standIn)
$probe.UseShellExecute = $true
$enforced = $false
try {
    $process = [Process]::Start($probe)
    $process.Dispose()
}
catch [ComponentModel.Win32Exception] {
    $enforced = $_.Exception.NativeErrorCode -eq 1223
}

if (-not $enforced) {
    Remove-Item -LiteralPath $root -Recurse -Force
    exit (Skip-TestRun -Reason 'this machine starts a file marked as downloaded without asking')
}

$originalElectronMode = $env:ELECTRON_RUN_AS_NODE
$quotedInstall = $install -replace "'", "''"
$folderPattern = [WildcardPattern]::Escape("Get-ChildItem -LiteralPath '$quotedInstall' -Recurse | Unblock-File")
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a caller inside VS Code's own extension host
    $env:ELECTRON_RUN_AS_NODE = '1'

    # Act / Assert
    $escaped = [WildcardPattern]::Escape($standIn)
    Assert-Throws -ScriptBlock {
        Start-VSCodeProcess -Executable $standIn -Argument @('/?')
    } -MessageLike "*will not start '$escaped'*mark of the web*$folderPattern*" `
        -Message 'An executable marked as downloaded is refused with the command that unblocks its install folder'
    Assert-Equal -Expected '1' -Actual $env:ELECTRON_RUN_AS_NODE `
        -Message 'and ELECTRON_RUN_AS_NODE is put back for the caller after the refused start'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the command the message offers, pasted as PowerShell
    $message = try {
        Start-VSCodeProcess -Executable $standIn -Argument @('/?')
    }
    catch {
        $_.Exception.Message
    }

    $command = [regex]::Match($message, "Get-ChildItem -LiteralPath '.*' -Recurse \| Unblock-File").Value
    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseInput($command, [ref]$tokens, [ref]$errors)
    $quoted = $ast.FindAll({ param($node) $node -is [StringConstantExpressionAst] }, $true).Where({
            $_.StringConstantType -eq 'SingleQuoted'
        }, 'First')

    # Assert
    Assert-Equal -Expected 0 -Actual $errors.Count `
        -Message 'The offered command parses, though the folder holds an apostrophe'
    Assert-Equal -Expected @($install) -Actual @($quoted.Value) -Message 'and names the install folder exactly'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with a typographic apostrophe, which PowerShell also
    # reads as a single quote
    $curlyInstall = Join-Path $root "Microsoft VS Code (O`u{2019}Brien)"
    New-Item -ItemType Directory -Path $curlyInstall | Out-Null
    $curlyStandIn = Join-Path $curlyInstall 'Code.exe'
    Copy-Item -LiteralPath $standIn -Destination $curlyStandIn
    Set-Content -LiteralPath $curlyStandIn -Stream Zone.Identifier -Value "[ZoneTransfer]`r`nZoneId=3"

    # Act
    $message = try {
        Start-VSCodeProcess -Executable $curlyStandIn -Argument @('/?')
    }
    catch {
        $_.Exception.Message
    }

    $command = [regex]::Match($message, "Get-ChildItem -LiteralPath '.*' -Recurse \| Unblock-File").Value
    $tokens = $null
    $errors = $null
    $ast = [Parser]::ParseInput($command, [ref]$tokens, [ref]$errors)
    $quoted = $ast.FindAll({ param($node) $node -is [StringConstantExpressionAst] }, $true).Where({
            $_.StringConstantType -eq 'SingleQuoted'
        }, 'First')

    # Assert
    Assert-That -Condition ($command -ne '') -Message 'The message offers the unblock command'
    Assert-Equal -Expected 0 -Actual $errors.Count `
        -Message 'The offered command parses, though the folder holds a typographic apostrophe'
    Assert-Equal -Expected @($curlyInstall) -Actual @($quoted.Value) -Message 'and names that install folder exactly'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a caller that never had it
    [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCodeProcess -Executable $standIn -Argument @('/?')
    } -MessageLike '*mark of the web*' -Message 'The refusal repeats for a caller without ELECTRON_RUN_AS_NODE'
    Assert-That -Condition (-not (Test-Path -LiteralPath 'Env:\ELECTRON_RUN_AS_NODE')) `
        -Message 'and ELECTRON_RUN_AS_NODE is not created by the refused start'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - what the message says to do
    Get-ChildItem -LiteralPath $install -Recurse | Unblock-File

    # Act
    $result = Start-VSCodeProcess -Executable $standIn -Argument @('/?')

    # Assert
    Assert-Equal -Expected $null -Actual $result -Message 'and once unblocked it starts'
}
finally {
    [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $originalElectronMode, 'Process')
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
