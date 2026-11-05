using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text

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
        with empty ones, and ProgramW6432 and ProgramFiles(x86) are removed.
        Only this process's environment changes. Remove-VSCodeSandbox puts
        all of it back.
    .OUTPUTS
        A fixture object for the other functions here.
    #>
    [CmdletBinding()]
    param()

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
        OriginalProgramW6432    = $env:ProgramW6432
        OriginalProgramFilesX86 = ${env:ProgramFiles(x86)}
    }

    $env:PATH = $bin
    $env:LOCALAPPDATA = $localAppData
    $env:ProgramFiles = $programFiles
    [Environment]::SetEnvironmentVariable('ProgramW6432', $null, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $null, 'Process')
    return $fixture
}

function Reset-VSCodeSandbox {
    <#
    .SYNOPSIS
        Empties the sandbox's install folders and PATH, so the next case
        starts with nothing installed.
    .PARAMETER Fixture
        The object New-VSCodeSandbox returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    foreach ($folder in $Fixture.LocalAppData, $Fixture.ProgramFiles) {
        Get-ChildItem -LiteralPath $folder | Remove-Item -Recurse -Force
    }

    $env:PATH = $Fixture.Bin
    [Environment]::SetEnvironmentVariable('ProgramW6432', $null, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramFiles(x86)', $null, 'Process')
}

function Get-VSCodeEditionTable {
    <#
    .SYNOPSIS
        Returns the imported module's own edition table, so a test follows
        the real folder and executable names instead of a copy of them.
    .OUTPUTS
        The table's entries (Name, Cli, Exe, Folder), Stable first.
    #>
    [CmdletBinding()]
    param()

    $module = Get-Module -Name TaffarelJr.VSCode
    if ($null -eq $module) {
        throw 'Import TaffarelJr.VSCode before asking for its edition table.'
    }

    $editions = & $module { $script:VSCodeEditions }
    return $editions
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
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        '',
        Justification = 'Read by the script block or child process the test hands it to, by scope.')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture,

        [ValidateSet('Stable', 'Insiders')]
        [string]$Edition = 'Stable',

        [ValidateSet('LocalAppData', 'ProgramFiles')]
        [string]$Location = 'LocalAppData'
    )

    $known = @(Get-VSCodeEditionTable).Where({ $_.Name -eq $Edition })[0]
    $base = Join-Path $Fixture.LocalAppData 'Programs'
    if ($Location -eq 'ProgramFiles') {
        $base = $Fixture.ProgramFiles
    }

    $folder = Join-Path $base $known.Folder
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $path = Join-Path $folder $known.Exe
    [File]::WriteAllText($path, '')
    return $path
}

function Add-FakeVSCodeShim {
    <#
    .SYNOPSIS
        Lays out a VS Code install folder holding only its bin\ CLI shim -
        no executable beside it - and puts that bin folder on PATH.
    .DESCRIPTION
        The shim is a batch file that writes its first argument, quotes
        stripped, to received.txt beside itself, after writing the folder it
        started in to cwd.txt, so a test can see what a launch through it
        delivered.
    .PARAMETER Fixture
        The object New-VSCodeSandbox returned.
    .PARAMETER FileName
        The shim's file name: code.cmd as VS Code ships it, or another name
        to test a shim the lookup must not take.
    .OUTPUTS
        An object with Shim (the batch file), Received and WorkingDirectory
        (the files it writes), and InstallRoot (the folder the executable
        would sit in).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture,

        [string]$FileName = 'code.cmd'
    )

    $installRoot = Join-Path $Fixture.Root "install-$([Guid]::NewGuid())"
    $bin = Join-Path $installRoot 'bin'
    New-Item -ItemType Directory -Path $bin | Out-Null
    $shim = Join-Path $bin $FileName
    [File]::WriteAllText($shim, "@echo off`r`n>`"%~dp0cwd.txt`" echo %CD%`r`n>`"%~dp0received.txt`" echo %~1`r`n")
    $env:PATH = $bin
    return [PSCustomObject]@{
        Shim             = $shim
        Received         = Join-Path $bin 'received.txt'
        WorkingDirectory = Join-Path $bin 'cwd.txt'
        InstallRoot      = $installRoot
    }
}

function Remove-VSCodeSandbox {
    <#
    .SYNOPSIS
        Restores the environment New-VSCodeSandbox replaced and deletes the
        sandbox.
    .PARAMETER Fixture
        The object New-VSCodeSandbox returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    $env:PATH = $Fixture.OriginalPath
    [Environment]::SetEnvironmentVariable('LOCALAPPDATA', $Fixture.OriginalLocalAppData, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramFiles', $Fixture.OriginalProgramFiles, 'Process')
    [Environment]::SetEnvironmentVariable('ProgramW6432', $Fixture.OriginalProgramW6432, 'Process')
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
    [CmdletBinding()]
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
        One object per launch (Executable, Argument), oldest first.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    $launches = & $Module { $script:FakeLaunches.ToArray() }
    return $launches
}

function New-SettingsFolder {
    <#
    .SYNOPSIS
        Creates a folder holding a .vscode/settings.json with the given text,
        and returns the folder's path.
    .PARAMETER Root
        The folder to create it in.
    .PARAMETER Name
        The new folder's name.
    .PARAMETER Content
        The settings file's text, written exactly as given.
    .PARAMETER Encoding
        The encoding to write it in; UTF-8 without a byte order mark when
        omitted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,

        [Encoding]$Encoding = [UTF8Encoding]::new($false)
    )

    $folder = Join-Path $Root $Name
    New-Item -ItemType Directory -Path (Join-Path $folder '.vscode') | Out-Null
    [File]::WriteAllText((Join-Path $folder '.vscode' 'settings.json'), $Content, $Encoding)
    return $folder
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
    [CmdletBinding()]
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
    [CmdletBinding()]
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
