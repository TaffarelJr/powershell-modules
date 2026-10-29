function Get-GitRepositoryVariable {
    <#
    .SYNOPSIS
        Returns the names of the environment variables that tie git to one
        repository.
    .DESCRIPTION
        The variables that select which repository git uses, or change its
        view of that repository's objects and history: git's own list of
        repository-local variables (git rev-parse --local-env-vars), plus
        GIT_NAMESPACE, without the two that only add configuration values
        (GIT_CONFIG_COUNT, GIT_CONFIG_PARAMETERS). GIT_CONFIG is in the list:
        it carries no setting, but points git config at another file in
        place of the repository's. A git hook inherits several of them; any
        one left set would make git read another repository's index,
        objects, history or config file in place of the one it is pointed
        at. Configuration passed through the environment, such as an auth
        header in GIT_CONFIG_KEY_0, still applies.
    .OUTPUTS
        The variable names, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    'GIT_ALTERNATE_OBJECT_DIRECTORIES'
    'GIT_COMMON_DIR'
    'GIT_CONFIG'
    'GIT_DIR'
    'GIT_GRAFT_FILE'
    'GIT_IMPLICIT_WORK_TREE'
    'GIT_INDEX_FILE'
    'GIT_NAMESPACE'
    'GIT_NO_REPLACE_OBJECTS'
    'GIT_OBJECT_DIRECTORY'
    'GIT_PREFIX'
    'GIT_REPLACE_REF_BASE'
    'GIT_SHALLOW_FILE'
    'GIT_WORK_TREE'
}
