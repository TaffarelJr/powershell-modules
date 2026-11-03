#Requires -Version 7.4
using namespace System.IO
using namespace System.Management.Automation.Language

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$build = Join-Path $repoRoot 'build' 'Build-Module.ps1'

# Fixture modules of the test's own, in a source root of their own: Alpha has
# module state, overlapping usings, a Scripts/ folder and a variable export;
# Beta uses $PSScriptRoot; Gamma does not parse.
$root = Join-Path ([Path]::GetTempPath()) "build-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
$src = Join-Path $root 'src'
$out = Join-Path $root 'out'

function New-FixtureModule {
    <#
    .SYNOPSIS
        Writes a fixture module folder with a manifest, root .psm1, README and
        CHANGELOG, plus the given files.
    .PARAMETER Name
        The module name.
    .PARAMETER Root
        The root .psm1 text.
    .PARAMETER Files
        Relative path to content, for the function files and anything else.
    .PARAMETER Exports
        The function names the manifest exports.
    .PARAMETER Variables
        The variable names the manifest exports.
    #>
    param(
        [string]$Name,
        [string]$Root,
        [hashtable]$Files,
        [string[]]$Exports,
        [string[]]$Variables = @()
    )

    $folder = Join-Path $src $Name
    $null = New-Item -ItemType Directory -Path $folder -Force
    $exportList = ($Exports | ForEach-Object { "'$_'" }) -join ', '
    $variableList = ($Variables | ForEach-Object { "'$_'" }) -join ', '
    Set-Content -LiteralPath (Join-Path $folder "$Name.psd1") -Value @"
@{
    RootModule = '$Name.psm1'
    ModuleVersion = '0.1.0'
    GUID = '$([Guid]::NewGuid())'
    Author = 'Test'
    Description = 'A fixture.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @($exportList)
    CmdletsToExport = @()
    VariablesToExport = @($variableList)
    AliasesToExport = @()
}
"@
    Set-Content -LiteralPath (Join-Path $folder "$Name.psm1") -Value $Root
    Set-Content -LiteralPath (Join-Path $folder 'README.md') -Value "# $Name"
    Set-Content -LiteralPath (Join-Path $folder 'CHANGELOG.md') -Value '# Changelog'
    foreach ($entry in $Files.GetEnumerator()) {
        $path = Join-Path $folder $entry.Key
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
        Set-Content -LiteralPath $path -Value $entry.Value
    }
}

$alphaRoot = @'
#Requires -Version 7.4
using namespace System.Text

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Variable -Name DefaultWidth -Value 2 -Option ReadOnly -Scope Script
$script:State = [StringBuilder]::new()

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Get-AlphaThing'
    'Get-AlphaWidth'
)

Export-ModuleMember -Variable 'DefaultWidth'
'@

$alphaFiles = @{
    'Private/Get-Inner.ps1'     = @'
using namespace System.Collections.Generic

function Get-Inner {
    <#
    .SYNOPSIS
        Inner.
    #>
    [List[int]]::new().Count
}
'@
    'Private/Get-Later.ps1'     = @'
using namespace System.Text

function Get-Later {
    <#
    .SYNOPSIS
        Later.
    #>
    [StringBuilder]::new().Length
}
'@
    'Public/Get-AlphaThing.ps1' = @'
using namespace System.Collections.Generic

function Get-AlphaThing {
    <#
    .SYNOPSIS
        Returns a thing.
    .DESCRIPTION
        A fixture.
    .EXAMPLE
        Get-AlphaThing

        Returns 'thing'.
    #>
    [CmdletBinding()]
    param()
    "thing $(Get-Inner) $(Get-Later)"
}
'@
    'Public/Get-AlphaWidth.ps1' = @'
function Get-AlphaWidth {
    <#
    .SYNOPSIS
        Returns the width.
    #>
    [CmdletBinding()]
    param()
    throw 'alpha width failure'
}
'@
    'Scripts/Run.ps1'           = "'a script'"
}

$plainRoot = @'
#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Get-Thing'
)
'@

$null = New-Item -ItemType Directory -Path $src
New-FixtureModule -Name 'TaffarelJr.Alpha' -Root $alphaRoot -Files $alphaFiles `
    -Exports 'Get-AlphaThing', 'Get-AlphaWidth' -Variables 'DefaultWidth'
New-FixtureModule -Name 'TaffarelJr.Beta' -Root $plainRoot -Exports 'Get-Thing' -Files @{
    'Public/Get-Thing.ps1' = "function Get-Thing {`r`n    Join-Path `$PSScriptRoot 'data.txt'`r`n}"
}
New-FixtureModule -Name 'TaffarelJr.Gamma' -Root $plainRoot -Exports 'Get-Thing' -Files @{
    'Public/Get-Thing.ps1' = "function Get-Thing {`r`n    'unterminated"
}
Set-Content -LiteralPath (Join-Path $src 'TaffarelJr.Alpha' 'notes.txt') -Value 'not part of the module'

try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = & $build -Name 'TaffarelJr.Alpha' -SourceRoot $src -OutputPath $out -PassThru
    $builtFolder = Join-Path $out 'TaffarelJr.Alpha'
    $builtText = [File]::ReadAllText((Join-Path $builtFolder 'TaffarelJr.Alpha.psm1'))
    $builtLines = $builtText -split "`r`n"

    # Assert - hoisting
    $expectedHead = @(
        '#Requires -Version 7.4'
        'using namespace System.Collections.Generic'
        'using namespace System.Text'
    )
    Assert-Equal -Expected $expectedHead -Actual $builtLines[0..2] `
        -Message 'The file opens with #Requires and the distinct using lines of every source file, sorted'
    $laterUsings = @($builtLines[3..($builtLines.Count - 1)] | Where-Object { $_ -like 'using namespace*' })
    Assert-Equal -Expected 0 -Actual $laterUsings.Count -Message 'and no using line appears anywhere later'

    # Assert - preamble and tail, byte for byte
    $preamble = @(
        'Set-StrictMode -Version Latest'
        "`$ErrorActionPreference = 'Stop'"
        ''
        'New-Variable -Name DefaultWidth -Value 2 -Option ReadOnly -Scope Script'
        '$script:State = [StringBuilder]::new()'
    ) -join "`r`n"
    Assert-That -Condition ($builtText.Contains($preamble)) `
        -Message 'The root module''s preamble (preference lines and module state) is kept as it was'
    Assert-That -Condition ($builtText.TrimEnd().EndsWith("Export-ModuleMember -Variable 'DefaultWidth'")) `
        -Message 'and so is its tail, variable export included'
    Assert-That -Condition ($builtText -notmatch 'Get-ChildItem') -Message 'while the dot-sourcing loop is gone'

    # Assert - order and region markers
    $regions = @($builtLines | Where-Object { $_ -like '#region *' } | ForEach-Object { $_.Substring(8) })
    $expectedRegions = @(
        'Private/Get-Inner.ps1'
        'Private/Get-Later.ps1'
        'Public/Get-AlphaThing.ps1'
        'Public/Get-AlphaWidth.ps1'
    )
    Assert-Equal -Expected $expectedRegions -Actual $regions `
        -Message 'Each source file is a region, Private before Public, each in ordinal order'
    $endRegions = @($builtLines | Where-Object { $_ -like '#endregion *' })
    Assert-Equal -Expected $regions.Count -Actual $endRegions.Count -Message 'and each region is closed'

    # Assert - files
    $expectedFiles = @('TaffarelJr.Alpha.psm1', 'TaffarelJr.Alpha.psd1', 'README.md', 'CHANGELOG.md', 'Scripts/Run.ps1')
    Assert-Equal -Expected $expectedFiles -Actual $result.Files `
        -Message 'The result lists the files written: the built module, the copied manifest, docs and Scripts'
    $onDisk = @(Get-ChildItem -LiteralPath $builtFolder -Recurse -File |
            ForEach-Object { [Path]::GetRelativePath($builtFolder, $_.FullName).Replace('\', '/') } |
            Sort-Object)
    Assert-Equal -Expected @($expectedFiles | Sort-Object) -Actual $onDisk `
        -Message 'and the output folder holds exactly those, so a stray file in the source folder is not shipped'
    $sourceManifest = [File]::ReadAllBytes((Join-Path $src 'TaffarelJr.Alpha' 'TaffarelJr.Alpha.psd1'))
    $builtManifest = [File]::ReadAllBytes((Join-Path $builtFolder 'TaffarelJr.Alpha.psd1'))
    Assert-Equal -Expected $sourceManifest -Actual $builtManifest -Message 'The manifest is copied byte for byte'

    # Assert - bytes
    $bytes = [File]::ReadAllBytes((Join-Path $builtFolder 'TaffarelJr.Alpha.psm1'))
    $hasBom = $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB
    Assert-That -Condition (-not $hasBom) -Message 'The built file has no byte order mark'
    $bareFeeds = ([regex]::Matches($builtText, '(?<!\r)\n')).Count
    Assert-Equal -Expected 0 -Actual $bareFeeds -Message 'and every line ends in CRLF'

    # Assert - result object
    Assert-Equal -Expected 'TaffarelJr.Alpha' -Actual $result.Name -Message 'The result names the module'
    Assert-Equal -Expected ([version]'0.1.0') -Actual $result.Version -Message 'and its version'
    Assert-Equal -Expected 4 -Actual $result.Functions -Message 'and how many source files went in'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the built module in a fresh process: exports, help, module state, a stack trace line
    $probe = @(
        "Import-Module '$(Join-Path $builtFolder 'TaffarelJr.Alpha.psd1')'"
        "(Get-Command -Module TaffarelJr.Alpha | Sort-Object Name | ForEach-Object Name) -join ','"
        "(Get-Help Get-AlphaThing).Synopsis.Trim()"
        "Get-AlphaThing"
        "(Get-Variable -Name DefaultWidth -ValueOnly)"
        "try { Get-AlphaWidth } catch { `$_.ScriptStackTrace.Split([Environment]::NewLine)[0] }"
    ) -join '; '
    $fresh = @(& pwsh -NoProfile -NonInteractive -Command $probe 2>&1 | ForEach-Object { "$_" })

    # Assert
    Assert-Equal -Expected 'Get-AlphaThing,Get-AlphaWidth' -Actual $fresh[0] `
        -Message 'The built module exports the same functions'
    Assert-Equal -Expected 'Returns a thing.' -Actual $fresh[1] -Message 'with its comment-based help'
    Assert-Equal -Expected 'thing 0 0' -Actual $fresh[2] -Message 'and its private helpers resolve'
    Assert-Equal -Expected '2' -Actual $fresh[3] -Message 'and the exported variable is there'
    $regionLine = [array]::IndexOf($builtLines, '#region Public/Get-AlphaWidth.ps1') + 1
    $throwLine = [array]::IndexOf($builtLines, "    throw 'alpha width failure'") + 1
    Assert-That -Condition ($fresh[4] -like "*TaffarelJr.Alpha.psm1: line $throwLine*") `
        -Message 'A stack trace names the built file''s line'
    Assert-Equal -Expected 8 -Actual ($throwLine - $regionLine) `
        -Message 'and that line minus the region marker''s line is the source file''s own line (8)'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - stale output
    Set-Content -LiteralPath (Join-Path $builtFolder 'stale.txt') -Value 'left over'

    # Act
    $null = & $build -Name 'TaffarelJr.Alpha' -SourceRoot $src -OutputPath $out
    $rebuilt = [File]::ReadAllText((Join-Path $builtFolder 'TaffarelJr.Alpha.psm1'))

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath (Join-Path $builtFolder 'stale.txt'))) `
        -Message 'A build empties the module''s output folder first'
    Assert-Equal -Expected $builtText -Actual $rebuilt -Message 'and two builds of the same source are byte-identical'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a source file that uses $PSScriptRoot
    Assert-Throws -ScriptBlock { & $build -Name 'TaffarelJr.Beta' -SourceRoot $src -OutputPath $out } `
        -MessageLike '*Beta*Public*Get-Thing.ps1:2: uses $PSScriptRoot*ModuleBase*' `
        -Message 'A function file that uses $PSScriptRoot is refused, naming the file, the line and the fix'
    Assert-That -Condition (-not (Test-Path -LiteralPath (Join-Path $out 'TaffarelJr.Beta'))) `
        -Message 'and nothing is written for it'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a source file that does not parse
    Assert-Throws -ScriptBlock { & $build -Name 'TaffarelJr.Gamma' -SourceRoot $src -OutputPath $out } `
        -MessageLike '*Gamma*Public*Get-Thing.ps1:*:*' `
        -Message 'A source file that does not parse is refused, naming the file, line and column'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - names
    Assert-Throws -ScriptBlock { & $build -Name 'TaffarelJr.NoSuch' -SourceRoot $src -OutputPath $out } `
        -MessageLike '*No module folder at*TaffarelJr.NoSuch*' `
        -Message 'An unknown module name is refused, naming the folder'
    $two = @(& $build -Name 'TaffarelJr.Alpha, TaffarelJr.Alpha' -SourceRoot $src -OutputPath $out -PassThru)
    Assert-Equal -Expected 2 -Actual $two.Count -Message 'One comma-joined token names several modules'
    Assert-Throws -ScriptBlock { & $build -Name ' , ' -SourceRoot $src -OutputPath $out } `
        -MessageLike '*names no module*' -Message 'and one that names none is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -All over a source root holding only buildable modules
    Remove-Item -LiteralPath (Join-Path $src 'TaffarelJr.Beta'), (Join-Path $src 'TaffarelJr.Gamma') -Recurse -Force
    $all = @(& $build -All -SourceRoot $src -OutputPath $out -PassThru)

    # Assert
    Assert-Equal -Expected @('TaffarelJr.Alpha') -Actual @($all.Name) `
        -Message '-All builds every module under the source root'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a real module, built from this repository's src: TestKit, which every tree here holds
$realOut = Join-Path ([Path]::GetTempPath()) "build-real-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    $real = @(& $build -Name 'TaffarelJr.TestKit' -OutputPath $realOut -PassThru)
    $kitManifest = Join-Path $realOut 'TaffarelJr.TestKit' 'TaffarelJr.TestKit.psd1'
    $sourceExports = @((Import-PowerShellDataFile -LiteralPath $kitManifest).FunctionsToExport | Sort-Object) -join ','
    $kitProbe = "Import-Module '$kitManifest'; " +
        "(Get-Command -Module TaffarelJr.TestKit | Sort-Object Name | ForEach-Object Name) -join ','"
    $kitExports = @(& pwsh -NoProfile -NonInteractive -Command $kitProbe 2>&1 | ForEach-Object { "$_" })[-1]

    # Assert
    Assert-Equal -Expected $sourceExports -Actual $kitExports `
        -Message 'A real module built from src imports in a fresh process with the exports its manifest lists'
    Assert-Equal -Expected 1 -Actual $real.Count -Message 'and one module built is one result'
}
finally {
    Remove-Item -LiteralPath $realOut -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
