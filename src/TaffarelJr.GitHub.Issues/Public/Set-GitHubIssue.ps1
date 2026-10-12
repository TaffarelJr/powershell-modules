function Set-GitHubIssue {
    <#
    .SYNOPSIS
        Changes an issue's title, body, labels, people, type, milestone,
        parent, sub-issues, blocking relationships, or pinned state.
    .DESCRIPTION
        Says what to change, or throws: asked for no change at all, gh
        would only refuse with a generic message. A value and its removal
        together - -Milestone with -RemoveMilestone, -Type with
        -RemoveType, -Parent with -RemoveParent - throw too, as gh refuses
        each pair, and so do a blank -Title, -Milestone, or -Type, and a
        blank name in any list.

        The body reaches gh through a temporary file, so it arrives exactly
        as given: any length, line endings as they are, and nothing added
        at the end. -Pinned is a three-state toggle: omitted leaves it
        alone, given pins the issue, and given as $false unpins it. Along
        with other edits, that is a second gh call after the edit: if it
        fails, the edit stays made, and the error says so.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Issue
        The issue to change: its number or URL, or an issue object. A pull
        request's URL or object is refused.
    .PARAMETER Title
        The new title. A blank one throws, as an issue needs a title.
    .PARAMETER Body
        The new body, as Markdown. An empty string clears it, and so does
        $null: PowerShell hands a text parameter given $null an empty
        string, so the two cannot be told apart.
    .PARAMETER Milestone
        The milestone to move the issue to, by name. A blank one throws;
        -RemoveMilestone takes the issue out of its milestone.
    .PARAMETER RemoveMilestone
        Takes the issue out of its milestone. Needs gh 2.54 or later.
    .PARAMETER AddLabel
        Labels to add.
    .PARAMETER RemoveLabel
        Labels to remove.
    .PARAMETER AddAssignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER RemoveAssignee
        Users to unassign, by login.
    .PARAMETER AddProject
        Projects to add the issue to, by title. Needs a token with the
        project scope.
    .PARAMETER RemoveProject
        Projects to remove the issue from, by title.
    .PARAMETER Type
        The new issue type, by name. A blank one throws; -RemoveType
        removes the type. Needs gh 2.94 or later.
    .PARAMETER RemoveType
        Removes the issue's type. Needs gh 2.94 or later.
    .PARAMETER Parent
        Sets the parent issue: its number or URL, or an issue object. Needs
        gh 2.94 or later.
    .PARAMETER RemoveParent
        Removes the parent issue relationship. Needs gh 2.94 or later.
    .PARAMETER AddSubIssue
        Sub-issues to add: numbers, URLs, or issue objects. Needs gh 2.94
        or later.
    .PARAMETER RemoveSubIssue
        Sub-issues to remove: numbers, URLs, or issue objects. Needs gh
        2.94 or later.
    .PARAMETER AddBlockedBy
        Issues to add as blocking this one: numbers, URLs, or issue
        objects. Needs gh 2.94 or later.
    .PARAMETER RemoveBlockedBy
        Issues to remove as blocking this one: numbers, URLs, or issue
        objects. Needs gh 2.94 or later.
    .PARAMETER AddBlocking
        Issues to add as blocked by this one: numbers, URLs, or issue
        objects. Needs gh 2.94 or later.
    .PARAMETER RemoveBlocking
        Issues to remove as blocked by this one: numbers, URLs, or issue
        objects. Needs gh 2.94 or later.
    .PARAMETER Pinned
        Pins the issue, or with -Pinned:$false unpins it.
    .PARAMETER Repository
        The repository, in [HOST/]OWNER/REPO form or as a URL, or a
        repository object. Omit it to use the current directory's
        repository; given as $null, it throws. An issue given by URL or
        object is in the repository it names; one in a different repository
        than this throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        System.Object
        The issue to change, bound to -Issue: its number or URL, or an issue
        object, such as one a listing returned.
    .OUTPUTS
        None.
    .EXAMPLE
        Set-GitHubIssue -Issue 12 -AddLabel bug -Repository OWNER/REPO

        Adds the label bug to issue 12 of OWNER/REPO.
    .EXAMPLE
        Set-GitHubIssue -Issue 12 -Pinned -Repository OWNER/REPO

        Pins issue 12 of OWNER/REPO.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Get-GitHubIssue
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Issue,

        [string]$Title,

        [string]$Body,

        [string]$Milestone,

        [switch]$RemoveMilestone,

        [string[]]$AddLabel,

        [string[]]$RemoveLabel,

        [string[]]$AddAssignee,

        [string[]]$RemoveAssignee,

        [string[]]$AddProject,

        [string[]]$RemoveProject,

        [string]$Type,

        [switch]$RemoveType,

        [object]$Parent,

        [switch]$RemoveParent,

        [object[]]$AddSubIssue,

        [object[]]$RemoveSubIssue,

        [object[]]$AddBlockedBy,

        [object[]]$RemoveBlockedBy,

        [object[]]$AddBlocking,

        [object[]]$RemoveBlocking,

        [switch]$Pinned,

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

            foreach ($value in 'Milestone', 'Type', 'Parent') {
                if ($PSBoundParameters.ContainsKey($value) -and $PSBoundParameters["Remove$value"]) {
                    $noun = $value.ToLowerInvariant()
                    throw "-$value and -Remove$value cannot be used together: one sets the $noun and the other" +
                    ' removes it. Give only one.'
                }
            }

            if ($PSBoundParameters.ContainsKey('Title') -and [string]::IsNullOrWhiteSpace($Title)) {
                throw '-Title is blank, and an issue needs a title.'
            }

            $blanks = [ordered]@{
                Milestone = "a milestone's name, or leave it out." +
                ' -RemoveMilestone takes the issue out of its milestone.'
                Type      = "an issue type's name, or leave it out. -RemoveType removes the issue's type."
            }
            foreach ($value in $blanks.Keys) {
                if ($PSBoundParameters.ContainsKey($value) -and
                    [string]::IsNullOrWhiteSpace($PSBoundParameters[$value])) {
                    throw "-$value is blank: give $($blanks[$value])"
                }
            }

            $given = $PSBoundParameters.ContainsKey('Repository')
            $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
            $edits = @()
            if ($Title) {
                $edits += "--title=$Title"
            }

            if ($Milestone) {
                $edits += "--milestone=$Milestone"
            }

            if ($RemoveMilestone) {
                $edits += '--remove-milestone'
            }

            if ($Type) {
                $edits += "--type=$Type"
            }

            if ($RemoveType) {
                $edits += '--remove-type'
            }

            if ($PSBoundParameters.ContainsKey('Parent')) {
                $reference = Resolve-GitHubItemReference -Item $Parent -Kind Issue -NotPiped
                $edits += @('--parent', $reference)
            }

            if ($RemoveParent) {
                $edits += '--remove-parent'
            }

            $lists = [ordered]@{
                AddLabel       = '--add-label'
                RemoveLabel    = '--remove-label'
                AddAssignee    = '--add-assignee'
                RemoveAssignee = '--remove-assignee'
                AddProject     = '--add-project'
                RemoveProject  = '--remove-project'
            }
            foreach ($name in $lists.Keys) {
                $conversion = @{
                    Name  = $name
                    Flag  = $lists[$name]
                    Value = $PSBoundParameters[$name]
                }
                $edits += ConvertTo-GitHubIssueListArgument @conversion
            }

            $related = [ordered]@{
                '--add-sub-issue'     = 'AddSubIssue'
                '--remove-sub-issue'  = 'RemoveSubIssue'
                '--add-blocked-by'    = 'AddBlockedBy'
                '--remove-blocked-by' = 'RemoveBlockedBy'
                '--add-blocking'      = 'AddBlocking'
                '--remove-blocking'   = 'RemoveBlocking'
            }
            foreach ($flag in $related.Keys) {
                if ($PSBoundParameters.ContainsKey($related[$flag])) {
                    foreach ($item in @($PSBoundParameters[$related[$flag]])) {
                        $reference = Resolve-GitHubItemReference -Item $item -Kind Issue -NotPiped
                        $edits += @($flag, $reference)
                    }
                }
            }

            $hasBody = $PSBoundParameters.ContainsKey('Body')
            $hasPin = $PSBoundParameters.ContainsKey('Pinned')
            if ($edits.Count -eq 0 -and -not $hasBody -and -not $hasPin) {
                throw 'Say what to change - for example -Title, -Body, -AddLabel, or -Pinned.'
            }
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
            $editing = $hasBody -or $edits.Count -gt 0
            $edited = $false
            if ($editing -and $PSCmdlet.ShouldProcess($target, 'Edit issue')) {
                $edit = @{
                    Activity   = "Editing issue $reference"
                    Arguments  = @('issue', 'edit', $reference) + $edits
                    Repository = $repositoryReference
                }
                if ($hasBody) {
                    Use-GitHubTextFile -Text $Body -ScriptBlock {
                        param($Path)

                        $edit.Arguments += @('--body-file', $Path)
                        Invoke-GitHubCommand @edit | Out-Null
                    }
                }
                else {
                    Invoke-GitHubCommand @edit | Out-Null
                }

                $edited = $true
            }

            if ($hasPin) {
                $subcommand = if ($Pinned) { 'pin' } else { 'unpin' }
                $verb = if ($Pinned) { 'Pinning' } else { 'Unpinning' }
                $action = if ($Pinned) { 'Pin issue' } else { 'Unpin issue' }
                if ($PSCmdlet.ShouldProcess($target, $action)) {
                    $invocation = @{
                        Activity   = "$verb issue $reference"
                        Arguments  = @('issue', $subcommand, $reference)
                        Repository = $repositoryReference
                    }
                    try {
                        Invoke-GitHubCommand @invocation | Out-Null
                    }
                    catch {
                        if (-not $edited) {
                            throw
                        }

                        throw "Issue $reference was edited, but $($verb.ToLowerInvariant()) it failed: " +
                        $_.Exception.Message
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
            )
        }
    }
}
