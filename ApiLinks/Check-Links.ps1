param(
    # Specifies a path to one or more locations.
    [Parameter(Mandatory=$true,
               Position=0,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
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
    class LinkInfo {
        [string]$Path
        [int]$Line
        [string]$Link
        [string]$Warning
    }

    $invalidLinks = [System.Collections.Concurrent.ConcurrentBag[LinkInfo]]::new()
}
process {
    if ($Path) {
        $items = Get-Item -Path $Path
    } else {
        $items = Get-Item -LiteralPath $LiteralPath
    }

    foreach ($item in $items) {
        $inCode = $false
        $line = 0
        $links = Get-Content $item | ForEach-Object {
            $line += 1
            if ($_.StartsWith('```')) {
                $inCode = -not $inCode
            }

            if (-not $inCode) {                
                $m = $_ | Select-String '(?<!!)\[.*?\]\((?<link>.*?)\)' -AllMatches -CaseSensitive
                if ($m) {
                    $m.Matches | ForEach-Object {
                        $linkInfo = [LinkInfo]::new()
                        $linkInfo.Path = $item.FullName
                        $linkInfo.Line = $line
                        $linkInfo.Link = $_.Groups["link"].Value
                        $linkInfo
                    }
                }

                if ($_ -match "\[[^\]]*$") {
                    Write-Warning "Possible multiline link not checked: $_"
                    $linkInfo = [LinkInfo]::new()
                    $linkInfo.Path = $item.FullName
                    $linkInfo.Line = $line
                    $linkInfo.Warning = "Possible multiline link not checked"
                    $invalidLinks.Add($linkInfo)
                }

                if ($_ -match "^\[[^^][^\]]*\]:\s*(?<link>.*)$") {
                    $linkInfo = [LinkInfo]::new()
                    $linkInfo.Path = $item.FullName
                    $linkInfo.Line = $line
                    $linkInfo.Link = $Matches["link"]
                    $linkInfo
                }
            }
        }

        $links | Foreach-Object -Parallel {
            $invalid = $using:invalidLinks
            $info = $_
            $link = $info.Link
            $index = $link.IndexOf("#")
            $anchor = $null
            if ($index -ge 0) {
                $link = $link.Substring(0, $index)
                $anchor = $_.Link.Substring($index + 1)
            }

            if ($link.Contains("\")) {
                Write-Warning "Contains backslash: $link"
                $info.Warning = "Contains backslash"
                $invalid.Add($info)
            }

            if ($link.Contains("://")) {
                $result = Invoke-WebRequest -SkipHttpErrorCheck $link
                if ($result.StatusCode -eq 200) {
                    Write-Host "OK: $link"
                } else {
                    Write-Warning "Status $($result.StatusCode): $link"
                    $info.Warning = "Status $($result.StatusCode)"
                    $invalid.Add($info)
                }
            } else {
                if ($link -eq "") {
                    $fullPath = $using:item.FullName
                } else {
                    $fullPath = Join-Path $using:item.DirectoryName $link
                    $pathTail = $link.Replace("/", "\")
                    while ($pathTail.StartsWith("..\")) {
                        $pathTail = $pathTail.Substring(3)
                    }
                }

                if ($link -eq "" -or (Test-Path $fullPath)) {
                    . "$using:PSScriptRoot/common.ps1"
                    if ($anchor -and (-not (Resolve-AnchorTarget $fullPath $anchor))) {
                        Write-Warning "Anchor not found: $($_.Link)"
                        $info.Warning = "Anchor not found"
                        $invalid.Add($info)
                    } else {
                        $canonical = &"$using:PSScriptRoot/../Get-CanonicalPath.ps1" $fullPath
                        if ($link -eq "" -or $canonical.EndsWith($pathTail)) {
                            Write-Host "OK: $($_.Link)"

                        } else {
                            Write-Warning "Wrong case: $link ($fullPath != $canonical)"
                            $info.Warning = "Wrong case ($fullPath != $canonical)"
                            $invalid.Add($info)
                        }
                    }
                } else {
                    Write-Warning "Not found: $link"
                    $info.Warning = "Not found"
                    $invalid.Add($info)
            }
            }
        }
    }
}
end {
    Write-Host ""
    if ($invalidLinks.Count -eq 0) {
        $color = "Green"
    } else {
        $color = "Yellow"
    }

    Write-Host "$($invalidLinks.Count) warnings" -ForegroundColor $color
    $invalidLinks | ForEach-Object {
        Write-Host "$($_.Path):$($_.Line) $($_.Link): $($_.Warning)" -ForegroundColor $color
    }
}