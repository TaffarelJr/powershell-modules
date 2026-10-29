#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Everything this module needs is loaded, and so is TestKit, which the runner
# does not need, and which a caller is free to have loaded.
$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Act
$names = @(& $module { Get-WorkerModulePath } | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })

# Assert
Assert-Equal -Expected 'TaffarelJr.TestRunner' -Actual $names[-1] -Message 'The module itself comes last'
foreach ($required in 'Tally', 'ConsoleOutput', 'ProcessInvocation', 'RequiredModules') {
    Assert-That -Condition ($names -contains "TaffarelJr.$required") `
        -Message "TaffarelJr.$required, which the runner needs, is listed"
}

Assert-That -Condition ($names -notcontains 'TaffarelJr.TestKit') `
    -Message 'A module the runner does not need is not listed, however loaded it is'
Assert-Equal -Expected $names.Count -Actual @($names | Sort-Object -Unique).Count `
    -Message 'Each module is listed once'

#───────────────────────────────────────────────────────────────────────────────
# Act - what each path is
$paths = @(& $module { Get-WorkerModulePath })

# Assert
Assert-That -Condition (-not ($paths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })) `
    -Message 'Every path is a file that exists, the one the module was loaded from'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - four throwaway modules, where A requires B and C, and both of those
# require D, so the chain is two levels deep and D is reached by two routes
$scratch = Join-Path ([IO.Path]::GetTempPath()) "workerpath-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $scratch | Out-Null
$chain = @(
    @{ Name = 'WorkerPathD'; Requires = @() }
    @{ Name = 'WorkerPathB'; Requires = @('WorkerPathD') }
    @{ Name = 'WorkerPathC'; Requires = @('WorkerPathD') }
    @{ Name = 'WorkerPathA'; Requires = @('WorkerPathB', 'WorkerPathC') }
)
try {
    foreach ($link in $chain) {
        $required = foreach ($name in $link.Requires) {
            "@{ ModuleName = '$name'; ModuleVersion = '1.0.0' }"
        }

        $manifestPath = Join-Path $scratch "$($link.Name).psd1"
        Set-Content -LiteralPath (Join-Path $scratch "$($link.Name).psm1") -Value ''
        Set-Content -LiteralPath $manifestPath -Value @(
            '@{'
            "    RootModule      = '$($link.Name).psm1'"
            "    ModuleVersion   = '1.0.0'"
            "    GUID            = '$([Guid]::NewGuid())'"
            "    RequiredModules = @($($required -join ', '))"
            '}'
        )
        Import-Module $manifestPath -Force
    }

    # Act - the real function, run as if it were part of the top module
    $function = & $module { ${function:Get-WorkerModulePath} }
    $chained = @(& (Get-Module WorkerPathA) $function | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })

    # Assert
    Assert-Equal -Expected 'WorkerPathA' -Actual $chained[-1] -Message 'The module itself comes last'
    Assert-Equal -Expected 4 -Actual $chained.Count -Message 'Each module is listed once, though two modules require D'
    Assert-That -Condition ($chained.IndexOf('WorkerPathD') -lt $chained.IndexOf('WorkerPathB')) `
        -Message 'A module comes after the one it requires, however deep the chain'
    Assert-That -Condition ($chained.IndexOf('WorkerPathD') -lt $chained.IndexOf('WorkerPathC')) `
        -Message 'whichever of its dependents it is reached from first'
    Assert-That -Condition ($chained.IndexOf('WorkerPathB') -lt $chained.IndexOf('WorkerPathA')) `
        -Message 'and every module after the ones it requires'
    Assert-That -Condition ($chained.IndexOf('WorkerPathC') -lt $chained.IndexOf('WorkerPathA')) `
        -Message 'on every route'
}
finally {
    Remove-Module -Name WorkerPathA, WorkerPathB, WorkerPathC, WorkerPathD -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
