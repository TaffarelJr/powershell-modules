using namespace System.IO

# Shared by this module's tests: a throwaway folder, empty test files to find,
# and a stand-in for the coverage wrapper that says what a test wants it to.
# A test-only fixture - nothing here is exported.

function New-TestRunnerSandbox {
    <#
    .SYNOPSIS
        Creates an empty folder under the temp folder for one test to work in.
    .OUTPUTS
        The folder's full path.
    #>
    $path = Join-Path ([Path]::GetTempPath()) "testrunner-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Remove-TestRunnerSandbox {
    <#
    .SYNOPSIS
        Deletes a folder New-TestRunnerSandbox made.
    .PARAMETER Path
        The folder.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
}

function New-TestFileStub {
    <#
    .SYNOPSIS
        Writes an empty <Name>.Tests.ps1, making its folder if need be.
        Whatever runs it is a stand-in wrapper, so it never needs content.
    .PARAMETER Directory
        The folder to put it in.
    .PARAMETER Name
        The file's name without the .Tests.ps1 suffix.
    .OUTPUTS
        The file's full path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Name
    )

    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $path = Join-Path $Directory "$Name.Tests.ps1"
    Set-Content -LiteralPath $path -Value ''
    return $path
}

function New-FakeWrapper {
    <#
    .SYNOPSIS
        Writes a script standing in for Invoke-TestFile.ps1, with its four
        parameters, so a test exercises discovery, orchestration and reporting
        without the real Pester coverage machinery.
    .PARAMETER Directory
        The folder to put it in.
    .PARAMETER Body
        What the script does, as text. It sees $TestFile, $SourceRoot,
        $OutputPath and $ResultPath.
    .OUTPUTS
        The script's full path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Body
    )

    $path = Join-Path $Directory "wrapper-$([Guid]::NewGuid()).ps1"
    $header = 'param([string]$TestFile, [string]$SourceRoot, [string]$OutputPath, [string]$ResultPath)'
    Set-Content -LiteralPath $path -Value ($header + [Environment]::NewLine + $Body)
    return $path
}

function New-FakePester {
    <#
    .SYNOPSIS
        Writes a module named Pester, of the given version, that only says it
        was loaded - so a test can see which Pester a child process imported
        without depending on the Pester versions this machine has.
    .PARAMETER Directory
        The folder to put the module's own Pester folder in.
    .PARAMETER Version
        The version its manifest declares.
    .OUTPUTS
        The manifest's full path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $folder = Join-Path $Directory 'Pester'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $manifest = Join-Path $folder 'Pester.psd1'
    Set-Content -LiteralPath $manifest -Value "@{ RootModule = 'Pester.psm1'; ModuleVersion = '$Version' }"
    Set-Content -LiteralPath (Join-Path $folder 'Pester.psm1') -Value "Write-Host 'fake Pester $Version loaded'"
    return $manifest
}

function Invoke-WithSeam {
    <#
    .SYNOPSIS
        Runs a script block with one of a module's own functions replaced,
        then puts the original back, even when the block throws.
    .PARAMETER Module
        The module whose function is replaced.
    .PARAMETER Name
        The function's name.
    .PARAMETER Replacement
        The body the function has while the block runs.
    .PARAMETER ScriptBlock
        The code to run.
    .OUTPUTS
        Whatever the script block writes.
    #>
    param(
        [Parameter(Mandatory)]
        [psmoduleinfo]$Module,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Replacement,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    # Read out now: replacing a function changes its FunctionInfo in place.
    $original = & $Module { param($Function) Get-Item -LiteralPath "function:$Function" -ErrorAction Ignore } $Name
    $isOwn = $null -ne $original -and $original.ModuleName -eq $Module.Name
    $originalBody = if ($isOwn) { $original.ScriptBlock }
    $setFunction = { param($Function, $Body) Set-Item -LiteralPath "function:script:$Function" -Value $Body }
    & $Module $setFunction $Name $Replacement
    try {
        & $ScriptBlock
    }
    finally {
        # A cmdlet, or a command another module exports, is shadowed, not
        # replaced, so taking the shadow away is what puts it back.
        if ($isOwn) {
            & $Module $setFunction $Name $originalBody
        }
        else {
            # Dot-sourced, so it runs in the module's own scope: Remove-Item
            # ignores a scope in a function: path.
            . $Module { param($Function) Remove-Item -LiteralPath "function:$Function" } $Name
        }
    }
}

function Get-TestKitFileContent {
    <#
    .SYNOPSIS
        Returns the text of a small test file that imports TestKit by its path,
        runs the given lines, and ends the way every TestKit file does.
    .PARAMETER Body
        The lines between the import and the exit.
    .PARAMETER NoExit
        Leaves the file without its closing exit statement.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Body,

        [switch]$NoExit
    )

    $root = (Get-Item -LiteralPath $PSScriptRoot).Parent.Parent.FullName
    $testKit = Join-Path $root 'src' 'TaffarelJr.TestKit' 'TaffarelJr.TestKit.psd1'
    $lines = @("Import-Module '$testKit' -Force", $Body)
    if (-not $NoExit) {
        $lines += 'exit (Complete-TestRun)'
    }

    return $lines -join [Environment]::NewLine
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
    param()

    $null = New-Module -Name TestRunnerVerboseCallers -ScriptBlock {
        function Invoke-FileProcessCaller {
            [CmdletBinding()]
            param($Call)

            Invoke-TestFileProcess @Call
        }

        function Invoke-RunCaller {
            [CmdletBinding()]
            param($Call)

            Invoke-TestRun @Call 6>$null
        }
    }
}
