#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$generator = Join-Path $repoRoot 'build' 'Get-DependencyDiagram.ps1'

# A source root of the test's own: Alpha requires nothing, Beta requires Alpha (as a bare name),
# Gamma requires both (as hashtables), and a dotted name checks the node ids.
$root = Join-Path ([Path]::GetTempPath()) "diagram-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
$src = Join-Path $root 'src'

function New-Manifest {
    <#
    .SYNOPSIS
        Writes a manifest for a fixture module with the given required modules.
    .PARAMETER Name
        The module's full name.
    .PARAMETER Required
        The RequiredModules text, or an empty string for none.
    #>
    param(
        [string]$Name,
        [string]$Required = ''
    )

    $folder = Join-Path $src $Name
    $null = New-Item -ItemType Directory -Path $folder -Force
    $line = if ($Required) { "    RequiredModules = $Required" } else { '' }
    Set-Content -LiteralPath (Join-Path $folder "$Name.psd1") -Value "@{`n    ModuleVersion = '0.1.0'`n$line`n}"
}

try {
    New-Manifest -Name 'TaffarelJr.Alpha'
    New-Manifest -Name 'TaffarelJr.Beta' -Required "@('TaffarelJr.Alpha')"
    $gammaRequires = "@(@{ ModuleName = 'TaffarelJr.Beta'; ModuleVersion = '0.1.0' }, " +
        "@{ ModuleName = 'TaffarelJr.Alpha'; ModuleVersion = '0.1.0' })"
    New-Manifest -Name 'TaffarelJr.Gamma' -Required $gammaRequires
    New-Manifest -Name 'TaffarelJr.Dotted.Name' -Required "@('TaffarelJr.Gamma')"

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $diagram = & $generator -SourceRoot $src
    $lines = $diagram -split "`n"

    # Assert
    Assert-Equal -Expected '```mermaid' -Actual $lines[0] -Message 'The diagram is a Mermaid block'
    Assert-Equal -Expected 'graph LR' -Actual $lines[1] -Message 'drawn left to right'
    Assert-Equal -Expected '```' -Actual $lines[-1] -Message 'and closed'
    $nodes = @($lines | Where-Object { $_ -match '^\s{4}\w+\["' })
    $expectedNodes = @('    Alpha["Alpha"]', '    Beta["Beta"]', '    DottedName["Dotted.Name"]', '    Gamma["Gamma"]')
    Assert-Equal -Expected $expectedNodes -Actual $nodes `
        -Message 'Every module is a node by its short name, in order, with dots out of the id and in the label'
    $edges = @($lines | Where-Object { $_ -match '-->' })
    $expectedEdges = @('    Beta --> Alpha', '    DottedName --> Gamma', '    Gamma --> Alpha', '    Gamma --> Beta')
    Assert-Equal -Expected $expectedEdges -Actual $edges `
        -Message 'An arrow runs from a module to each module it requires, bare names and hashtables alike'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a README with the markers and CRLF line endings
    $readme = Join-Path $root 'README.md'
    $before = "# Title`r`n`r`n<!-- dependency-diagram -->`r`nstale`r`n<!-- /dependency-diagram -->`r`n`r`nAfter.`r`n"
    [File]::WriteAllText($readme, $before)

    # Act
    & $generator -SourceRoot $src -ReadmePath $readme
    $written = [File]::ReadAllText($readme)

    # Assert
    Assert-That -Condition ($written.Contains('graph LR') -and -not $written.Contains('stale')) `
        -Message 'The block between the markers is replaced'
    $opening = "# Title`r`n`r`n<!-- dependency-diagram -->`r`n"
    $closing = "`r`n`r`nAfter.`r`n"
    Assert-That -Condition ($written.StartsWith($opening) -and $written.EndsWith($closing)) `
        -Message 'and the text around it is left alone'
    $bareFeeds = ([regex]::Matches($written, '(?<!\r)\n')).Count
    Assert-Equal -Expected 0 -Actual $bareFeeds -Message 'in the README''s own line endings'
    $again = $written
    & $generator -SourceRoot $src -ReadmePath $readme
    Assert-Equal -Expected $again -Actual ([File]::ReadAllText($readme)) -Message 'Running it again changes nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a README without the markers
    $bare = Join-Path $root 'Bare.md'
    [File]::WriteAllText($bare, "# Title`r`n")
    Assert-Throws -ScriptBlock { & $generator -SourceRoot $src -ReadmePath $bare } `
        -MessageLike '*has no <!-- dependency-diagram -->*' `
        -Message 'A README without the markers is refused, naming them'

    #───────────────────────────────────────────────────────────────────────────
    # Act - no modules at all
    $empty = & $generator -SourceRoot (Join-Path $root 'nowhere')

    # Assert
    Assert-Equal -Expected "``````mermaid`ngraph LR`n``````" -Actual $empty `
        -Message 'A source root with no modules draws an empty graph'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

#───────────────────────────────────────────────────────────────────────────────
# Act - this repository's own README against this repository's manifests. Each module's pull
# request adds its node, so the committed diagram is exactly what the modules under src declare.
$committed = [File]::ReadAllText((Join-Path $repoRoot 'README.md')).Replace("`r`n", "`n")
$expected = & $generator
$match = [regex]::Match($committed, '(?s)<!-- dependency-diagram -->\n(.*?)\n<!-- /dependency-diagram -->')

# Assert
Assert-That -Condition $match.Success -Message 'The root README holds the dependency diagram between its markers'
Assert-Equal -Expected $expected -Actual $match.Groups[1].Value `
    -Message 'and it is the diagram of the modules under src: run build/Get-DependencyDiagram.ps1 -ReadmePath README.md'

#───────────────────────────────────────────────────────────────────────────────
# Act - and its table: a row for every module under src, and for no other
$folders = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Directory
$modules = @($folders | ForEach-Object { $_.Name.Substring(11) } | Sort-Object)
$rowPattern = '(?m)^\| \[([^\]]+)\]\(src/TaffarelJr\.[^)]+\)'
$rows = @([regex]::Matches($committed, $rowPattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object)

# Assert
Assert-Equal -Expected $modules -Actual $rows `
    -Message 'The root README''s table has a row for every module under src, and no other'

exit (Complete-TestRun)
