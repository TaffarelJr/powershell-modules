# Custom PowerShell Modules

A personal collection of independently-versioned PowerShell modules,
published to the PowerShell Gallery for reuse
in scripts and GitHub Actions workflows across my repositories.

| Module                                                    | Description                                                                                      | Version |
| :-------------------------------------------------------- | :----------------------------------------------------------------------------------------------- | :------ |
| [ConsoleOutput](src/TaffarelJr.ConsoleOutput)             | Indent-aware console status output - success/skip/warn lines, progress, banners.                 | -       |
| [FileText](src/TaffarelJr.FileText)                       | Encoding-safe text file read/write and token replacement across a directory tree.                | -       |
| [Git](src/TaffarelJr.Git)                                 | Wraps the git CLI - branches, remotes, staging, commits, push/pull, tags, merging, and stashing. | -       |
| [GitHub.Account](src/TaffarelJr.GitHub.Account)           | Wraps gh's own auth, account switching, credential-helper setup, orgs, and local config.         | -       |
| [GitHub.Core](src/TaffarelJr.GitHub.Core)                 | Shared plumbing every other TaffarelJr.GitHub.* module builds on.                                | -       |
| [GitHub.Gists](src/TaffarelJr.GitHub.Gists)               | Wraps the gh CLI for gists - create, edit, rename files, clone, and delete.                      | -       |
| [GitHub.Issues](src/TaffarelJr.GitHub.Issues)             | Wraps the gh CLI for issues - create, edit, comment, transfer, and manage their lifecycle.       | -       |
| [GitHub.PullRequests](src/TaffarelJr.GitHub.PullRequests) | Wraps the gh CLI for pull requests - create, review, merge, comment, and manage their lifecycle. | -       |
| [GitHub.Releases](src/TaffarelJr.GitHub.Releases)         | Wraps the gh CLI for releases and their assets - create, edit, publish, upload, download.        | -       |
| [GitHub.Repositories](src/TaffarelJr.GitHub.Repositories) | Wraps the gh CLI for repo admin - labels, deploy keys, rulesets, secrets, variables.             | -       |
| [GitHub.Search](src/TaffarelJr.GitHub.Search)             | Wraps the gh CLI to search code, commits, issues, pull requests, and repositories.               | -       |
| [GitHub.Workflows](src/TaffarelJr.GitHub.Workflows)       | Wraps the gh CLI for Actions - dispatch/monitor workflow runs, manage workflows, caches.         | -       |
| [ProcessInvocation](src/TaffarelJr.ProcessInvocation)     | Runs an external command with consistent output capture and error handling.                      | -       |
| [RequiredModules](src/TaffarelJr.RequiredModules)         | Declares, checks, installs, and imports a script's required Gallery modules.                     | -       |
| [Tally](src/TaffarelJr.Tally)                             | A generic named-counter utility - add, read, clear, render, and parse counts.                    | -       |
| [TestKit](src/TaffarelJr.TestKit)                         | A minimal, homegrown test-writing kit - assertions, tallies, and output capture.                 | -       |
| [TestRunner](src/TaffarelJr.TestRunner)                   | Runs a folder's Pester test files in parallel, with coverage and a run summary.                  | -       |
| [UserInput](src/TaffarelJr.UserInput)                     | Composable interactive-prompting primitives - read, validate, retry, confirm.                    | -       |
