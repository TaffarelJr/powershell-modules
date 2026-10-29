function Get-GitHubWorkflow {
    <#
    .SYNOPSIS
        Returns a repository's workflows.
    .DESCRIPTION
        Disabled workflows are left out unless -All is given. To act on
        one workflow, pipe it to the other workflow functions, which read
        its Id, or pass them its Id, Name, or file name.
    .PARAMETER All
        Includes disabled workflows (gh's --all).
    .PARAMETER Limit
        The most workflows to return, at least 1. gh's default is 50.
    .PARAMETER Repository
        The repository to read, as [HOST/]OWNER/REPO, a URL, or a
        repository object. Omit it to use the current directory's
        repository; a -Repository given as $null throws.
    .INPUTS
        None
    .OUTPUTS
        System.Management.Automation.PSCustomObject
        One object per workflow - Id, Name, Path, State, and Repository,
        the repository it was read from, written OWNER/REPO
        (HOST/OWNER/REPO off github.com) however it was named, or $null
        for the current directory's.
    .EXAMPLE
        Get-GitHubWorkflow -All -Repository 'OWNER/REPO'

        Lists every workflow of OWNER/REPO, disabled ones included.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/README.md
    .LINK
        Get-GitHubWorkflowRun
    #>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([PSCustomObject])]
    param(
        [switch]$All,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Limit,

        [object]$Repository
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $repositoryReference = Resolve-GitHubRepositoryArgument -Value $Repository `
            -Given $PSBoundParameters.ContainsKey('Repository')
        $arguments = @('workflow', 'list', '--json', 'id,name,path,state')
        if ($All) {
            $arguments += '--all'
        }

        if ($PSBoundParameters.ContainsKey('Limit')) {
            $arguments += @('--limit', $Limit)
        }

        $out = Invoke-GitHubCommand -Activity 'Listing workflows' -Arguments $arguments -Repository $repositoryReference
        $items = ConvertFrom-GitHubJson -Lines $out
        $origin = $null
        if ($repositoryReference) {
            $origin = Format-GitHubRepositoryName -Repository $repositoryReference
        }

        foreach ($item in $items) {
            $item | Add-Member -NotePropertyName 'Repository' -NotePropertyValue $origin
            $item
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name)
        )
    }
}
