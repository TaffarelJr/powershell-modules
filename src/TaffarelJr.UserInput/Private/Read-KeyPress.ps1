function Read-KeyPress {
    <#
    .SYNOPSIS
        Waits for one key and discards it, without echoing it.
    .DESCRIPTION
        Not exported. A function of its own so a test can stand in for a key
        press without a console to press it on.
    #>
    $null = [Console]::ReadKey($true)
}
