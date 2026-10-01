#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'FileTextTestHelper.ps1')
$module = Get-Module TaffarelJr.FileText

$sandbox = New-FileTextSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $long = New-TestFile -Directory $sandbox -Name 'long.bin' -Byte ([byte[]](1, 2, 3, 4, 5, 6))

    # Act
    $head = & $module { param($p) Read-FileHead -Path $p -Count 4 } $long

    # Assert
    Assert-Equal -Expected ([byte[]](1, 2, 3, 4)) -Actual $head -Message 'Only the first bytes asked for are read'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $short = New-TestFile -Directory $sandbox -Name 'short.bin' -Byte ([byte[]](7, 8))
    $empty = New-TestFile -Directory $sandbox -Name 'empty.bin' -Byte ([byte[]]@())

    # Act
    $shortHead = & $module { param($p) Read-FileHead -Path $p -Count 4 } $short
    $emptyHead = & $module { param($p) Read-FileHead -Path $p -Count 4 } $empty

    # Assert
    Assert-Equal `
        -Expected ([byte[]](7, 8)) `
        -Actual $shortHead `
        -Message 'A file shorter than the count comes back whole, with no padding'
    Assert-Equal `
        -Expected ([byte[]]@()) `
        -Actual $emptyHead `
        -Message 'and an empty file as no bytes, not as nothing at all'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file another program holds open
    $held = New-TestFile -Directory $sandbox -Name 'held.bin' -Byte ([byte[]](1, 2, 3, 4))
    $hold = Lock-TestFile -Path $held

    # Act / Assert
    try {
        Assert-Throws -ScriptBlock { & $module { param($p) Read-FileHead -Path $p -Count 4 } $held } `
            -MessageLike ([WildcardPattern]::Escape("Cannot read '$held': ") + '*being used by another process*') `
            -Message 'A file held open by another program says it cannot read the file, and why'
    }
    finally {
        $hold.Dispose()
    }
}
finally {
    Remove-FileTextSandbox -Path $sandbox
}

exit (Complete-TestRun)
