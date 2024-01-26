# Gets the canonical case of a path on a case-insensitive file system.
param(
    # Specifies a path to one or more locations. Wildcards are permitted.
    [Parameter(Mandatory=$true,
               Position=0,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [string[]]
    $Path,
    # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
    # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
    # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
    # characters as escape sequences.
    [Parameter(Mandatory=$true,
               ParameterSetName="LiteralPath",
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Literal path to one or more locations.")]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $LiteralPath
)
begin {
    function Get-CanonicalName([System.IO.FileSystemInfo]$item) {
        $parent = $item.DirectoryName
        if (-not $parent) {
            return $item.FullName
        }

        $parentName = Get-CanonicalName (Get-Item $parent)
        $canonicalItem = Get-ChildItem $parentName | Where-Object { $_.Name -ieq $item.Name }
        $canonicalItem.FullName
    }
}

process {
    if ($Path) {
        $items = Get-Item $Path
    } else {
        $items = Get-Item -LiteralPath $LiteralPath
    }

    $items | ForEach-Object {
        Get-CanonicalName $_
    }
}