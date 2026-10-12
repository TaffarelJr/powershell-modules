function Add-GitHubActionsStepSummary {
    <#
    .SYNOPSIS
        Appends Markdown to the job's step summary.
    .DESCRIPTION
        The runner caps a job's combined summary at 1 MiB across all of
        its steps. This throws before writing past that, rather than
        truncating silently or leaving the real failure for the runner
        to report after the fact.
    .PARAMETER Markdown
        The content to append.
    #>
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Markdown
    )

    begin {
        $limit = 1024 * 1024
    }

    process {
        if (-not $env:GITHUB_STEP_SUMMARY) {
            throw 'GITHUB_STEP_SUMMARY is not set - this must run inside a GitHub Actions step.'
        }

        $addition = [System.Text.Encoding]::UTF8.GetByteCount($Markdown + "`n")
        $existing = if (Test-Path -LiteralPath $env:GITHUB_STEP_SUMMARY) {
            (Get-Item -LiteralPath $env:GITHUB_STEP_SUMMARY).Length
        }
        else {
            0
        }

        if ($existing + $addition -gt $limit) {
            throw "Writing $addition more byte(s) would push the job summary past its 1 MiB limit ($existing already written)."
        }

        [System.IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, $Markdown + "`n", [System.Text.UTF8Encoding]::new($false))
    }
}
