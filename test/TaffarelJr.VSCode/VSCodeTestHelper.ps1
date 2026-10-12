using namespace System.IO
using namespace System.Management.Automation

# Shared by this module's tests: an isolated place for VS Code's install
# lookup to search, a stand-in for the one function that launches a process,
# and small capture helpers. A test-only fixture - nothing here is exported.

function New-VSCodeSandbox {
    <#
    .SYNOPSIS
        Points VS Code's install lookup at empty folders, so a test sees only
        what it puts there and never the real install on this machine.
    .DESCRIPTION
        PATH is replaced with one empty folder, LOCALAPPDATA and ProgramFiles
        with empty ones, and ProgramFiles(x86) is removed. Remove-VSCodeSandbox
        puts all of it back.
    .OUTPUTS
        A fixture object for the other functions here.
    #>
    $root = Join-Path ([Path]::GetTempPath()) "vscode-sandbox-$([Guid]::NewGuid())"
    $bin = Join-Path $root 'bin'
    $localAppData = Join-Path $root 'LocalAppData'
    $programFiles = Join-Path $root 'ProgramFiles'
    foreach ($folder in $bin, $localAppData, $programFiles) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }

    $fixture = [PSCustomObject]@{
        Root                    = $root
        Bin                     = $bin
        LocalAppData            = $localAppData
        ProgramFiles            = $programFiles
        OriginalPath            = $env:PATH
        OriginalLocalAppData    = $env:LOCALAPPDATA
        OriginalProgramFiles    = $env:ProgramFiles
        OriginalProgramFilesX86 = ${env:ProgramFiles(x86)}
    }

    $env:PATH = $bin
    $env:LOCALAPPDATA = $localAppData
    $env:ProgramFiles = $programFiles
    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $null, 'Process')
    return $fixture
}

function Reset-VSCodeSandbox {
    <#
    .SYNOPSIS
        Empties the sandbox's install folders, so the next case starts with
        nothing installed.
    .PARAMETER Fixture
        The object New-VSCodeSandbox returned.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    foreach ($folder in $Fixture.LocalAppData, $Fixture.ProgramFiles) {
        Get-ChildItem -LiteralPath $folder | Remove-Item -Recurse -Force
    }

    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $null, 'Process')
}

function Add-FakeVSCode {
    <#
    .SYNOPSIS
        Puts an empty stand-in for an installed VS Code executable where the
        lookup expects one, and returns its path.
    .PARAMETER Fixture
        The object New-VSCodeSandbox returned.
    .PARAMETER Edition
        Stable or Insiders.
    .PARAMETER Location
        LocalAppData (a per-user install, under Programs) or ProgramFiles
        (a machine-wide one).
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture,

        [ValidateSet('Stable', 'Insiders')]
        [string]$Edition = 'Stable',

        [ValidateSet('LocalAppData', 'ProgramFiles')]
        [string]$Location = 'LocalAppData'
    )

    $folderName = if ($Edition -eq 'Stable') { 'Microsoft VS Code' } else { 'Microsoft VS Code Insiders' }
    $exeName = if ($Edition -eq 'Stable') { 'Code.exe' } else { 'Code - Insiders.exe' }
    $base = if ($Location -eq 'LocalAppData') { Join-Path $Fixture.LocalAppData 'Programs' } else { $Fixture.ProgramFiles }
    $folder = Join-Path $base $folderName
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $path = Join-Path $folder $exeName
    [File]::WriteAllText($path, '')
    return $path
}

function Remove-VSCodeSandbox {
    <#
    .SYNOPSIS
        Restores the environment New-VSCodeSandbox replaced and deletes the
        sandbox.
    .PARAMETER Fixture
        The object New-VSCodeSandbox returned.
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    $env:PATH = $Fixture.OriginalPath
    [Environment]::SetEnvironmentVariable('LOCALAPPDATA', $Fixture.OriginalLocalAppData, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramFiles', $Fixture.OriginalProgramFiles, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $Fixture.OriginalProgramFilesX86, 'Process')
    Remove-Item -LiteralPath $Fixture.Root -Recurse -Force -ErrorAction SilentlyContinue
}

function Install-FakeVSCodeLauncher {
    <#
    .SYNOPSIS
        Replaces the module's one process-launching function with a recorder,
        so a test can see what would have been launched without launching it.
    .DESCRIPTION
        Each test file runs in its own process, so the replacement never needs
        undoing. Pass -Throw to make the stand-in fail the way a real launch
        can.
    .PARAMETER Module
        The imported TaffarelJr.VSCode module.
    .PARAMETER Throw
        Makes the stand-in throw instead of recording.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [switch]$Throw
    )

    & $Module {
        param($shouldThrow)
        $script:FakeLaunches = [System.Collections.Generic.List[object]]::new()
        $script:FakeLaunchShouldThrow = $shouldThrow
        function script:Start-VSCodeProcess {
            param($Executable, $Argument)
            if ($script:FakeLaunchShouldThrow) {
                throw 'the launch failed'
            }

            $script:FakeLaunches.Add([PSCustomObject]@{
                    Executable = $Executable
                    Argument   = $Argument
                })
        }
    } $Throw.IsPresent
}

function Get-FakeVSCodeLaunch {
    <#
    .SYNOPSIS
        Returns every launch the stand-in recorded, oldest first.
    .PARAMETER Module
        The imported TaffarelJr.VSCode module.
    .OUTPUTS
        One object per launch (Executable, Argument), always an array.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    $launches = & $Module { $script:FakeLaunches.ToArray() }
    return , @($launches)
}

function Get-WarningText {
    <#
    .SYNOPSIS
        Runs a script block and returns the text of each warning it wrote.
    .PARAMETER ScriptBlock
        The code to run.
    .OUTPUTS
        One string per warning, always an array.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $records = & $ScriptBlock 3>&1
    $messages = foreach ($record in $records) {
        if ($record -is [WarningRecord]) {
            $record.Message
        }
    }

    return , @($messages)
}

function Get-ErrorMessage {
    <#
    .SYNOPSIS
        Runs a script block and returns the message it threw, or $null if it
        did not throw.
    .PARAMETER ScriptBlock
        The code to run.
    #>
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    try {
        $null = & $ScriptBlock
        return $null
    }
    catch {
        return $_.Exception.Message
    }
}

function Read-WorkspaceFile {
    <#
    .SYNOPSIS
        Parses a .code-workspace file, so a test can assert on what VS Code
        would read rather than on the text that produced it.
    .DESCRIPTION
        ConvertFrom-Json accepts the comments and trailing commas a
        .code-workspace file is allowed to carry.
    .PARAMETER Path
        The workspace file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $text = [File]::ReadAllText($Path)
    return ConvertFrom-Json -InputObject $text
}

function Wait-TestFile {
    <#
    .SYNOPSIS
        Waits for a file to appear with something in it, for a process a test
        started and cannot wait on directly.
    .PARAMETER Path
        The file to wait for.
    .PARAMETER TimeoutSeconds
        How long to wait before giving up.
    .OUTPUTS
        $true once the file exists and is not empty, $false on timeout.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [int]$TimeoutSeconds = 60
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ((Test-Path -LiteralPath $Path) -and (Get-Item -LiteralPath $Path).Length -gt 0) {
            return $true
        }

        Start-Sleep -Milliseconds 100
    }

    return $false
}
