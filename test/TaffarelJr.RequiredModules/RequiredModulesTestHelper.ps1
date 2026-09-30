using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation

# Shared by this module's tests: a throwaway folder, modules "installed" into
# it, manifest files, stand-ins for the installers, and a fresh process to run
# Assert-RequiredModule in. A test-only fixture - nothing here is exported.

function New-RequiredModulesSandbox {
    <#
    .SYNOPSIS
        Creates an empty folder under the temp folder for one test file to work in,
        and makes PSModulePath that folder plus PowerShell's own modules only.
    .DESCRIPTION
        Nothing the machine has installed is listed then, so no answer depends
        on it, and Windows PowerShell's module folder cannot hand a built-in
        module to the compatibility session.

        PowerShell finds a module anywhere below a PSModulePath folder, so a module
        that must not be found there - one a test imports by its path - goes in
        the sibling folder named like this one plus "-outside", which is not on it.

        Each test file runs in its own process, but Remove-RequiredModulesSandbox
        still puts PSModulePath back.
    .OUTPUTS
        The folder's full path.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path ([Path]::GetTempPath()) "requiredmodules-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null
    $script:SavedModulePath = $env:PSModulePath
    $env:PSModulePath = $path + [Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
    return $path
}

function Remove-RequiredModulesSandbox {
    <#
    .SYNOPSIS
        Deletes a folder New-RequiredModulesSandbox made, and its "-outside"
        sibling, and restores PSModulePath.
    .PARAMETER Path
        The folder.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $env:PSModulePath = $script:SavedModulePath
    Remove-Item -LiteralPath $Path, "$Path-outside" -Recurse -Force -ErrorAction SilentlyContinue
}

function Use-FakeInstaller {
    <#
    .SYNOPSIS
        Replaces Install-Module, Update-Module, Install-PSResource and
        Update-PSResource for the whole session, so nothing a test runs can
        install or update a module or reach the Gallery.
    .DESCRIPTION
        The stand-in Install-Module adds each call to $global:FakeInstallCalls
        and, while $global:FakeInstallFailure holds a message, fails with it the
        way PowerShellGet does: a non-terminating error, unless the caller passes
        -ErrorAction. Like the real one, it follows the session's -WhatIf and
        -Confirm preferences unless the call passes its own: under -WhatIf it
        records nothing, and where the real one would ask for confirmation it
        throws instead, so a test fails rather than waits for an answer.
        The stand-in Update-Module does the same with $global:FakeUpdateCalls
        and $global:FakeUpdateFailure.
        Install-PSResource and Update-PSResource always throw: nothing here
        calls them.

        Imported into the global session as a module of its own, not defined in
        the test file: Install-RequiredModule looks the command up from its own
        module, and under the coverage wrapper a test file runs nested inside
        Pester, where a function of the file's own scope is not visible. The
        preference is set inside the fake module because a script block from a
        test file would carry that file's 'Stop' with it.

        Ends with Assert-FakeInstaller, so a fake that did not take over
        stops the test file before anything can reach the real installer.
    .PARAMETER Module
        The imported TaffarelJr.RequiredModules module, handed on to
        Assert-FakeInstaller.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidGlobalVars',
        '',
        Justification = 'The test sets and reads the caller-session state the code under test uses.')]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    $global:FakeInstallCalls = [List[object]]::new()
    $global:FakeInstallFailure = $null
    $global:FakeUpdateCalls = [List[object]]::new()
    $global:FakeUpdateFailure = $null
    $null = New-Module -Name FakeInstaller -ScriptBlock {
        $ErrorActionPreference = 'Continue'

        function Install-Module {
            [CmdletBinding(SupportsShouldProcess)]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSAvoidGlobalVars',
                '',
                Justification = 'The test sets and reads the caller-session state the code under test uses.')]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSAvoidOverwritingBuiltInCmdlets',
                '',
                Justification = 'The test replaces the command so the code under test runs unchanged.')]
            param(
                $Name,
                $MinimumVersion,
                $Scope,
                [switch]$Force,
                [switch]$SkipPublisherCheck
            )

            if ($ConfirmPreference -ne 'None' -and $ConfirmPreference -le 'Medium') {
                throw "Install-Module would have asked to confirm installing $Name."
            }

            if (-not $PSCmdlet.ShouldProcess($Name, 'Install-Module')) {
                return
            }

            $global:FakeInstallCalls.Add([PSCustomObject]@{
                    Name               = $Name
                    MinimumVersion     = $MinimumVersion
                    Scope              = $Scope
                    Force              = $Force.IsPresent
                    SkipPublisherCheck = $SkipPublisherCheck.IsPresent
                })
            if ($global:FakeInstallFailure) {
                Write-Error $global:FakeInstallFailure
            }
        }

        function Update-Module {
            [CmdletBinding(SupportsShouldProcess)]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSAvoidGlobalVars',
                '',
                Justification = 'The test sets and reads the caller-session state the code under test uses.')]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSAvoidOverwritingBuiltInCmdlets',
                '',
                Justification = 'The test replaces the command so the code under test runs unchanged.')]
            param(
                $Name,
                [switch]$Force
            )

            if ($ConfirmPreference -ne 'None' -and $ConfirmPreference -le 'Medium') {
                throw "Update-Module would have asked to confirm updating $Name."
            }

            if (-not $PSCmdlet.ShouldProcess($Name, 'Update-Module')) {
                return
            }

            $global:FakeUpdateCalls.Add([PSCustomObject]@{
                    Name  = $Name
                    Force = $Force.IsPresent
                })
            if ($global:FakeUpdateFailure) {
                Write-Error $global:FakeUpdateFailure
            }
        }

        function Install-PSResource {
            throw 'Install-PSResource is blocked in this test session.'
        }

        function Update-PSResource {
            throw 'Update-PSResource is blocked in this test session.'
        }
    } | Import-Module -Global

    Assert-FakeInstaller -Module $Module
}

function Assert-FakeInstaller {
    <#
    .SYNOPSIS
        Throws unless Install-Module, Update-Module, Install-PSResource and
        Update-PSResource resolve to the stand-ins from Use-FakeInstaller.
    .DESCRIPTION
        PowerShellGet sits in PowerShell's own module folder, which the
        sandbox keeps on PSModulePath: if the fake failed to import, or
        anything imported PowerShellGet after it, the real Install-Module
        would answer and reach the Gallery. Call this right before anything
        that may install. Each command is looked up from inside the module,
        so a stand-in the module cannot see does not count. Only the aliases
        and functions already loaded are looked at, so nothing is run or
        imported: a command whose module is not loaded resolves to nothing,
        and still fails the check.
    .PARAMETER Module
        The imported TaffarelJr.RequiredModules module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    foreach ($name in 'Install-Module', 'Update-Module', 'Install-PSResource', 'Update-PSResource') {
        # Get-Command would import the module that defines a command not yet
        # loaded - the real installer - whatever the autoloading preference.
        $command = & $Module {
            param($commandName)
            foreach ($drive in 'alias', 'function') {
                $item = Get-Item -LiteralPath "${drive}:$commandName" -ErrorAction Ignore
                if ($item) {
                    return $item
                }
            }
        } $name
        $owner = if ($null -eq $command) {
            'nothing'
        }
        elseif ($command -is [AliasInfo]) {
            "an alias of $($command.Definition)"
        }
        elseif ($command.Source) {
            $command.Source
        }
        else {
            'a function outside any module'
        }

        if ($owner -ne 'FakeInstaller') {
            throw "$name resolves to $owner, not the test stand-in - stopping before anything can be installed."
        }
    }
}

function New-FakeModule {
    <#
    .SYNOPSIS
        "Installs" a module: a real manifest and script under
        <Root>/<Name>/<Version>, where PSModulePath finds it.
    .DESCRIPTION
        Its one command, Get-FakeModuleState, returns the name, the version, and a
        value picked each time the module is loaded, so a test can tell which
        version answered and a reload from no reload.
    .PARAMETER Root
        A folder on PSModulePath, from New-RequiredModulesSandbox.
    .PARAMETER Name
        The module's name.
    .PARAMETER Version
        The module's version.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $folder = Join-Path $Root $Name $Version
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $script = '$script:State = [Guid]::NewGuid().ToString()' + [Environment]::NewLine +
    'function Get-FakeModuleState { return "' + $Name + ' ' + $Version + ' " + $script:State }'
    Set-Content -LiteralPath (Join-Path $folder "$Name.psm1") -Value $script
    $manifest = "@{ RootModule = '$Name.psm1'; ModuleVersion = '$Version'; " +
    "GUID = '$([Guid]::NewGuid())'; FunctionsToExport = @('Get-FakeModuleState') }"
    Set-Content -LiteralPath (Join-Path $folder "$Name.psd1") -Value $manifest
}

function New-ManifestFile {
    <#
    .SYNOPSIS
        Writes a manifest file holding the given text.
    .PARAMETER Directory
        The folder to put it in.
    .PARAMETER Content
        What the file says.
    .PARAMETER Name
        The file's name. Defaults to RequiredModules.psd1.
    .OUTPUTS
        The file's full path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Content,

        [string]$Name = 'RequiredModules.psd1'
    )

    $path = Join-Path $Directory $Name
    Set-Content -LiteralPath $path -Value $Content
    return $path
}

function Invoke-Capturing {
    <#
    .SYNOPSIS
        Runs a script block and returns what it threw, warned, and printed with
        Write-Host, so a test can check all three from one run.
    .PARAMETER ScriptBlock
        The code to run. Anything else it outputs is discarded.
    .OUTPUTS
        An object with Error (the ErrorRecord, or $null when nothing was thrown),
        Warnings (each warning's text) and Output (each Write-Host call's text).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $thrown = $null
    $records = try {
        & $ScriptBlock 3>&1 6>&1
    }
    catch {
        $thrown = $_
    }

    $warnings = [List[string]]::new()
    $output = [List[string]]::new()
    foreach ($record in $records) {
        if ($record -is [WarningRecord]) {
            $warnings.Add($record.Message)
        }
        elseif ($record -is [InformationRecord]) {
            $data = $record.MessageData
            $text = if ($data -is [HostInformationMessage]) { $data.Message } else { "$data" }
            $output.Add($text)
        }
    }

    return [PSCustomObject]@{
        Error    = $thrown
        Warnings = $warnings.ToArray()
        Output   = $output.ToArray()
    }
}

function Use-AssertSeam {
    <#
    .SYNOPSIS
        Replaces Install-RequiredModule, as Assert-RequiredModule calls it,
        with a stand-in that records the call, and empties the record.
    .DESCRIPTION
        Each test file runs in its own process, so the replacement never needs
        undoing; -RealInstall puts the module's own function back. The
        module's own Test-RequiredModule and Get-InstalledModuleVersion stay
        real, looking at the sandbox.
    .PARAMETER Module
        The imported TaffarelJr.RequiredModules module.
    .PARAMETER OnInstall
        Runs when Install-RequiredModule is called, to make the module appear.
        It is given the module being installed.
    .PARAMETER RealInstall
        Leaves the module's own Install-RequiredModule in place, so it reaches
        the stand-in Install-Module from Use-FakeInstaller, which records the
        call but makes no module appear. OnInstall is not run then.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [scriptblock]$OnInstall = {},

        [switch]$RealInstall
    )

    & $Module {
        param($onInstall, $realInstall)
        if ($null -eq (Get-Variable -Name SeamRealInstall -Scope Script -ErrorAction Ignore)) {
            $script:SeamRealInstall = ${function:Install-RequiredModule}
        }

        $script:SeamInstalls = [List[string]]::new()
        $script:SeamOnInstall = $onInstall
        if ($realInstall) {
            ${function:script:Install-RequiredModule} = $script:SeamRealInstall
            return
        }

        function script:Install-RequiredModule {
            param($Module)
            $script:SeamInstalls.Add("$($Module.Name) $($Module.MinimumVersion)")
            & $script:SeamOnInstall $Module
        }
    } $OnInstall ([bool]$RealInstall)
}

function Get-AssertSeamRecord {
    <#
    .SYNOPSIS
        Returns what the stand-in from Use-AssertSeam was asked to install.
    .PARAMETER Module
        The imported TaffarelJr.RequiredModules module.
    .OUTPUTS
        An object with Installs: each install, as the module's name and
        minimum version ('Probe.Name 1.0.0'), in the order asked.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    return & $Module {
        [PSCustomObject]@{ Installs = $script:SeamInstalls.ToArray() }
    }
}

function Invoke-AssertProcess {
    <#
    .SYNOPSIS
        Runs Assert-RequiredModule in a fresh pwsh process, with a CI variable
        set and the stand-ins from Use-FakeInstaller and Use-AssertSeam in
        place, and returns what happened there.
    .DESCRIPTION
        A confirmation prompt can only be answered, or shown to fail where
        no one can answer, outside the test's own process. The process gets
        the manifest as a file in -Sandbox, which it puts first on
        PSModulePath, and the stand-in Install-RequiredModule makes each
        module appear there at its minimum version.
    .PARAMETER Module
        The imported TaffarelJr.RequiredModules module: the process imports
        the same manifest.
    .PARAMETER Sandbox
        A folder of its own for the run: it is created, and must not exist.
    .PARAMETER Name
        The modules the manifest names, each at minimum version 1.0.0.
    .PARAMETER Answer
        The lines the process reads as input, one per confirmation prompt.
        None by default.
    .PARAMETER NonInteractive
        Starts pwsh with -NonInteractive, where a prompt throws.
    .PARAMETER WithConfirm
        Passes -Confirm to Assert-RequiredModule.
    .PARAMETER SessionConfirmPreference
        The process's global $ConfirmPreference. High, PowerShell's own
        default, by default.
    .PARAMETER RealInstall
        Uses the module's own Install-RequiredModule, which reaches the
        stand-in Install-Module and so makes no module appear.
    .OUTPUTS
        An object with Error (the message Assert-RequiredModule threw, or
        $null), Installs (what the stand-in Install-RequiredModule installed,
        joined with '|') and ModuleInstall (the names the stand-in
        Install-Module was called with, joined with '|').
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Sandbox,

        [string[]]$Name = @('Probe.Child'),

        [string[]]$Answer = @(),

        [switch]$NonInteractive,

        [switch]$WithConfirm,

        [string]$SessionConfirmPreference = 'High',

        [switch]$RealInstall
    )

    $null = New-Item -ItemType Directory -Path $Sandbox
    $entries = foreach ($moduleName in $Name) {
        "'$moduleName' = @{ MinimumVersion = '1.0.0' }"
    }
    $manifest = New-ManifestFile -Directory $Sandbox -Content "@{ $($entries -join '; ') }"
    $script = New-ManifestFile -Directory $Sandbox -Name 'Invoke-Assert.ps1' -Content @'
param($ModulePath, $HelperPath, $Sandbox, $ManifestPath, $Preference, [switch]$Confirm, [switch]$RealInstall)
$ErrorActionPreference = 'Stop'
$module = Import-Module $ModulePath -Force -PassThru
. $HelperPath
$env:PSModulePath = $Sandbox + [IO.Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
$env:CI = 'true'
Use-FakeInstaller -Module $module
Use-AssertSeam -Module $module -RealInstall:$RealInstall -OnInstall {
    param($installing)
    New-FakeModule -Root $Sandbox -Name $installing.Name -Version $installing.MinimumVersion.ToString()
}
$switches = @{}
if ($Confirm) {
    $switches['Confirm'] = $true
}
$global:ConfirmPreference = $Preference
$thrown = try {
    Assert-RequiredModule -Path $ManifestPath @switches 6>$null
}
catch {
    $_.Exception.Message
}
[PSCustomObject]@{
    Error         = $thrown
    Installs      = (Get-AssertSeamRecord -Module $module).Installs -join '|'
    ModuleInstall = @($global:FakeInstallCalls | ForEach-Object { $_.Name }) -join '|'
} | ConvertTo-Json -Compress
'@

    $modulePath = Join-Path $Module.ModuleBase "$($Module.Name).psd1"
    $pwshPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $arguments = [List[string]]::new()
    $arguments.Add('-NoProfile')
    if ($NonInteractive) {
        $arguments.Add('-NonInteractive')
    }

    $arguments.AddRange([string[]]@(
            '-File', $script,
            '-ModulePath', $modulePath,
            '-HelperPath', $PSCommandPath,
            '-Sandbox', $Sandbox,
            '-ManifestPath', $manifest,
            '-Preference', $SessionConfirmPreference
        ))
    if ($WithConfirm) {
        $arguments.Add('-Confirm')
    }

    if ($RealInstall) {
        $arguments.Add('-RealInstall')
    }

    $lines = @($Answer | & $pwshPath @arguments 2>&1)
    $json = $lines | Where-Object { "$_" -like '{*' } | Select-Object -Last 1
    if ($null -eq $json) {
        throw "The child process printed no result: $($lines -join "`n")"
    }

    return $json | ConvertFrom-Json
}

function Get-NonInteractiveError {
    <#
    .SYNOPSIS
        Runs a command in a fresh pwsh process that cannot be asked anything,
        and returns the error it raised.
    .DESCRIPTION
        A call that leaves out a mandatory parameter is asked for it in an
        interactive host, so a test of that call has to run where no one can
        answer.
    .PARAMETER Module
        The imported TaffarelJr.RequiredModules module: the process imports
        the same one.
    .PARAMETER Command
        The command line to run once the module is imported.
    .PARAMETER Directory
        A folder to put the script in.
    .OUTPUTS
        An object with Type (the name of the exception's type) and Message,
        or $null when the command raised nothing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter(Mandatory)]
        [string]$Directory
    )

    $modulePath = Join-Path $Module.ModuleBase "$($Module.Name).psd1"
    $scriptPath = Join-Path $Directory "probe-$([Guid]::NewGuid()).ps1"
    Set-Content -LiteralPath $scriptPath -Value @(
        'param($ModulePath)'
        '$ErrorActionPreference = ''Stop'''
        'Import-Module $ModulePath -Force'
        'try {'
        "    $Command"
        '}'
        'catch {'
        '    [PSCustomObject]@{ Type = $_.Exception.GetType().Name; Message = $_.Exception.Message } |'
        '        ConvertTo-Json -Compress'
        '}'
    )
    $pwshPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $lines = @(& $pwshPath -NoProfile -NonInteractive -File $scriptPath -ModulePath $modulePath 2>&1)
    $json = $lines | Where-Object { "$_" -like '{*' } | Select-Object -Last 1
    if ($null -eq $json) {
        return $null
    }

    return $json | ConvertFrom-Json
}

function Install-VerboseCaller {
    <#
    .SYNOPSIS
        Imports a module of its own whose functions call this module's public
        functions, as a command of another module does.
    .DESCRIPTION
        -Verbose and the verbose preference of a function in one module do not
        reach a command in another by themselves, so these callers show whether
        this module reads the preference of whoever calls it. Each test file
        runs in its own process, so the module never needs removing.
    #>
    [CmdletBinding()]
    param()

    $null = New-Module -Name RequiredModulesVerboseCallers -ScriptBlock {
        function Invoke-InstallCaller {
            [CmdletBinding()]
            param($Module)

            Install-RequiredModule -Module $Module
        }

        function Invoke-AssertCaller {
            [CmdletBinding()]
            param($Data)

            Assert-RequiredModule -Data $Data
        }
    }
}
