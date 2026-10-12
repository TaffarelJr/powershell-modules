@{
    RootModule        = 'TaffarelJr.GitHub.PullRequests.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'c3b4d5e6-f7a8-4192-a314-c5d6e7f8a9b0'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI for pull requests: create, review, merge, comment, and manage their lifecycle.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Add-GitHubPullRequestComment'
        'Close-GitHubPullRequest'
        'Get-GitHubPullRequest'
        'Get-GitHubPullRequestCheck'
        'Get-GitHubPullRequestDiff'
        'Get-GitHubPullRequestStatus'
        'Lock-GitHubPullRequest'
        'Merge-GitHubPullRequest'
        'New-GitHubPullRequest'
        'Open-GitHubPullRequest'
        'Set-GitHubPullRequest'
        'Submit-GitHubPullRequestReview'
        'Switch-GitHubPullRequest'
        'Unlock-GitHubPullRequest'
        'Update-GitHubPullRequestBranch'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'PullRequest')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}