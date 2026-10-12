#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Parses one JSON array and converts its root element, keeping the array whole.
$convert = {
    param([string]$Json)
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        , (ConvertFrom-GitHubJsonArray -Element $document.RootElement -Context (New-GitHubJsonContext))
    }
    finally {
        $document.Dispose()
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Act - an array of every kind of element
$items = & $module $convert '[{"node_id":"n"},[1,[]],"2024-01-02T03:04:05Z",7,null,true]'

# Assert
Assert-Equal -Expected 6 -Actual $items.Count -Message 'Every element is kept, a null included'
Assert-Equal -Expected 'n' -Actual $items[0].NodeId -Message 'An object element is converted'
Assert-That -Condition ($items[1] -is [array] -and $items[1][1] -is [array] -and $items[1][1].Count -eq 0) `
    -Message 'An array element stays an array, an empty one included'
Assert-Equal -Expected '2024-01-02T03:04:05Z' -Actual $items[2] `
    -Message 'A string element has no key, so it is never a date'
Assert-Equal -Expected @([long]7, $null, $true) -Actual @($items[3], $items[4], $items[5]) `
    -Message 'and the scalars are converted in place'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array and a one-element one
$empty = & $module $convert '[]'
$one = & $module $convert '["x"]'

# Assert
Assert-That -Condition ($empty -is [array] -and $empty.Count -eq 0) `
    -Message 'An empty array comes back as an empty array'
Assert-That -Condition ($one -is [array] -and $one.Count -eq 1) -Message 'and a one-element array as an array'

exit (Complete-TestRun)
