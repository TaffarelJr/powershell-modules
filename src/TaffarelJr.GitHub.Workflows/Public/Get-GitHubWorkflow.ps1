function Get-GitHubWorkflow {
    <#
    .SYNOPSIS
        Returns a repository's workflows.
    .DESCRIPTION
        Disabled workflows are left out unless -All is given. To act on
        one workflow, pass its Id, Name, or Path to the other workflow
        functions.
    .PARAMETER All
        Includes disabled workflows.
    .PARAMETER Limit
        The most workflows to return. gh's default is 50.
    .PARAMETER Repository
        The repository to read, in [HOST/]OWNER/REPO form. Omit it to use
        the current directory's repository.
    .OUTPUTS
        One object per workflow - Id, Name, Path, State - always an
        array.
    #>
    param(
        [switch]$All,

        [int]$Limit,

        [string]$Repository
    )

    $arguments = @('workflow', 'list', '--json', 'id,name,path,state')
    if ($All) {
        $arguments += '--all'
    }

    if ($Limit -gt 0) {
        $arguments += @('--limit', $Limit)
    }

    $out = Invoke-GitHubCommand -Activity 'Listing workflows' -Arguments $arguments -Repository $Repository
    $workflows = ConvertFrom-GitHubJson -Lines $out
    return , @($workflows)
}
