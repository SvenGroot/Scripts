function Resolve-Reference([string]$folder, [string]$reference, $refs) {
    if ($refs.ContainsKey($reference)) {
        Write-Host "  Already found"
        return
    }

    $original = $reference
    if ($reference.EndsWith("()")) {
        $isMethod = $true
        $reference = $reference.Substring(0, $reference.Length-2)
    }

    $reference = $reference.Replace(".", "_");
    $files = Get-ChildItem $folder | Where-Object { $_.Name -match "_$reference[_.]"} | ForEach-Object { $_.BaseName }
    if ($isMethod) {
        $matching = $files | Where-Object { $_.StartsWith("M_") -or $_.StartsWith("Overload_") }
    } else {
        $matching = $files | Where-Object { $_.StartsWith("T_") }
        if (-not $matching) {
            $matching = $files
        }
    }

    $matching | ForEach-Object {
        Write-Host "  $_"
    }

    if ($matching) {
        $refs[$original] = $matching
    } else {
        $refs[$original] = "!UNKNOWN!"
    }
}

function Resolve-Link([string]$reference, $refs, $labels) {
    if (!$refs.ContainsKey($reference)) {
        Write-Warning "Unknown reference $reference"
        Write-Host "Press a key to continue."
        $Host.UI.RawUI.ReadKey() | Out-Null
        return $null
    }

    $link = $refs[$reference]
    if (-not $link) {
        return $null
    }

    # TODO: Pick one.
    if (-not $link.GetType().IsArray) {
        $link = @($link)
    }

    return Select-Link $reference $link $labels
}

function Select-Link([string]$reference, [string[]]$links, $labels) {
    $old = $Host.UI.RawUI.ForegroundColor
    try {
        $Host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Choose link for ``$reference``:"
        for ($i = 0; $i -lt $links.Length; $i += 1) {
            Write-Host "$($i + 1). $($links[$i])"
        }

        Write-Host "0. No link."
        while ($true)
        {
            Write-Host -NoNewline "Choose a target: "
            $key = $Host.UI.RawUI.ReadKey()
            Write-Host ""

            if ($key.VirtualKeyCode -eq 0x1b) {
                throw "Aborted"
            }

            [int]$index = 0
            if ([int]::TryParse($key.Character, [ref]$index))
            {
                if ($index -eq 0) {
                    return $null
                }
                
                $index -= 1
                if ($index -ge 0 -and $index -lt $links.Length) {
                    break
                }
            }

            Write-Warning "Invalid selection."
        }

        if ($links.Length -eq 1) {
            $label = "``$reference``"
        } else {
            $label = "${reference}_$index"
        }

        $target = $links[$index]
        $labels[$label] = $target

        return $label
    }
    finally {
        $Host.UI.RawUI.ForegroundColor = $old
    }
}

function Resolve-AnchorTarget([string]$File, [string]$Anchor) {
    $contents = Get-Content $File
    foreach ($line in $contents) {
        if ($line.StartsWith("#")) {
            $lineAnchor = Get-Anchor $line
            if ($Anchor -ceq $lineAnchor) {
                return $true
            }
        }
    }

    return $false
}

function Get-Anchor([string]$Heading) {
    $started = $false
    $result = [System.Text.StringBuilder]::new()
    foreach ($char in $Heading.ToCharArray()) {
        if (-not $started -and $char -ne '#' -and $char -ne ' ') {
            $started = $true
        }

        if (-not $started) {
            continue
        }

        if ([char]::IsLetterOrDigit($char)) {
            $result.Append([char]::ToLowerInvariant($char)) | Out-Null
        } elseif ($char -eq ' ' -or $char -eq '-') {
            $result.Append('-') | Out-Null
        }
    }

    return $result.ToString()
}