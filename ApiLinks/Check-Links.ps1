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
process {
    if ($Path) {
        $items = Get-Item -Path $Path
    } else {
        $items = Get-Item -LiteralPath $LiteralPath
    }

    foreach ($item in $items) {
        $inCode = $false
        $links = Get-Content $item | ForEach-Object {
            if ($_.StartsWith('```')) {
                $inCode = -not $inCode
            }

            if (-not $inCode) {
                $m = $_ | Select-String '(?<!!)\[.*?\]\((?<link>.*?)\)' -AllMatches -CaseSensitive
                if ($m) {
                    $m.Matches | ForEach-Object {
                        $_.Groups["link"].Value
                    }
                }

                if ($_ -match "\[[^\]]*$") {
                    Write-Warning "Possible multiline link not checked: $_"
                }

                if ($_ -match "^\[[^\]]*\]:\s*(?<link>.*)$") {
                    $Matches["link"]
                }
            }
        }

        $links | Foreach-Object -Parallel {
            $link = $_
            $index = $link.IndexOf("#")
            $anchor = $null
            if ($index -ge 0) {
                $link = $link.Substring(0, $index)
                $anchor = $_.Substring($index + 1)
            }

            if ($link.Contains("://")) {
                $result = Invoke-WebRequest -SkipHttpErrorCheck $link
                if ($result.StatusCode -eq 200) {
                    Write-Host "OK: $link"
                } else {
                    Write-Warning "Status $($result.StatusCode): $link"
                }
            } else {
                if ($link -eq "") {
                    $fullPath = $using:item.FullName
                } else {
                    $fullPath = Join-Path $using:item.DirectoryName $link
                }

                if ($link -eq "" -or (Test-Path $fullPath)) {
                    . "$using:PSScriptRoot/common.ps1"
                    if ($anchor -and (-not (Resolve-AnchorTarget $fullPath $anchor))) {
                        Write-Warning "Anchor not found: $_"
                    } else {
                        Write-Host "OK: $_"
                    }
                } else {
                    Write-Warning "Not found: $link"
                }
            }
        }
    }
}