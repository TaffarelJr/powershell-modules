function New-GitHubIssue {
    <#
    .SYNOPSIS
        Opens an issue.
    .DESCRIPTION
        The body reaches gh through a temporary file, so it arrives
        exactly as given: any length, line endings as they are, and nothing
        added at the end. gh needs both a title and a body when it cannot
        prompt, which it never can here. There is no -Template for the same
        reason: gh offers a template only along with its own prompts, and
        refuses it next to a body.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Title
        The issue's title. The one parameter that can be given by position.
        A blank one throws.
    .PARAMETER Body
        The issue's body, as Markdown. An empty string is a body with
        nothing in it.
    .PARAMETER Assignee
        Users to assign, by login. '@me' is the authenticated user.
    .PARAMETER Label
        Labels to add.
    .PARAMETER Milestone
        A milestone to add the issue to, by name. A blank one throws.
    .PARAMETER Project
        Projects to add the issue to, by title. Needs a token with the
        project scope.
    .PARAMETER Type
        The issue type, by name. A blank one throws. Needs gh 2.94 or
        later.
    .PARAMETER Parent
        Makes the new issue a sub-issue of this parent: its number or URL,
        or an issue object. Needs gh 2.94 or later.
    .PARAMETER BlockedBy
        Issues this issue is blocked by: numbers, URLs, or issue objects.
        Needs gh 2.94 or later.
    .PARAMETER Blocking
        Issues this issue blocks: numbers, URLs, or issue objects. Needs gh
        2.94 or later.
    .PARAMETER Repository
        The repository to open it in, in [HOST/]OWNER/REPO form or as a
        URL, or a repository object. Omit it to use the current directory's
        repository; given as $null, it throws.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None.
    .OUTPUTS
        System.String
        The new issue's URL.
    .EXAMPLE
        $issue = @{
            Title      = 'Flaky test'
            Body       = 'Fails one run in ten.'
            Label      = 'bug'
            Repository = 'OWNER/REPO'
        }
        New-GitHubIssue @issue

        Opens an issue in OWNER/REPO labeled bug, and returns its URL.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/README.md
    .LINK
        Get-GitHubIssue
    #>
    [CmdletBinding(SupportsShouldProcess, PositionalBinding = $false)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Title,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Body,

        [string[]]$Assignee,

        [string[]]$Label,

        [string]$Milestone,

        [string[]]$Project,

        [string]$Type,

        [object]$Parent,

        [object[]]$BlockedBy,

        [object[]]$Blocking,

        [object]$Repository
    )

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

        if ([string]::IsNullOrWhiteSpace($Title)) {
            throw '-Title is blank, and an issue needs a title.'
        }

        $names = [ordered]@{
            Milestone = "a milestone's name"
            Type      = "an issue type's name"
        }
        foreach ($name in $names.Keys) {
            if ($PSBoundParameters.ContainsKey($name) -and [string]::IsNullOrWhiteSpace($PSBoundParameters[$name])) {
                throw "-$name is blank: give $($names[$name]), or leave it out."
            }
        }

        $given = $PSBoundParameters.ContainsKey('Repository')
        $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository -Given $given
        $arguments = @('issue', 'create', "--title=$Title")
        $lists = [ordered]@{
            Assignee = '--assignee'
            Label    = '--label'
            Project  = '--project'
        }
        foreach ($name in $lists.Keys) {
            $conversion = @{
                Name  = $name
                Flag  = $lists[$name]
                Value = $PSBoundParameters[$name]
            }
            $arguments += ConvertTo-GitHubIssueListArgument @conversion
        }

        if ($Milestone) {
            $arguments += "--milestone=$Milestone"
        }

        if ($Type) {
            $arguments += "--type=$Type"
        }

        if ($PSBoundParameters.ContainsKey('Parent')) {
            $reference = Resolve-GitHubItemReference -Item $Parent -Kind Issue -NotPiped
            $arguments += @('--parent', $reference)
        }

        $related = [ordered]@{
            '--blocked-by' = 'BlockedBy'
            '--blocking'   = 'Blocking'
        }
        foreach ($flag in $related.Keys) {
            if ($PSBoundParameters.ContainsKey($related[$flag])) {
                foreach ($item in @($PSBoundParameters[$related[$flag]])) {
                    $reference = Resolve-GitHubItemReference -Item $item -Kind Issue -NotPiped
                    $arguments += @($flag, $reference)
                }
            }
        }

        $target = "the current directory's repository"
        if ($repositoryReference) {
            $target = Format-GitHubRepositoryName -Repository $repositoryReference
        }

        $shownTitle = Hide-UrlCredential -Text $Title
        if (-not $PSCmdlet.ShouldProcess($target, "Create issue '$shownTitle'")) {
            return
        }

        $out = Use-GitHubTextFile -Text $Body -ScriptBlock {
            param($Path)

            $invocation = @{
                Activity   = 'Creating the issue'
                Arguments  = $arguments + @('--body-file', $Path)
                Repository = $repositoryReference
            }
            Invoke-GitHubCommand @invocation
        }
        return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
