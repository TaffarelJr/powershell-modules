using namespace System.IO

function New-GitTestRepo {
    <#
    .SYNOPSIS
        Creates a throwaway git repo under the temp folder, with a
        deterministic identity and line-ending config so a test never
        depends on the host machine's own git config.
    .DESCRIPTION
        Not exported - a test-only fixture, shared across this module's
        test files rather than reimplemented per file.
    .PARAMETER NoCommit
        Skips the initial commit, for a test that needs a repo with no
        history at all.
    .OUTPUTS
        The new repo's full path.
    #>
    param(
        [switch]$NoCommit
    )

    $path = Join-Path ([Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null

    git -C $path init --quiet --initial-branch=main 2>&1 | Out-Null
    git -C $path config core.autocrlf false 2>&1 | Out-Null
    git -C $path config user.name 'Test' 2>&1 | Out-Null
    git -C $path config user.email 'test@example.com' 2>&1 | Out-Null

    if (-not $NoCommit) {
        Set-Content -LiteralPath (Join-Path $path 'a.txt') -Value 'line1' -NoNewline
        git -C $path add -A 2>&1 | Out-Null
        git -C $path commit --quiet -m 'initial' 2>&1 | Out-Null
    }

    return $path
}

function Remove-GitTestRepo {
    <#
    .SYNOPSIS
        Deletes a repo New-GitTestRepo created.
    .DESCRIPTION
        Not exported - a test-only fixture. Tolerates a path that is
        already gone, so a test's own finally block never fails on
        cleanup it does not strictly need.
    .PARAMETER Path
        The repo to delete.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
