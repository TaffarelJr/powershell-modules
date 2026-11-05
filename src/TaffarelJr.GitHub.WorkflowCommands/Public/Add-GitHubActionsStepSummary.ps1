function Add-GitHubActionsStepSummary {
    <#
    .SYNOPSIS
        Appends Markdown to the job's step summary.
    .DESCRIPTION
        The runner caps each step's summary at 1 MiB, and shows at most 20
        steps' summaries for a job. This throws before writing this step's
        summary past its 1 MiB, counted in UTF-8 bytes, rather than
        truncating silently or leaving the real failure for the runner to
        report after the fact.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Markdown
        The content to append. A newline is added after it.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.String. The Markdown to append.
    .OUTPUTS
        None. Nothing is returned.
    .EXAMPLE
        Add-GitHubActionsStepSummary -Markdown '## Test results'

        Appends a heading, and a newline after it, to the step summary.
    .EXAMPLE
        '# Results', '', 'All passed.' | Add-GitHubActionsStepSummary

        Appends each piped string as a line of its own.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Markdown
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            $limit = 1024 * 1024
            $path = Resolve-GitHubActionsFilePath -Variable 'GITHUB_STEP_SUMMARY'
            $text = $Markdown + "`n"
            $addition = [System.Text.Encoding]::UTF8.GetByteCount($text)
            $existing = [System.IO.FileInfo]::new($path).Length
            if ($existing + $addition -gt $limit) {
                throw ("Writing $addition more byte(s) would push this step's summary past its 1 MiB limit " +
                    "($existing already written).")
            }

            $shownPath = Hide-UrlCredential -Text $path
            if (-not $PSCmdlet.ShouldProcess($shownPath, 'Append to the step summary')) {
                return
            }

            Add-GitHubActionsFileText -Variable 'GITHUB_STEP_SUMMARY' -Path $path -Text $text
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
