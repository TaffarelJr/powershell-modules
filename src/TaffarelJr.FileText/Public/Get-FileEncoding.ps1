function Get-FileEncoding {
    <#
    .SYNOPSIS
        Returns the encoding a file is written in,
        from the byte order mark it currently starts with.
    .DESCRIPTION
        Rewriting a file through PowerShell's own defaults is lossy:
        Set-Content writes UTF-8 without a BOM,
        so a file that had one loses it,
        and a UTF-16 file is silently transcoded.
        Reading the mark and handing it back
        keeps a content edit to just the content.
        UTF-8, UTF-16, and UTF-32 marks are recognized,
        in both byte orders where there is a choice.

        UTF-8 without a BOM is the fallback,
        which is also what .NET assumes when it decodes.
        A file in a legacy encoding such as Windows-1252 has no mark to read,
        so it is reported as UTF-8 too: Read-TextFile refuses such a file
        unless it is given the encoding to read it with.

        The marks overlap in one place: FF FE 00 00 starts both UTF-32 little
        endian and UTF-16 little endian text whose first character is U+0000.
        It is read as UTF-32, so such a UTF-16 file is reported as UTF-32 and
        Read-TextFile refuses it as not valid UTF-32 text.

        A file that cannot be inspected - missing, a folder, not on the file
        system - is a terminating error, and in a pipeline it stops the
        pipeline.
    .PARAMETER Path
        The file to inspect. A relative path is relative to PowerShell's
        current location. Path strings can be piped in, and so can files from
        Get-ChildItem (by their FullName or PSPath) and Resolve-Path output
        (by its Path).
    .INPUTS
        System.String. The path of a file; or any object with a FullName,
        PSPath, or Path property, such as the files Get-ChildItem returns.
    .OUTPUTS
        System.Text.Encoding. The encoding, which throws on text it cannot map
        instead of substituting a character.
    .EXAMPLE
        Get-FileEncoding -Path ./README.md

        Returns the encoding README.md is written in.
    .EXAMPLE
        Get-ChildItem -File -Filter *.cs -Recurse | Get-FileEncoding

        Returns the encoding of every C# file under the current folder, one
        per file, in the order they are listed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Read-TextFile
    .LINK
        Write-TextFile
    #>
    [CmdletBinding()]
    [OutputType([System.Text.Encoding])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'PSPath')]
        [string]$Path
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            $full = Resolve-TextFilePath -Path $Path -MustExist
            $head = Read-FileHead -Path $full -Count 4
            return (Get-BomEncoding -Byte $head).Encoding
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
