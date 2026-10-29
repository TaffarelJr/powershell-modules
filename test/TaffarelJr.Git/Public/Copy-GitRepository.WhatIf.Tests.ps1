#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$source = New-GitTestRepo
$destination = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
$work = New-GitTestFolder
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $run = Get-WhatIfOutput { Copy-GitRepository -Url $source -Destination $destination -WhatIf }

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $destination) -Message '-WhatIf clones nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Clone $source"" on target ""$destination"".") `
        -Actual $run.Messages -Message '-WhatIf names the destination and the repository it would clone'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a URL with a credential in it, and -Branch
    $run = Get-WhatIfOutput {
        Copy-GitRepository 'https://user:s3cret@example.invalid/o/r.git' $destination -Branch 'main' -WhatIf
    }

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $destination) `
        -Message '-WhatIf with -Branch clones nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Clone https://***@example.invalid/o/r.git, checking out branch main""" +
        " on target ""$destination""."
    ) -Actual $run.Messages -Message '-WhatIf hides the credential in the URL it names, and names the branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative destination, and an empty folder there
    New-Item -ItemType Directory -Path (Join-Path $work 'empty') | Out-Null
    Push-Location -LiteralPath $work

    # Act
    try {
        $run = Get-WhatIfOutput { Copy-GitRepository -Url $source -Destination 'empty' -WhatIf }
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-ChildItem -LiteralPath (Join-Path $work 'empty') -Force).Count `
        -Message '-WhatIf clones nothing into an empty folder'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Clone $source"" on target ""$(Join-Path $work 'empty')""."
    ) -Actual $run.Messages -Message '-WhatIf names a relative destination as a full path'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Copy-GitRepository -Url '--upload-pack=x' -Destination $destination -WhatIf } `
        -MessageLike "*'--upload-pack=x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a URL that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a destination folder that is not empty, and one that is a file
    $full = Join-Path $work 'full'
    New-Item -ItemType Directory -Path $full | Out-Null
    Set-Content -LiteralPath (Join-Path $full 'x.txt') -Value 'x' -NoNewline
    $file = Join-Path $work 'file.txt'
    Set-Content -LiteralPath $file -Value 'x' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Copy-GitRepository -Url $source -Destination $full -WhatIf } `
        -MessageLike "Cloning $source failed: '$full' already exists and is not an empty folder." `
        -Message '-WhatIf refuses a destination folder that is not empty'
    Assert-Throws -ScriptBlock { Copy-GitRepository -Url $source -Destination $full } `
        -MessageLike "Cloning $source failed: '$full' already exists and is not an empty folder." `
        -Message 'and so does the real call'
    Assert-Throws -ScriptBlock { Copy-GitRepository -Url $source -Destination $file -WhatIf } `
        -MessageLike "Cloning $source failed: '$file' already exists and is not an empty folder." `
        -Message '-WhatIf refuses a destination that is a file'
    Assert-Equal -Expected @('x.txt') -Actual @(Get-ChildItem -LiteralPath $full -Force -Name) `
        -Message 'and the folder that is not empty is left as it was'
}
finally {
    Remove-GitTestRepo -Path $source
    Remove-GitTestRepo -Path $destination
    Remove-GitTestRepo -Path $work
}

exit (Complete-TestRun)
