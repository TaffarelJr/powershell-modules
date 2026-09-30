#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
foreach ($name in 'Tally', 'ConsoleOutput', 'ProcessInvocation', 'RequiredModules', 'TestRunner') {
    Import-Module (Join-Path $repoRoot 'src' "TaffarelJr.$name" "TaffarelJr.$name.psd1") -Force
}
$module = Get-Module TaffarelJr.TestRunner

#───────────────────────────────────────────────────────────────────────────────
# Act
$path = & $module { Get-TestFileWrapperPath }

# Assert
Assert-Equal -Expected (Join-Path $module.ModuleBase 'Scripts' 'Invoke-TestFile.ps1') -Actual $path `
    -Message 'The wrapper is the module''s own Scripts/Invoke-TestFile.ps1, under its base folder'
Assert-That -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Message 'and the file is there'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the module built into one file, where $PSScriptRoot would be the module root
$out = Join-Path ([Path]::GetTempPath()) "wrapper-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    $null = & (Join-Path $repoRoot 'build' 'Build-Module.ps1') -Name 'TaffarelJr.TestRunner' -OutputPath $out
    $built = Join-Path $out 'TaffarelJr.TestRunner'
    $srcRoot = Join-Path $repoRoot 'src'

    # Act - in a child with the dependencies on its module path, so this process keeps its own TestRunner
    $probe = "`$env:PSModulePath = '$srcRoot' + [IO.Path]::PathSeparator + `$env:PSModulePath; " +
        "Import-Module '$(Join-Path $built 'TaffarelJr.TestRunner.psd1')' -Force; " +
        "& (Get-Module TaffarelJr.TestRunner) { Get-TestFileWrapperPath }"
    $output = @(& pwsh -NoProfile -NonInteractive -Command $probe 2>&1 | ForEach-Object { "$_" })

    # Assert
    Assert-Equal -Expected (Join-Path $built 'Scripts' 'Invoke-TestFile.ps1') -Actual $output[-1] `
        -Message 'From a single-file build the wrapper is still found under the module''s base folder'
}
finally {
    Remove-Item -LiteralPath $out -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
