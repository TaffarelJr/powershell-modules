function Get-HostFact {
    <#
    .SYNOPSIS
        Reads the three facts about this process that decide whether anyone
        can be asked a question.
    .DESCRIPTION
        Not exported. A function of its own so a test can stand in for a
        process launched a different way.
    .OUTPUTS
        A PSCustomObject with CommandLine (the arguments this process was
        started with), UserInteractive, and InputRedirected.
    #>
    return [PSCustomObject]@{
        CommandLine     = [Environment]::GetCommandLineArgs()
        UserInteractive = [Environment]::UserInteractive
        InputRedirected = [Console]::IsInputRedirected
    }
}
