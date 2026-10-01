#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1'
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module $modulePath -Force
$module = Get-Module TaffarelJr.Tally

#───────────────────────────────────────────────────────────────────────────────
# Arrange - six runspaces add under one key while two more add and clear
# names under another, and two read and render the first as it grows
$keyA = "Concurrency.A.$([Guid]::NewGuid())"
$keyB = "Concurrency.B.$([Guid]::NewGuid())"
$adders = 1..6 | ForEach-Object { [PSCustomObject]@{ Role = 'Add'; Id = $_ } }
$churners = 1..2 | ForEach-Object { [PSCustomObject]@{ Role = 'Churn'; Id = $_ } }
$readers = 1..2 | ForEach-Object { [PSCustomObject]@{ Role = 'Read'; Id = $_ } }
$work = @($adders) + @($churners) + @($readers)

# Act
$readings = $work | ForEach-Object -ThrottleLimit 10 -TimeoutSeconds 120 -Parallel {
    Import-Module $using:modulePath
    $keyA = $using:keyA
    $keyB = $using:keyB
    $name = "churn$($_.Id)"
    switch ($_.Role) {
        'Add' {
            1..100 | ForEach-Object { Add-Tally -Name 'hits' -Key $keyA }
        }
        'Churn' {
            1..100 | ForEach-Object {
                Add-Tally -Name $name -Key $keyB
                Clear-Tally -Name $name -Key $keyB
            }
        }
        'Read' {
            1..100 | ForEach-Object {
                [PSCustomObject]@{
                    Count = Get-Tally -Name 'hits' -Key $keyA
                    Line  = Format-Tally -Key $keyA
                }
            }
        }
    }
}
$total = Get-Tally -Name 'hits' -Key $keyA
$outOfRange = @($readings.Where({ $_.Count -lt 0 -or $_.Count -gt 600 }))
$malformed = @($readings.Where({ $_.Line -notmatch '^(?:[0-9]+ hits)?$' }))
$keyBKept = & $module { param($Key) (Get-TallyState).Keyed.Contains($Key) } $keyB

# Assert
Assert-Equal -Expected 600 -Actual $total -Message 'Every add under one key is counted while other keys change'
Assert-Equal -Expected 200 -Actual @($readings).Count -Message 'and every read finished'
Assert-Equal -Expected 0 -Actual $outOfRange.Count -Message 'each seeing a count between none and all of the adds'
Assert-Equal -Expected 0 -Actual $malformed.Count -Message 'and each rendering a whole line'
Assert-Equal -Expected $false -Actual $keyBKept `
    -Message 'and the key whose names were all cleared is forgotten, however the clears interleaved'
Clear-Tally -Key $keyA

exit (Complete-TestRun)
