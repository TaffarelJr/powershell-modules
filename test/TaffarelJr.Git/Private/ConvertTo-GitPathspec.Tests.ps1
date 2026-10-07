#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru

$temp = [System.IO.Path]::GetTempPath().TrimEnd('\', '/')
$slashedTemp = $temp -replace '\\', '/'

#───────────────────────────────────────────────────────────────────────────────
# Act
$relative = & $module { ConvertTo-GitPathspec -Activity 'Reading' -Path 'src\report[1].txt' }

# Assert
Assert-Equal -Expected ':(top,literal)src/report[1].txt' -Actual $relative `
    -Message 'A bare relative path is literal, from the repository root, with forward slashes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - bare paths with inner segments git would resolve without the
# literal magic
$innerRows = @(
    @{ Path = 'src/./x.txt'; Expected = ':(top,literal)src/x.txt' }
    @{ Path = 'src/sub/../a.txt'; Expected = ':(top,literal)src/a.txt' }
    @{ Path = 'src//x.txt'; Expected = ':(top,literal)src/x.txt' }
    @{ Path = 'src/..'; Expected = ':(top)' }
)

# Act / Assert
foreach ($row in $innerRows) {
    $normalized = & $module { param($p) ConvertTo-GitPathspec -Activity 'Reading' -Path $p } $row.Path
    Assert-Equal -Expected $row.Expected -Actual $normalized `
        -Message "'$($row.Path)' is normalized before the magic is added"
}

Assert-Throws -ScriptBlock { & $module { ConvertTo-GitPathspec -Activity 'Reading' -Path 'src/../../x.txt' } } `
    -MessageLike "Reading failed: -Path 'src/../../x.txt' climbs above the repository root.*" `
        -Message 'A bare path that climbs above the root throws'

#───────────────────────────────────────────────────────────────────────────────
# Act
$dotFile = & $module { ConvertTo-GitPathspec -Activity 'Reading' -Path '.gitignore' }

# Assert
Assert-Equal -Expected ':(top,literal).gitignore' -Actual $dotFile `
    -Message 'A name that only starts with a dot is still a bare path'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$full = Join-Path $temp 'repo' 'a*.txt'

# Act
$absolute = & $module { param($p) ConvertTo-GitPathspec -Activity 'Reading' -Path $p } $full

# Assert
Assert-Equal -Expected ":(literal)$($full -replace '\\', '/')" -Actual $absolute `
    -Message 'An absolute path is literal and used as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$rows = @(
    @{ Path = '.\src\x.txt'; Expected = ":(literal)$slashedTemp/src/x.txt" }
    @{ Path = './src/x.txt'; Expected = ":(literal)$slashedTemp/src/x.txt" }
    @{ Path = '.'; Expected = ":(literal)$slashedTemp" }
    @{
        Path = '..\x.txt'
        Expected = ":(literal)$([System.IO.Path]::GetFullPath((Join-Path $temp '..' 'x.txt')) -replace '\\', '/')"
    }
)
Push-Location -LiteralPath $temp

# Act / Assert
try {
    foreach ($row in $rows) {
        $pathspec = & $module { param($p) ConvertTo-GitPathspec -Activity 'Reading' -Path $p } $row.Path
        Assert-Equal -Expected $row.Expected -Actual $pathspec `
            -Message "'$($row.Path)' is relative to the current location, made absolute"
    }
}
finally {
    Pop-Location
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$fromRepoPath = & $module { param($r) ConvertTo-GitPathspec -Activity 'Reading' -Path '.\x.txt' -RepoPath $r } (Join-Path $temp 'repo')

# Assert
Assert-Equal -Expected ":(literal)$slashedTemp/repo/x.txt" -Actual $fromRepoPath `
    -Message 'With -RepoPath, a path starting with a dot is relative to it instead'

exit (Complete-TestRun)
