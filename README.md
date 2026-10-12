# Custom PowerShell Modules

A personal collection of independently versioned PowerShell modules,
published to the PowerShell Gallery for reuse
in scripts and GitHub Actions workflows across my repositories.
Each module is versioned, released and published on its own:
a GitHub Release on the tag `<ModuleName>/vX.Y.Z` publishes that module,
built into a single file, to GitHub Packages and then to the Gallery.

| Module                                                            | Description                                                                                                            | Version |
| :---------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------- | :------ |
| [ConsoleOutput](src/TaffarelJr.ConsoleOutput)                     | Indent-aware console status output - success/skip/warn lines, progress, banners.                                       | -       |
| [FileText](src/TaffarelJr.FileText)                               | Encoding-safe text file read/write and token replacement across a directory tree.                                      | -       |
| [Git](src/TaffarelJr.Git)                                         | Wraps the git CLI - branches, remotes, staging, commits, push/pull, tags, merging, and stashing.                       | -       |
| [GitHub.Account](src/TaffarelJr.GitHub.Account)                   | Wraps gh's own auth, account switching, credential-helper setup, orgs, and local config.                               | -       |
| [GitHub.Core](src/TaffarelJr.GitHub.Core)                         | Shared plumbing the gh-based TaffarelJr.GitHub.* modules build on.                                                     | -       |
| [GitHub.Issues](src/TaffarelJr.GitHub.Issues)                     | Wraps the gh CLI for issues - create, edit, comment, transfer, and manage their lifecycle.                             | -       |
| [GitHub.PullRequests](src/TaffarelJr.GitHub.PullRequests)         | Wraps the gh CLI for pull requests - create, review, merge, comment, and manage their lifecycle.                       | -       |
| [GitHub.Releases](src/TaffarelJr.GitHub.Releases)                 | Wraps the gh CLI for releases and their assets - create, edit, publish, upload, download.                              | -       |
| [GitHub.Repositories](src/TaffarelJr.GitHub.Repositories)         | Wraps the gh CLI for repo admin - create, edit, delete, fork, sync, labels, deploy keys, rulesets, secrets, variables. | -       |
| [GitHub.Workflows](src/TaffarelJr.GitHub.Workflows)               | Wraps the gh CLI for Actions - dispatch/monitor workflow runs, manage workflows, caches.                               | -       |
| [ProcessInvocation](src/TaffarelJr.ProcessInvocation)             | Runs an external command with consistent output capture and error handling.                                            | -       |
| [RequiredModules](src/TaffarelJr.RequiredModules)                 | Declares, checks, installs, updates, and imports a script's required Gallery modules.                                  | -       |
| [Tally](src/TaffarelJr.Tally)                                     | A generic named-counter utility - add, read, clear, render, and parse counts.                                          | -       |
| [TestKit](src/TaffarelJr.TestKit)                                 | A minimal, homegrown test-writing kit - assertions, tallies, and output capture.                                       | -       |
| [TestRunner](src/TaffarelJr.TestRunner)                           | Runs *.Tests.ps1 files under one or more folders in parallel, with a run summary and coverage on request.              | -       |
| [UserInput](src/TaffarelJr.UserInput)                             | Composable interactive-prompting primitives - read, validate, retry, confirm.                                          | -       |

## Dependencies

An arrow runs from a module to each module it requires: `Git --> ProcessInvocation`
means `Git` lists `ProcessInvocation` in its manifest's `RequiredModules`,
so installing `Git` installs it too.
The diagram is generated from the manifests by `build/Get-DependencyDiagram.ps1`,
and a test fails when it differs from them,
so a pull request that adds a module also adds its node.

<!-- dependency-diagram -->
```mermaid
graph LR
    ConsoleOutput["ConsoleOutput"]
    FileText["FileText"]
    Git["Git"]
    GitHubAccount["GitHub.Account"]
    GitHubCore["GitHub.Core"]
    GitHubIssues["GitHub.Issues"]
    GitHubPullRequests["GitHub.PullRequests"]
    GitHubReleases["GitHub.Releases"]
    GitHubRepositories["GitHub.Repositories"]
    GitHubWorkflows["GitHub.Workflows"]
    ProcessInvocation["ProcessInvocation"]
    RequiredModules["RequiredModules"]
    Tally["Tally"]
    TestKit["TestKit"]
    TestRunner["TestRunner"]
    UserInput["UserInput"]

    Git --> ProcessInvocation
    GitHubAccount --> GitHubCore
    GitHubAccount --> ProcessInvocation
    GitHubCore --> ProcessInvocation
    GitHubIssues --> GitHubCore
    GitHubIssues --> ProcessInvocation
    GitHubPullRequests --> GitHubCore
    GitHubPullRequests --> ProcessInvocation
    GitHubReleases --> GitHubCore
    GitHubReleases --> ProcessInvocation
    GitHubRepositories --> GitHubCore
    GitHubRepositories --> ProcessInvocation
    GitHubWorkflows --> GitHubCore
    GitHubWorkflows --> ProcessInvocation
    TestRunner --> ConsoleOutput
    TestRunner --> ProcessInvocation
    TestRunner --> RequiredModules
    TestRunner --> Tally
    UserInput --> ConsoleOutput
```
<!-- /dependency-diagram -->
