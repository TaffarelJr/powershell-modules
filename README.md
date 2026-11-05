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
| [ProcessInvocation](src/TaffarelJr.ProcessInvocation)             | Runs an external command with consistent output capture and error handling.                                            | -       |
| [RequiredModules](src/TaffarelJr.RequiredModules)                 | Declares, checks, installs, updates, and imports a script's required Gallery modules.                                  | -       |
| [Tally](src/TaffarelJr.Tally)                                     | A generic named-counter utility - add, read, clear, render, and parse counts.                                          | -       |
| [TestKit](src/TaffarelJr.TestKit)                                 | A minimal, homegrown test-writing kit - assertions, tallies, and output capture.                                       | -       |
| [TestRunner](src/TaffarelJr.TestRunner)                           | Runs *.Tests.ps1 files under one or more folders in parallel, with a run summary and coverage on request.              | -       |

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
    ProcessInvocation["ProcessInvocation"]
    RequiredModules["RequiredModules"]
    Tally["Tally"]
    TestKit["TestKit"]
    TestRunner["TestRunner"]

    TestRunner --> ConsoleOutput
    TestRunner --> ProcessInvocation
    TestRunner --> RequiredModules
    TestRunner --> Tally
```
<!-- /dependency-diagram -->
