function New-GitHubRepository {
    <#
    .SYNOPSIS
        Creates a repository on GitHub.
    .DESCRIPTION
        Everything gh would otherwise prompt for is a parameter here, so
        the call never stalls; -Visibility is mandatory for that reason.
    .PARAMETER Name
        The new repository's name, as NAME or OWNER/NAME. Without an
        owner, the authenticated user owns it.
    .PARAMETER Visibility
        public, private, or internal.
    .PARAMETER Description
        The repository description.
    .PARAMETER Homepage
        The repository's home page URL.
    .PARAMETER AddReadme
        Starts the repository with a README.
    .PARAMETER Gitignore
        A .gitignore template name to start from, such as 'VisualStudio'.
    .PARAMETER License
        A license keyword to start from, such as 'mit'.
    .PARAMETER Template
        A template repository, as OWNER/NAME, to create from.
    .PARAMETER IncludeAllBranches
        Copies every branch from the template, not just its default.
    .PARAMETER DisableIssues
        Turns issues off.
    .PARAMETER DisableWiki
        Turns the wiki off.
    .PARAMETER Team
        An organization team to grant access to.
    .PARAMETER Source
        A local repository to create the remote one from.
    .PARAMETER Remote
        The git remote name to add to -Source for the new repository.
    .PARAMETER Push
        Pushes -Source's local commits to the new repository.
    .PARAMETER Clone
        Clones the new repository into the current directory.
    .OUTPUTS
        The new repository's URL.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('public', 'private', 'internal')]
        [string]$Visibility,

        [string]$Description,

        [string]$Homepage,

        [switch]$AddReadme,

        [string]$Gitignore,

        [string]$License,

        [string]$Template,

        [switch]$IncludeAllBranches,

        [switch]$DisableIssues,

        [switch]$DisableWiki,

        [string]$Team,

        [string]$Source,

        [string]$Remote,

        [switch]$Push,

        [switch]$Clone
    )

    $arguments = @('repo', 'create', $Name, "--$Visibility")
    if ($Description) {
        $arguments += @('--description', $Description)
    }

    if ($Homepage) {
        $arguments += @('--homepage', $Homepage)
    }

    if ($AddReadme) {
        $arguments += '--add-readme'
    }

    if ($Gitignore) {
        $arguments += @('--gitignore', $Gitignore)
    }

    if ($License) {
        $arguments += @('--license', $License)
    }

    if ($Template) {
        $arguments += @('--template', $Template)
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
        $arguments += @('--team', $Team)
    }

    if ($Source) {
        $arguments += @('--source', $Source)
    }

    if ($Remote) {
        $arguments += @('--remote', $Remote)
    }

    if ($Push) {
        $arguments += '--push'
    }

    if ($Clone) {
        $arguments += '--clone'
    }

    $out = Invoke-GitHubCommand -Activity "Creating repository $Name" -Arguments $arguments
    return $out | Where-Object { $_ -match '^https?://' } | Select-Object -First 1
}
