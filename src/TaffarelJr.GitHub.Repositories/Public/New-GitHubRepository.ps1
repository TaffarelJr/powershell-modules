function New-GitHubRepository {
    <#
    .SYNOPSIS
        Creates a repository on GitHub.
    .DESCRIPTION
        -Visibility is mandatory: gh refuses to create a repository
        without one when it cannot ask.

        -Clone, -Push, and -Source run git, which can stop to ask for
        credentials or an SSH passphrase; nothing here answers it, so have
        those set up before a run nobody watches.

        With -WhatIf nothing is changed and nothing is returned.
    .PARAMETER Name
        The new repository's name, as NAME or OWNER/NAME. Without an
        owner, the authenticated user owns it. A blank one is refused.
    .PARAMETER Visibility
        public, private, or internal.
    .PARAMETER Description
        The repository description. A blank one is refused.
    .PARAMETER Homepage
        The repository's home page URL. A blank one is refused.
    .PARAMETER AddReadme
        Starts the repository with a README.
    .PARAMETER Gitignore
        A .gitignore template name to start from, such as 'VisualStudio'.
        A blank one is refused.
    .PARAMETER License
        A license keyword to start from, such as 'mit'. A blank one is
        refused.
    .PARAMETER Template
        A template repository to create from - gh's --template - as
        [HOST/]OWNER/REPO, a URL, or a repository object. A blank one is
        refused.
    .PARAMETER IncludeAllBranches
        Copies every branch from the template, not just its default.
    .PARAMETER DisableIssues
        Turns issues off.
    .PARAMETER DisableWiki
        Turns the wiki off.
    .PARAMETER Team
        An organization team to grant access to. A blank one is refused.
    .PARAMETER Source
        A local repository folder to create the remote one from - gh's
        --source. A relative path is read from PowerShell's location, and
        ~ is the home folder. A blank one is refused.
    .PARAMETER RemoteName
        The name of the git remote to add to -Source for the new
        repository - gh's --remote. Also accepted as -Remote. A blank one
        is refused.
    .PARAMETER Push
        Pushes -Source's local commits to the new repository.
    .PARAMETER Clone
        Clones the new repository into the current directory.
    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not run.
    .PARAMETER Confirm
        Prompts for confirmation before the command runs.
    .INPUTS
        None. The repository is described by parameters.
    .OUTPUTS
        System.String
        The new repository's URL.
    .EXAMPLE
        New-GitHubRepository -Name 'OWNER/NEW-REPO' -Visibility private

        Creates a private repository and returns its URL.
    .EXAMPLE
        New-GitHubRepository -Name 'NEW-REPO' -Visibility public `
            -Template 'OWNER/TEMPLATE' -Description 'A short summary'

        Creates a public repository from the template under the
        authenticated user's account.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/README.md
    .LINK
        Set-GitHubRepository
    .LINK
        Remove-GitHubRepository
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [ValidateScript({ Assert-GitHubNotOption -Value $_ })]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('public', 'private', 'internal')]
        [string]$Visibility,

        [string]$Description,

        [string]$Homepage,

        [switch]$AddReadme,

        [string]$Gitignore,

        [string]$License,

        [object]$Template,

        [switch]$IncludeAllBranches,

        [switch]$DisableIssues,

        [switch]$DisableWiki,

        [string]$Team,

        [string]$Source,

        [Alias('Remote')]
        [string]$RemoteName,

        [switch]$Push,

        [switch]$Clone
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

        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw "-Name is blank: give the new repository's name."
        }

        $blank = [ordered]@{
            Description = 'a description'
            Homepage    = 'a home page URL'
            Gitignore   = 'a .gitignore template name'
            License     = 'a license keyword'
            Template    = 'OWNER/REPO, HOST/OWNER/REPO, or a URL'
            Team        = 'a team name'
            Source      = 'a local repository folder'
            RemoteName  = 'a remote name'
        }
        foreach ($option in $blank.PSBase.Keys) {
            $value = $PSBoundParameters[$option]
            $items = @($value)
            $filled = @($items | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $onlyBlank = $items.Count -gt 0 -and $filled.Count -eq 0
            if ($PSBoundParameters.ContainsKey($option) -and ($null -eq $value -or $onlyBlank)) {
                throw "-$option is blank: give $($blank[$option]), or leave it out."
            }
        }

        $templateReference = ConvertTo-GitHubRepositoryReference -Repository $Template -Name 'Template'
        $sourcePath = $null
        if ($Source) {
            $sourcePath = Resolve-GitHubPath -Path $Source
        }

        $arguments = @('repo', 'create', $Name, "--$($Visibility.ToLowerInvariant())")
        if ($Description) {
            $arguments += "--description=$Description"
        }

        if ($Homepage) {
            $arguments += "--homepage=$Homepage"
        }

        if ($AddReadme) {
            $arguments += '--add-readme'
        }

        if ($Gitignore) {
            $arguments += "--gitignore=$Gitignore"
        }

        if ($License) {
            $arguments += "--license=$License"
        }

        if ($templateReference) {
            $arguments += "--template=$templateReference"
        }

        if ($IncludeAllBranches) {
            $arguments += '--include-all-branches'
        }

        if ($DisableIssues) {
            $arguments += '--disable-issues'
        }

        if ($DisableWiki) {
            $arguments += '--disable-wiki'
        }

        if ($Team) {
            $arguments += "--team=$Team"
        }

        if ($sourcePath) {
            $arguments += "--source=$sourcePath"
        }

        if ($RemoteName) {
            $arguments += "--remote=$RemoteName"
        }

        if ($Push) {
            $arguments += '--push'
        }

        if ($Clone) {
            $arguments += '--clone'
        }

        $action = "Create $($Visibility.ToLowerInvariant()) repository"
        if ($templateReference) {
            $action += " from template $(Format-GitHubRepositoryName -Repository $templateReference)"
        }

        $here = $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
        $effects = @()
        if ($sourcePath) {
            $remote = 'a remote'
            if ($RemoteName) {
                $remote = "remote $(Hide-UrlCredential -Text $RemoteName)"
            }

            $shownSource = Resolve-GitHubPath -Path (Hide-UrlCredential -Text $Source)
            $effects += "adding it as $remote of $shownSource"
        }

        if ($Push) {
            $effects += 'pushing the local commits to it'
        }

        if ($Clone) {
            $effects += "cloning it into a new folder in $here"
        }

        if ($effects.Count -gt 0) {
            $action += ", $($effects -join ' and ')"
        }

        $shownName = Hide-UrlCredential -Text $Name
        if (-not $PSCmdlet.ShouldProcess($shownName, $action)) {
            return
        }

        $out = Invoke-GitHubCommand -Activity "Creating repository $shownName" -Arguments $arguments
        $urls = @($out | Where-Object { $_ -match '^https?://' })
        if ($urls.Count -eq 0) {
            return
        }

        return $urls[0]
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
