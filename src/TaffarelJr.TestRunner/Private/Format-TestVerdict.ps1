function Format-TestVerdict {
    <#
    .SYNOPSIS
        Renders one file's result the way the runner prints it.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$Result)

    if ($Result.Crashed) { return "💥 crashed (exit $($Result.ExitCode))" }
    if ($Result.ExitCode -ne 0) { return "❌ $($Result.Passed) passed, $($Result.Failed) failed" }
    return "✅ $($Result.Passed) passed"
}
