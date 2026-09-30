function Write-Done {
    <#
    .SYNOPSIS
        Closes the line opened by Write-Doing, with its outcome.
    .DESCRIPTION
        Falls back to Write-Success/Write-Skip -
        a fresh line, not a continuation -
        when no Write-Doing is open,
        so a caller does not have to track that itself.
    .PARAMETER Text
        Overrides the default outcome wording ("done" or "already done").
    .PARAMETER Skip
        Marks the outcome as unchanged rather than done,
        the same distinction Write-Skip makes on its own line.
    #>
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [string]$Text,

        [switch]$Skip
    )

    process {
        $hasText = $PSBoundParameters.ContainsKey('Text')
        $outcome = if ($hasText) {
            $Text
        }
        elseif ($Skip) {
            'already done'
        }
        else {
            'done'
        }

        if (-not $script:LineOpen) {
            if ($Skip) {
                Write-Skip -Text $outcome
            }
            else {
                Write-Success -Text $outcome
            }

            return
        }

        $script:LineOpen = $false
        $color = if ($Skip) {
            'DarkGray'
        }
        else {
            'Green'
        }

        Write-Host " $(Format-MessageText $outcome)" -ForegroundColor $color
    }
}
