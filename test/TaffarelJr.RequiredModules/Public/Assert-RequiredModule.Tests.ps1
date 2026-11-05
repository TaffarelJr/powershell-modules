#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets and reads the caller-session state the code under test uses.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The in-process cases replace Install-RequiredModule with Use-AssertSeam's
# stand-in, or keep it and reach the stand-in Install-Module, so nothing is
# downloaded or installed. The last cases run in a fresh non-interactive
# process with a CI variable set, the way CI does.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
$notFoundTail = 'was installed but is still not found - is the install location on PSModulePath?'
$appear = {
    param($installing)
    New-FakeModule -Root $sandbox -Name $installing.Name -Version $installing.MinimumVersion.ToString()
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module installed at 2.0.0, and manifests needing it at 1.0.0
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$satisfiedPath = New-ManifestFile -Directory $sandbox -Name 'satisfied.psd1' `
    -Content "@{ 'Probe.Present' = @{ MinimumVersion = '1.0.0' } }"
$satisfiedData = @{ 'Probe.Present' = @{ MinimumVersion = '1.0.0' } }
Use-AssertSeam -Module $module

# Act
$byPath = Invoke-Capturing { Assert-RequiredModule -Path $satisfiedPath }
$byData = Invoke-Capturing { Assert-RequiredModule -Data $satisfiedData }
$piped = Invoke-Capturing { $satisfiedData | Assert-RequiredModule }

# Assert
Assert-That -Condition ($null -eq $byPath.Error) -Message 'An already-satisfied manifest file does not throw'
Assert-That -Condition ($null -eq $byData.Error) -Message 'An already-satisfied hashtable manifest does not throw'
Assert-That -Condition ($null -eq $piped.Error) -Message 'A piped, already-satisfied hashtable manifest does not throw'
Assert-Equal -Expected @() -Actual ($byPath.Output + $byData.Output + $piped.Output) `
    -Message 'A satisfied manifest prints nothing'
Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A satisfied manifest installs nothing'

#───────────────────────────────────────────────────────────────────────────────
# Act - a path and a hashtable given by position, and a file piped in
$positionalPath = Invoke-Capturing { Assert-RequiredModule $satisfiedPath }
$positionalData = Invoke-Capturing { Assert-RequiredModule $satisfiedData }
$pipedFile = Invoke-Capturing { Get-Item -LiteralPath $satisfiedPath | Assert-RequiredModule }

# Assert
Assert-That -Condition ($null -eq $positionalPath.Error) -Message 'A path given by position is read as -Path'
Assert-That -Condition ($null -eq $positionalData.Error) -Message 'A hashtable given by position is read as -Data'
Assert-That -Condition ($null -eq $pipedFile.Error) -Message 'A piped file is read by its full name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Path and -Data together is ambiguous, not a merge
Assert-Throws -ScriptBlock {
    Assert-RequiredModule -Path $satisfiedPath -Data @{}
} -ExceptionType ([System.Management.Automation.ParameterBindingException]) -Message '-Path and -Data together throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module that is not installed, and an install that works
Use-AssertSeam -Module $module -OnInstall $appear
$wantedData = @{ 'Probe.Wanted' = @{ MinimumVersion = '1.0.0' } }

# Act
$wanted = Invoke-Capturing { Assert-RequiredModule -Data $wantedData }

# Assert
Assert-Equal -Expected @('Probe.Wanted 1.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A missing module is installed, at its minimum version, without a question'
Assert-Equal -Expected $null -Actual $wanted.Error -Message 'and nothing fails once it is found'
Assert-Equal -Expected @('Installing Probe.Wanted 1.0.0 or later ... ', 'done') -Actual $wanted.Output `
    -Message 'and the install is reported as it happens'
Assert-Equal -Expected @() -Actual $wanted.Warnings -Message 'and nothing is warned'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two modules missing and one older than needed, in one manifest
Use-AssertSeam -Module $module -OnInstall $appear
New-FakeModule -Root $sandbox -Name 'Probe.Old' -Version '2.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Fine' -Version '1.0.0'
$severalData = @{
    'Probe.Zulu'  = @{ MinimumVersion = '1.0.0' }
    'Probe.Old'   = @{ MinimumVersion = '5.0.0' }
    'Probe.Alpha' = @{ MinimumVersion = '2.0.0' }
    'Probe.Fine'  = @{ MinimumVersion = '1.0.0' }
}

# Act
$several = Invoke-Capturing { Assert-RequiredModule -Data $severalData }

# Assert
Assert-Equal -Expected @('Probe.Alpha 2.0.0', 'Probe.Old 5.0.0', 'Probe.Zulu 1.0.0') `
    -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'Every module that is missing or too old is installed, in name order, and none that is satisfied'
Assert-Equal -Expected $null -Actual $several.Error -Message 'and nothing fails once they are all found'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a missing module named like a member of the dictionary that holds
# the modules still to check
Use-AssertSeam -Module $module -OnInstall $appear
$memberNamedData = @{ Keys = @{ MinimumVersion = '1.0.0' } }

# Act
$memberNamed = Invoke-Capturing { Assert-RequiredModule -Data $memberNamedData }

# Assert
Assert-Equal -Expected @('Keys 1.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A missing module named Keys is installed like any other'
Assert-Equal -Expected $null -Actual $memberNamed.Error -Message 'and nothing fails once it is found'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one module missing and one satisfied, counting how often the
# module path is scanned
Use-AssertSeam -Module $module -OnInstall $appear
$countedData = @{
    'Probe.Counted' = @{ MinimumVersion = '1.0.0' }
    'Probe.Fine'    = @{ MinimumVersion = '1.0.0' }
}
& $module {
    $script:ScanCount = 0
    $script:RealScan = ${function:Get-InstalledModuleVersion}
    function script:Get-InstalledModuleVersion {
        param($Name, $MinimumVersion)
        $script:ScanCount++
        & $script:RealScan @PSBoundParameters
    }
}

# Act
$null = Invoke-Capturing { Assert-RequiredModule -Data $countedData }
$scans = & $module { $script:ScanCount }
& $module { ${function:script:Get-InstalledModuleVersion} = $script:RealScan }

# Assert
Assert-Equal -Expected 3 -Actual $scans `
    -Message 'Each module is looked up once, and an installed one once more to check the install'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a missing module in a manifest piped before a satisfied one
Use-AssertSeam -Module $module -OnInstall $appear
$firstData = @{ 'Probe.PipedFirst' = @{ MinimumVersion = '1.0.0' } }

# Act
$null = Invoke-Capturing { $firstData, $satisfiedData | Assert-RequiredModule }

# Assert
Assert-Equal -Expected @('Probe.PipedFirst 1.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A missing module piped before a satisfied manifest is not skipped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a missing module in a manifest piped after a satisfied one
Use-AssertSeam -Module $module -OnInstall $appear
$lastData = @{ 'Probe.PipedLast' = @{ MinimumVersion = '1.0.0' } }

# Act
$null = Invoke-Capturing { $satisfiedData, $lastData | Assert-RequiredModule }

# Assert
Assert-Equal -Expected @('Probe.PipedLast 1.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A missing module piped after a satisfied manifest is not skipped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - missing modules in two different piped manifests
Use-AssertSeam -Module $module -OnInstall $appear
$bad = @{ 'Probe.Missing' = @{ MinimumVersion = '1.0.0' } }
$otherBad = @{ 'Probe.AlsoMissing' = @{ MinimumVersion = '3.0.0' } }

# Act
$null = Invoke-Capturing { $bad, $satisfiedData, $otherBad | Assert-RequiredModule }

# Assert
Assert-Equal -Expected @('Probe.AlsoMissing 3.0.0', 'Probe.Missing 1.0.0') `
    -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'Modules missing from different piped manifests are installed in one run, in name order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one module required by two piped manifests at different minimums,
# installed between the two, the lower minimum first
Use-AssertSeam -Module $module -OnInstall $appear
New-FakeModule -Root $sandbox -Name 'Probe.Shared' -Version '1.5.0'
$lower = @{ 'Probe.Shared' = @{ MinimumVersion = '1.0.0' } }
$higher = @{ 'probe.shared' = @{ MinimumVersion = '2.0.0' } }

# Act
$null = Invoke-Capturing { $lower, $higher | Assert-RequiredModule }

# Assert
Assert-Equal -Expected @('probe.shared 2.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A module required twice, in any casing, is installed once, at the higher minimum, as its entry writes it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same, the higher minimum first
Use-AssertSeam -Module $module -OnInstall $appear
New-FakeModule -Root $sandbox -Name 'Probe.Twice' -Version '1.5.0'
$lower = @{ 'Probe.Twice' = @{ MinimumVersion = '1.0.0' } }
$higher = @{ 'probe.twice' = @{ MinimumVersion = '2.0.0' } }

# Act
$null = Invoke-Capturing { $higher, $lower | Assert-RequiredModule }

# Assert
Assert-Equal -Expected @('probe.twice 2.0.0') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'The higher minimum wins whichever manifest comes first'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module loaded by its path at a version that meets the minimum, and a count of the PSModulePath scans
Use-AssertSeam -Module $module
New-FakeModule -Root "$sandbox-outside" -Name 'Probe.Loose' -Version '3.0.0'
$null = Import-Module (Join-Path "$sandbox-outside" 'Probe.Loose' '3.0.0' 'Probe.Loose.psd1') -Global -Force
$looseData = @{ 'Probe.Loose' = @{ MinimumVersion = '1.0.0' } }
& $module {
    $script:ListScans = 0
    function script:Get-Module {
        if ($args -contains '-ListAvailable') {
            $script:ListScans++
        }

        Microsoft.PowerShell.Core\Get-Module @args
    }
}

# Act
$loose = Invoke-Capturing { Assert-RequiredModule -Data $looseData }
$looseScans = & $module { $script:ListScans }

# Assert
Assert-That -Condition ($null -eq $loose.Error) -Message 'A module loaded at a good enough version needs nothing'
Assert-Equal -Expected 0 -Actual $looseScans -Message 'and PSModulePath is not scanned to find that out'
Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs -Message 'and nothing is installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module named with no minimum version, missing, and one installed at some version
$appearAnyVersion = {
    param($installing)
    New-FakeModule -Root $sandbox -Name $installing.Name -Version '1.0.0'
}
Use-AssertSeam -Module $module -OnInstall $appearAnyVersion
New-FakeModule -Root $sandbox -Name 'Probe.Anything' -Version '0.0.1'
$anyData = @{
    'Probe.Anything'  = @{}
    'Probe.NoMinimum' = @{ DocumentationUrl = 'https://example.test' }
}

# Act
$any = Invoke-Capturing { Assert-RequiredModule -Data $anyData }

# Assert
Assert-Equal -Expected @('Probe.NoMinimum ') -Actual (Get-AssertSeamRecord -Module $module).Installs `
    -Message 'A module with no minimum version is installed when it is missing, and not when any version is there'
Assert-Equal -Expected $null -Actual $any.Error -Message 'and nothing fails once it is found'
Assert-Equal -Expected @('Installing Probe.NoMinimum ... ', 'done') -Actual $any.Output `
    -Message 'and the install is reported without a version'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one module with no minimum in one manifest and a minimum in another, either way round
$unversioned = @{ 'Probe.Dupe' = @{} }
$versioned = @{ 'probe.dupe' = @{ MinimumVersion = '2.0.0' } }

# Act
Use-AssertSeam -Module $module -OnInstall $appear
$null = Invoke-Capturing { $unversioned, $versioned | Assert-RequiredModule }
$noneFirst = (Get-AssertSeamRecord -Module $module).Installs
Remove-Item -LiteralPath (Join-Path $sandbox 'probe.dupe') -Recurse -Force
Use-AssertSeam -Module $module -OnInstall $appear
$null = Invoke-Capturing { $versioned, $unversioned | Assert-RequiredModule }
$noneLast = (Get-AssertSeamRecord -Module $module).Installs

# Assert
Assert-Equal -Expected @('probe.dupe 2.0.0') -Actual $noneFirst `
    -Message 'A minimum version beats having none, when the manifest with none comes first'
Assert-Equal -Expected @('probe.dupe 2.0.0') -Actual $noneLast -Message 'and when it comes last'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an install that fails the way Install-Module does, for the first
# of two missing modules, one of them installed too old
Use-AssertSeam -Module $module -RealInstall
$global:FakeInstallCalls.Clear()
$global:FakeInstallFailure = "No match was found for the specified search criteria and module name 'Probe.Broken'."
New-FakeModule -Root $sandbox -Name 'Probe.Broken' -Version '0.5.0'
$brokenData = @{
    'Probe.Broken' = @{ MinimumVersion = '1.0.0'; DocumentationUrl = 'https://example.test' }
    'Probe.Later'  = @{ MinimumVersion = '1.0.0' }
}
$brokenMessage = @(
    "Could not install Probe.Broken 1.0.0 or later: $global:FakeInstallFailure"
    'Probe.Broken 1.0.0 or later is required, but only 0.5.0 is installed.'
    'Install it with: Install-Module -Name Probe.Broken -MinimumVersion 1.0.0 -Scope CurrentUser ' +
    '-Force -SkipPublisherCheck'
    'Docs: https://example.test'
) -join "`n"

# Act
Assert-FakeInstaller -Module $module
$broken = Invoke-Capturing { Assert-RequiredModule -Data $brokenData }
$global:FakeInstallFailure = $null
$brokenCalls = @($global:FakeInstallCalls | ForEach-Object { $_.Name })

# Assert
Assert-Equal -Expected $brokenMessage -Actual $broken.Error.Exception.Message `
    -Message 'A failed install throws with the installer''s reason, what is wrong, the command to run and the docs'
Assert-Equal -Expected @('Probe.Broken') -Actual $brokenCalls `
    -Message 'and stops there, before the next module'
Assert-Equal -Expected @('Installing Probe.Broken 1.0.0 or later ... ', 'failed') -Actual $broken.Output `
    -Message 'and the install is reported as failed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an install that leaves the module still not found
Use-AssertSeam -Module $module
$ghostData = @{ 'Probe.Ghost' = @{ MinimumVersion = '1.0.0' } }

# Act
$notFound = Invoke-Capturing { Assert-RequiredModule -Data $ghostData }

# Assert
Assert-Equal `
    -Expected ("Probe.Ghost 1.0.0 or later $notFoundTail") `
    -Actual $notFound.Error.Exception.Message `
    -Message 'An install that does not make the module available throws, not a later step without a cause'
Assert-Equal -Expected @('Installing Probe.Ghost 1.0.0 or later ... ', 'failed') -Actual $notFound.Output `
    -Message 'and the install is reported as failed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an install that leaves only a version below the minimum
Use-AssertSeam -Module $module -OnInstall {
    param($installing)
    New-FakeModule -Root $sandbox -Name $installing.Name -Version '0.9.0'
}
$staleData = @{ 'Probe.Stale' = @{ MinimumVersion = '2.0.0' } }
$staleMessage = 'Probe.Stale 2.0.0 or later was installed but only 0.9.0 is found - ' +
'is the install location on PSModulePath?'

# Act
$stale = Invoke-Capturing { Assert-RequiredModule -Data $staleData }

# Assert
Assert-Equal `
    -Expected $staleMessage `
    -Actual $stale.Error.Exception.Message `
    -Message 'An install that leaves the module too old throws, naming the version found'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fresh non-interactive process with a CI variable set, reading a
# manifest from a folder with an apostrophe in its name
$quotedFolder = New-Item -ItemType Directory -Path (Join-Path $sandbox "O'Brien")

# Act
$ci = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $quotedFolder 'ci') -NonInteractive `
    -Name 'Probe.Zulu', 'Probe.Alpha'

# Assert
Assert-Equal -Expected 'Probe.Alpha 1.0.0|Probe.Zulu 1.0.0' -Actual $ci.Installs `
    -Message 'Where no one can answer, every missing module is installed without a question'
Assert-Equal -Expected $null -Actual $ci.Error -Message 'and nothing fails'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same, through the module's own Install-RequiredModule
$ciReal = Invoke-AssertProcess -Module $module -Sandbox (Join-Path $quotedFolder 'ci-real') -NonInteractive `
    -RealInstall

# Assert
Assert-Equal -Expected 'Probe.Child' -Actual $ciReal.ModuleInstall `
    -Message 'Where no one can answer, Install-Module is reached without a prompt'
Assert-Equal `
    -Expected ("Probe.Child 1.0.0 or later $notFoundTail") `
    -Actual $ciReal.Error `
    -Message 'and the check after it runs (the stand-in Install-Module makes no module appear)'

# Cleanup
Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
