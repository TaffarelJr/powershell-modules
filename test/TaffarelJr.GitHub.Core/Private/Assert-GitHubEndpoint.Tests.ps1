#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force -PassThru

$assert = {
    param([string]$Endpoint)
    Assert-GitHubEndpoint -Endpoint $Endpoint
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
foreach ($endpoint in 'repos/o/r', 'graphql', 'https://ghe.example.com/api/v3/user', 'a-b') {
    Assert-Equal -Expected $true -Actual (& $module $assert $endpoint) -Message "'$endpoint' passes"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - endpoints gh would read as an option
$refused = @(
    @{
        Endpoint = '--hostname'
        Like = "'--hostname' starts with '-', which gh would read as an option."
        Message = 'A leading dash is refused'
    }
    @{
        Endpoint = '-https://u:SENTINEL@ghe.example.com/x'
        Like = "'-https://***@ghe.example.com/x' starts with '-', which gh would read as an option."
        Message = 'and the endpoint is shown with its credential hidden'
    }
)

# Act / Assert
foreach ($case in $refused) {
    Assert-Throws -ScriptBlock {
        & $module $assert $case.Endpoint
    } -MessageLike ([WildcardPattern]::Escape($case.Like)) -Message $case.Message
}

exit (Complete-TestRun)
