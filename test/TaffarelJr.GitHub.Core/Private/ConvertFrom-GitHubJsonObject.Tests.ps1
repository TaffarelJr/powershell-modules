#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

# Parses one JSON object and converts its root element.
$convert = {
    param([string]$Json, [bool]$KeyedByData, [string[]]$KeepKeysOf)
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try {
        $context = New-GitHubJsonContext -KeepKeysOf $KeepKeysOf
        ConvertFrom-GitHubJsonObject -Element $document.RootElement -Context $context -KeyedByData $KeyedByData
    }
    finally {
        $document.Dispose()
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Act - an object with every kind of value
$object = & $module $convert '{"name":"x","count":2,"draft":false,"body":null,"author":{"login":"o"},"labels":["a"],"createdAt":"2024-01-02T03:04:05Z"}' $false

# Assert
Assert-That -Condition ($object -is [System.Management.Automation.PSCustomObject]) `
    -Message 'An object with ordinary keys becomes a PSCustomObject'
Assert-Equal -Expected @('Name', 'Count', 'Draft', 'Body', 'Author', 'Labels', 'CreatedAt') `
    -Actual @($object.PSObject.Properties.Name) `
    -Message 'with every key re-cased, in order'
Assert-Equal -Expected @('x', [long]2, $false, $null) `
    -Actual @($object.Name, $object.Count, $object.Draft, $object.Body) `
    -Message 'and each scalar converted in place'
Assert-Equal -Expected 'o' -Actual $object.Author.Login -Message 'A nested object is converted too'
Assert-That -Condition ($object.Labels -is [array] -and $object.Labels.Count -eq 1) `
    -Message 'and a nested array stays an array'
Assert-That -Condition ($object.CreatedAt -is [datetime]) -Message 'A timestamp under a date''s key is a [datetime]'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same object, keyed by data
$keyed = & $module $convert '{"a_b.txt":{"raw_url":"u"},"created_at":"2024-01-02T03:04:05Z"}' $true

# Assert
Assert-That -Condition ($keyed -is [System.Collections.Specialized.OrderedDictionary]) `
    -Message 'An object keyed by data becomes an ordered dictionary'
Assert-Equal -Expected @('a_b.txt', 'created_at') -Actual @($keyed.PSBase.Keys) `
    -Message 'with its keys exactly as they are'
Assert-Equal -Expected 'u' -Actual $keyed['a_b.txt'].RawUrl -Message 'while what they hold is re-cased'
Assert-Equal -Expected '2024-01-02T03:04:05Z' -Actual $keyed['created_at'] -Message 'and a data key is never a date''s'

#───────────────────────────────────────────────────────────────────────────────
# Act - a kept name below the top
$nested = & $module $convert '{"outer":{"files":{"x_y":1}}}' $false @('files')

# Assert
Assert-Equal -Expected @('x_y') -Actual @($nested.Outer.Files.PSBase.Keys) `
    -Message 'A kept name is found below the top too'

#───────────────────────────────────────────────────────────────────────────────
# Act - the date rule: which keys, which values, and which kind
$json = '{"closedAt":"0001-01-01T00:00:00Z","title":"2024-01-02T03:04:05Z","createdAt":"2024-01-02T03:04:05Z",' +
'"updatedAt":"2024-01-02T03:04:05+05:00","dueDate":"2024-02-30T00:00:00Z"}'
$dated = & $module $convert $json $false

# Assert
Assert-Equal -Expected $null -Actual $dated.ClosedAt `
    -Message 'Year 0001 under a date''s key is $null, gh''s time that was never set'
Assert-Equal -Expected '2024-01-02T03:04:05Z' -Actual $dated.Title -Message 'A timestamp under any other key stays text'
Assert-Equal -Expected ([datetime]::new(2024, 1, 2, 3, 4, 5, [DateTimeKind]::Utc)) -Actual $dated.CreatedAt `
    -Message 'One ending Z is that moment in UTC'
Assert-Equal -Expected ([DateTimeKind]::Utc) -Actual $dated.CreatedAt.Kind -Message 'of Kind Utc'
Assert-Equal -Expected ([DateTimeOffset]::Parse('2024-01-02T03:04:05+05:00').LocalDateTime) -Actual $dated.UpdatedAt `
    -Message 'One with an offset is that moment in local time'
Assert-Equal -Expected ([DateTimeKind]::Local) -Actual $dated.UpdatedAt.Kind -Message 'of Kind Local'
Assert-Equal -Expected '2024-02-30T00:00:00Z' -Actual $dated.DueDate -Message 'and one .NET cannot hold stays its text'

#───────────────────────────────────────────────────────────────────────────────
# Act - a kept name met again inside the dictionary it keeps
$inside = & $module $convert '{"files":{"files":{"x_y":1}}}' $false @('files')

# Assert
Assert-Equal -Expected @('files') -Actual @($inside.Files.PSBase.Keys) `
    -Message 'A kept map''s own key is data, even one equal to the kept name'
Assert-Equal -Expected @('XY') -Actual @($inside.Files['files'].PSObject.Properties.Name) `
    -Message 'so what it holds is re-cased, not kept'

exit (Complete-TestRun)
