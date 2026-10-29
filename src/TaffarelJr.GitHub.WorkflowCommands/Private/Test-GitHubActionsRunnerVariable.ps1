function Test-GitHubActionsRunnerVariable {
    <#
    .SYNOPSIS
        Tells whether the runner sets an environment variable for every step
        itself, over any value GITHUB_ENV gave it.
    .DESCRIPTION
        Not exported. The runner builds each step's environment from
        GITHUB_ENV first, then writes over it: GITHUB_<KEY> for each github
        context key on its allowlist (GitHubContext.cs), RUNNER_<KEY> for
        each runner context key, and GITHUB_ACTIONS. Every other GITHUB_ or
        RUNNER_ name, GITHUB_TOKEN among them, reaches later steps as
        written. CI is set only when nothing else has set it, so it is not
        one of them.
    .PARAMETER Name
        The variable's name.
    .PARAMETER IgnoreCase
        Compares names in any casing, as Windows does; without it, only the
        runner's own casing matches, as on Linux and macOS.
    .OUTPUTS
        True if the runner sets the variable itself.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$IgnoreCase
    )

    $githubKeys = @(
        'ACTION', 'ACTION_PATH', 'ACTION_REF', 'ACTION_REPOSITORY', 'ACTOR', 'ACTOR_ID', 'API_URL', 'ARTIFACTS',
        'ARTIFACTS_LIST', 'BASE_REF', 'ENV', 'EVENT_NAME', 'EVENT_PATH', 'GRAPHQL_URL', 'HEAD_REF', 'JOB', 'OUTPUT',
        'PATH', 'REF', 'REF_NAME', 'REF_PROTECTED', 'REF_TYPE', 'REPOSITORY', 'REPOSITORY_ID', 'REPOSITORY_OWNER',
        'REPOSITORY_OWNER_ID', 'RETENTION_DAYS', 'RUN_ATTEMPT', 'RUN_ID', 'RUN_NUMBER', 'SERVER_URL', 'SHA', 'STATE',
        'STEP_SUMMARY', 'TRIGGERING_ACTOR', 'WORKFLOW', 'WORKFLOW_REF', 'WORKFLOW_SHA', 'WORKSPACE'
    )
    $runnerKeys = @('ARCH', 'DEBUG', 'ENVIRONMENT', 'NAME', 'OS', 'TEMP', 'TOOL_CACHE', 'WORKSPACE')
    $names = [System.Collections.Generic.List[string]]::new()
    $names.Add('GITHUB_ACTIONS')
    foreach ($key in $githubKeys) {
        $names.Add("GITHUB_$key")
    }

    foreach ($key in $runnerKeys) {
        $names.Add("RUNNER_$key")
    }

    if ($IgnoreCase) {
        return $Name -in $names
    }

    return $Name -cin $names
}
