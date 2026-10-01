#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Get-Module TaffarelJr.FileText

function New-StubItem([string]$Name) {
    [PSCustomObject]@{
        Name     = $Name
        FullName = "root/$Name"
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names, what -To turns them into, and why that is unusable on Windows
$reserved = 'older Windows and many Windows tools treat it as a device.'
$trailing = 'Windows drops a trailing dot or space, so the name on disk would not be the one asked for.'
$cases = @(
    @{ Name = 'Placeholder.txt'; To = 'CON'; Expected = @("root/Placeholder.txt -> CON.txt - $reserved") }
    @{ Name = 'Placeholder'; To = 'nul'; Expected = @("root/Placeholder -> nul - $reserved") }
    @{ Name = 'Placeholder.tar.gz'; To = 'Com1'; Expected = @("root/Placeholder.tar.gz -> Com1.tar.gz - $reserved") }
    @{ Name = 'Placeholder.log'; To = 'LPT9'; Expected = @("root/Placeholder.log -> LPT9.log - $reserved") }
    @{ Name = 'Placeholder'; To = "COM$([char]0xB9)"; Expected = @("root/Placeholder -> COM$([char]0xB9) - $reserved") }
    @{ Name = 'Placeholder .txt'; To = 'AUX'; Expected = @("root/Placeholder .txt -> AUX .txt - $reserved") }
    @{ Name = 'Placeholder'; To = 'Real.'; Expected = @("root/Placeholder -> Real. - $trailing") }
    @{ Name = 'Placeholder'; To = 'Real '; Expected = @("root/Placeholder -> Real  - $trailing") }
    @{ Name = 'Placeholder.txt'; To = 'CONSOLE'; Expected = @() }
    @{ Name = 'Placeholder.txt'; To = 'COM10'; Expected = @() }
    @{ Name = 'xPlaceholder.txt'; To = 'CON'; Expected = @() }
    @{ Name = 'PlaceholderApp'; To = 'Real.'; Expected = @() }
    @{ Name = 'CON.txt'; To = 'Real'; Expected = @() }
    @{ Name = 'Placeholder'; To = "Real.$([char]0x200D)"; Expected = @() }
    @{ Name = 'Placeholder'; To = "Real $([char]0x200D)"; Expected = @() }
)

foreach ($case in $cases) {
    # Act
    $item = New-StubItem -Name $case.Name
    $found = @(& $module { param($i, $t) Find-UnusableName -Item $i -From 'Placeholder' -To $t } @($item) $case.To)

    # Assert
    Assert-Equal `
        -Expected $case.Expected `
        -Actual $found `
        -Message "'$($case.Name)' with -To '$($case.To)' gives $($case.Expected.Count) problem(s)"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$items = @(
    New-StubItem -Name 'Placeholder.txt'
    New-StubItem -Name 'other.txt'
    New-StubItem -Name 'Placeholder'
)

# Act
$several = @(& $module { param($i) Find-UnusableName -Item $i -From 'Placeholder' -To 'PRN' } $items)
$none = @(& $module { Find-UnusableName -Item @() -From 'Placeholder' -To 'PRN' })

# Assert
Assert-Equal `
    -Expected @("root/Placeholder.txt -> PRN.txt - $reserved", "root/Placeholder -> PRN - $reserved") `
    -Actual $several `
    -Message 'Every item that would get an unusable name is listed, in order, and only those'
Assert-Equal -Expected 0 -Actual $none.Count -Message 'No items have no problems'

exit (Complete-TestRun)
