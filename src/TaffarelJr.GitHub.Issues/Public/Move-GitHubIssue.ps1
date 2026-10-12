function Move-GitHubIssue {
    <#
    .SYNOPSIS
        Transfers an issue to another repository.
    .DESCRIPTION
        Moves an issue to another repository, as gh issue transfer does.
        The issue keeps its comments and assignees. Its labels and
        milestones come along only where the destination has ones of the
        same name (a milestone also of the same due date); the rest are
        dropped.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to transfer: its number or URL, or an issue object. A
        pull request's URL or object is refused.
    .PARAMETER DestinationRepository
        The repository to transfer it to, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Given as $null, it throws. It is the
        second positional value, after the issue; with issues piped in,
        give it by name.
    .PARAMETER Repository
        The issue's current repository, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Omit it to use the current directory's
        repository; given as $null, it throws. An issue given by URL or
        object is in the repository it names; one in a different repository
        than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The issue to transfer, bound to -Issue: its number or URL, or an
        issue object, such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Move-GitHubIssue 12 OWNER/OTHER -Repository OWNER/REPO

        Transfers issue 12 of OWNER/REPO to OWNER/OTHER.
    .EXAMPLE
        Get-GitHubIssue -List -Label moved -Repository OWNER/REPO |
            Move-GitHubIssue -DestinationRepository OWNER/OTHER

        Transfers OWNER/REPO's open issues labeled moved to OWNER/OTHER.
        Given by position instead, OWNER/OTHER would bind to -Issue, the
        first positional parameter, and the call would fail for want of
        -DestinationRepository.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [object]$DestinationRepository,

        [object]$Repository
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
                $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Confirm')) {
                $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference')
            }

            if (-not $PSBoundParameters.ContainsKey('Verbose')) {
                $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
            }

            $conversion = @{
                Repository = $DestinationRepository
                Name       = 'DestinationRepository'
            }
            $destination = ConvertTo-GitHubRepositoryReference @conversion
            if ($null -eq $destination) {
                throw '-DestinationRepository was given, but it is $null: give the repository to transfer the issue to.'
            }

            # Core's reader returns any text without a dash or a space; gh's transfer takes only a URL in a
            # scheme it knows (in lower case), the SSH form, or [HOST[:PORT]/]OWNER/REPO.
            $isUrl = $destination -cmatch '^(?:git@|(?:ssh|git\+ssh|git|https?|git\+https):)'
            if (-not $isUrl -and $destination -notmatch '^(?:[^/:]+(?::[0-9]+)?/)?[^/:]+/[^/:]+\z') {
                $shown = Hide-UrlCredential -Text $destination
                throw "'$shown' is not a repository: give OWNER/REPO, HOST/OWNER/REPO, or a URL."
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $destinationName = Format-GitHubRepositoryName -Repository $destination
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }

    process {
        try {
            $reference = Resolve-GitHubItemReference -Item $Issue -Kind Issue -Repository $repositoryReference
            $target = Format-GitHubIssueTarget -Reference $reference -Repository $repositoryReference
            if (-not $PSCmdlet.ShouldProcess($target, "Transfer issue to $destinationName")) {
                return
            }

            $invocation = @{
                Activity   = "Transferring issue $reference"
                Arguments  = @('issue', 'transfer', $reference, $destination)
                Repository = $repositoryReference
            }
            Invoke-GitHubCommand @invocation | Out-Null
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
