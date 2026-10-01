using namespace System.IO
using namespace System.Management.Automation

# Shared by this module's tests: a throwaway folder, a file made from bytes, and
# a stand-in for the folder listing. A test-only fixture - nothing here is
# exported. Use-SplitLocation, for making a relative path go astray, is
# TaffarelJr.TestKit's.

function New-FileTextSandbox {
    <#
    .SYNOPSIS
        Creates an empty folder under the temp folder for one test to work in.
    .OUTPUTS
        The folder's full path.
    #>
    $path = Join-Path ([Path]::GetTempPath()) "filetext-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Remove-FileTextSandbox {
    <#
    .SYNOPSIS
        Deletes a folder New-FileTextSandbox made, read-only and hidden files
        and links included.
    .DESCRIPTION
        A folder link is deleted on its own first, so nothing it points at is
        deleted through it, and every other file's attributes are reset, so a
        read-only, hidden, or system file cannot stop the delete.
    .PARAMETER Path
        The folder.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $items = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue)
    foreach ($item in $items) {
        $isLink = $item.LinkType -in 'SymbolicLink', 'Junction'
        if ($isLink -and $item.PSIsContainer) {
            [Directory]::Delete($item.FullName)
        }
        elseif (-not $isLink -and -not $item.PSIsContainer) {
            $item.Attributes = [FileAttributes]::Normal
        }
    }

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
}

function New-TestFile {
    <#
    .SYNOPSIS
        Writes a file holding exactly the given bytes.
    .PARAMETER Directory
        The folder to put it in.
    .PARAMETER Name
        The file name.
    .PARAMETER Byte
        What the file holds.
    .OUTPUTS
        The file's full path.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Byte
    )

    $path = Join-Path $Directory $Name
    [File]::WriteAllBytes($path, $Byte)
    return $path
}

function Lock-TestFile {
    <#
    .SYNOPSIS
        Opens a file so that nothing else can read or write it, as a program
        that holds it open does.
    .DESCRIPTION
        The lock lasts until the returned stream is disposed: dispose it in a
        finally block.
    .PARAMETER Path
        The file.
    .OUTPUTS
        The open stream.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return [File]::Open($Path, [FileMode]::Open, [FileAccess]::ReadWrite, [FileShare]::None)
}

function Install-DirectoryListingStub {
    <#
    .SYNOPSIS
        Replaces the module's folder listing with one that records each folder it
        is asked about, and fails for the one a test names.
    .DESCRIPTION
        Each test file runs in its own process, so the replacement never needs
        undoing. It lets a test make a folder unreadable on any platform, and
        see which folders the walk went into.
    .PARAMETER Module
        The imported TaffarelJr.FileText module.
    .PARAMETER FailFor
        A folder whose listing throws.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module,

        [string]$FailFor
    )

    & $Module {
        param($failFor)
        $script:VisitedFolders = [System.Collections.Generic.List[string]]::new()
        $script:FolderToFail = $failFor
        function script:Get-DirectoryEntry {
            param($Path)
            $script:VisitedFolders.Add($Path)
            if ($script:FolderToFail -and $Path -eq $script:FolderToFail) {
                throw 'Access to the path is denied.'
            }

            return Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop
        }
    } $FailFor
}

function Get-VisitedFolder {
    <#
    .SYNOPSIS
        Returns the folders the walk has listed since Install-DirectoryListingStub.
    .PARAMETER Module
        The imported TaffarelJr.FileText module.
    .OUTPUTS
        The folders' full paths, one at a time.
    #>
    param(
        [Parameter(Mandatory)]
        [PSModuleInfo]$Module
    )

    return & $Module { $script:VisitedFolders.ToArray() }
}

function Get-FileTextTreeState {
    <#
    .SYNOPSIS
        Returns every item under a folder with its content, to tell whether
        anything in it changed.
    .PARAMETER Path
        The folder.
    .OUTPUTS
        One line per item, sorted: its path relative to the folder, and for a
        file its bytes in hex.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $items = @(Get-ChildItem -LiteralPath $Path -Recurse -Force)
    $lines = foreach ($item in $items) {
        $relative = [Path]::GetRelativePath($Path, $item.FullName)
        if ($item.PSIsContainer) {
            "$relative/"
        }
        else {
            "$relative = $([Convert]::ToHexString([File]::ReadAllBytes($item.FullName)))"
        }
    }

    return @($lines | Sort-Object)
}

function New-UnaskableCmdlet {
    <#
    .SYNOPSIS
        Returns a PSCmdlet whose ShouldProcess throws, as a -Confirm prompt
        does where no one can answer it.
    .DESCRIPTION
        Hands the private helpers a caller that cannot ask, in this process,
        whatever the host: a real prompt would wait for an answer when a test
        file is run by hand. A PowerShell class cannot implement an interface
        method with an out parameter, so the stand-in is compiled from C#, once
        per process.
    .PARAMETER Message
        What ShouldProcess throws.
    .OUTPUTS
        The PSCmdlet.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not ('FileTextUnaskableCmdlet' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Management.Automation;
using System.Management.Automation.Host;

public sealed class FileTextUnaskableRuntime : ICommandRuntime
{
    private readonly string message;

    public FileTextUnaskableRuntime(string message) { this.message = message; }

    public PSHost Host { get { return null; } }
    public PSTransactionContext CurrentPSTransaction { get { return null; } }
    public void WriteDebug(string text) { }
    public void WriteError(ErrorRecord errorRecord) { }
    public void WriteObject(object sendToPipeline) { }
    public void WriteObject(object sendToPipeline, bool enumerateCollection) { }
    public void WriteProgress(ProgressRecord progressRecord) { }
    public void WriteProgress(long sourceId, ProgressRecord progressRecord) { }
    public void WriteVerbose(string text) { }
    public void WriteWarning(string text) { }
    public void WriteCommandDetail(string text) { }
    public bool ShouldProcess(string target) { throw new PSInvalidOperationException(message); }
    public bool ShouldProcess(string target, string action) { throw new PSInvalidOperationException(message); }
    public bool ShouldProcess(string description, string warning, string caption)
    {
        throw new PSInvalidOperationException(message);
    }
    public bool ShouldProcess(string description, string warning, string caption, out ShouldProcessReason reason)
    {
        throw new PSInvalidOperationException(message);
    }
    public bool ShouldContinue(string query, string caption) { throw new PSInvalidOperationException(message); }
    public bool ShouldContinue(string query, string caption, ref bool yesToAll, ref bool noToAll)
    {
        throw new PSInvalidOperationException(message);
    }
    public bool TransactionAvailable() { return false; }
    public void ThrowTerminatingError(ErrorRecord errorRecord) { throw errorRecord.Exception; }
}

public sealed class FileTextUnaskableCmdlet : PSCmdlet
{
    public FileTextUnaskableCmdlet(string message) { CommandRuntime = new FileTextUnaskableRuntime(message); }
}
'@
    }

    return [FileTextUnaskableCmdlet]::new($Message)
}

function New-TestLink {
    <#
    .SYNOPSIS
        Creates a symbolic link, or returns $null when this machine does not
        allow one.
    .DESCRIPTION
        Windows only lets an ordinary user make a link in Developer Mode, so
        the tests that need one ask first and skip themselves when it says no.
    .PARAMETER Path
        Where the link goes.
    .PARAMETER Target
        What it points at.
    .OUTPUTS
        The link, or $null.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Target
    )

    try {
        return New-Item -ItemType SymbolicLink -Path $Path -Target $Target -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Install-VerboseCaller {
    <#
    .SYNOPSIS
        Imports a module of its own whose functions call this module's public
        functions, as a command of another module does.
    .DESCRIPTION
        -Verbose and the verbose preference of a function in one module do not
        reach a command in another by themselves, so these callers show whether
        this module reads the preference of whoever calls it. Each test file
        runs in its own process, so the module never needs removing.
    #>
    param()

    $null = New-Module -Name FileTextVerboseCallers -ScriptBlock {
        function Invoke-WriteTextFileCaller {
            [CmdletBinding()]
            param($Path, $Content)

            Write-TextFile -Path $Path -Content $Content
        }

        function Invoke-UpdateFileTokenCaller {
            [CmdletBinding()]
            param($Path, $From, $To)

            Update-FileToken -Path $Path -From $From -To $To
        }

        function Invoke-RenameTokenCaller {
            [CmdletBinding()]
            param($Path, $From, $To)

            Rename-Token -Path $Path -From $From -To $To
        }
    }
}
