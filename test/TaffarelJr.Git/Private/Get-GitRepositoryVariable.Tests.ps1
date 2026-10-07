#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - git's repository-local variables, without the two that only add
# configuration values, plus GIT_NAMESPACE
$expected = @(
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
)

# Act
$listed = @(& $module { Get-GitRepositoryVariable })

# Assert
Assert-Equal -Expected ($expected -join ', ') -Actual ($listed -join ', ') `
    -Message 'The list holds the variables that select a repository or change its view of history'
Assert-That -Condition ($listed -notcontains 'GIT_CONFIG_COUNT' -and $listed -notcontains 'GIT_CONFIG_PARAMETERS') `
    -Message 'and none that only adds configuration values'

exit (Complete-TestRun)
