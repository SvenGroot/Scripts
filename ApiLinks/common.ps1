$script:frameworkRefs = $null

function Get-FrameworkRefs() {
    if ($script:frameworkRefs) {
        return $script:frameworkRefs
    }

    $script:frameworkRefs = Get-Content "$PSScriptRoot/framework.json" | ConvertFrom-Json -AsHashtable
    return $script:frameworkRefs
}

function Resolve-Reference([string]$folder, [string]$reference, $refs) {
    if ($refs.ContainsKey($reference)) {
        Write-Host "  Already found"
        return
    }

    $isMethod = $false
    $original = $reference
    $originalNoParens = $reference
    $index = $reference.IndexOf("(")
    if ($index -ge 0) {
        $isMethod = $true
        $reference = $reference.Substring(0, $index)
        $originalNoParens = $reference
    }

    $reference = Update-Generics $reference $isMethod
    $reference = $reference.Replace(".", "_")
    Write-Verbose $reference
    $files = Get-ChildItem $folder | Where-Object { $_.Name -match "_$reference[_.]"} | ForEach-Object { $_.BaseName }
    if ($isMethod) {
        $matching = $files | Where-Object { $_.StartsWith("M_") -or $_.StartsWith("Overload_") }
    } else {
        $matching = $files | Where-Object { $_.StartsWith("T_") }
        if (-not $matching) {
            $matching = $files
        }
    }

    if (-not $matching) {
        $framework = Get-FrameworkRefs
        $key = $null
        if ($framework.ContainsKey($originalNoParens)) {
            $key = $originalNoParens
            $matching = $refs[$originalNoParens]

        } else {
            $pairs = $framework.GetEnumerator() | Where-Object {
                $_.Key.EndsWith("." + $originalNoParens)
            } | Select-Object

            if ($pairs) {
                $key = $pairs.Key
                $matching = $pairs.Value
            }
        }

        if ($key -and -not $matching) {
            $matching = $key.ToLowerInvariant()
        }

        $matching = $matching | ForEach-Object {
            "#" + $matching
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

function Resolve-CppReference([xml]$tags, [string]$reference, [string]$namespace, $refs) {
    if ($refs.ContainsKey($reference)) {
        Write-Host "  Already found"
        return
    }

    $name = $reference
    $components = $name.Split("::")
    $leafName = $components[-1]
    if ($leafName.EndsWith("()")) {
        $isFunction = $true
        $leafName = $leafName.Substring(0, $leafName.Length - 2)
    }

    $first = 0
    if ($components[0] -eq $namespace) {
        $first = 1
    }

    $startNode = $null
    $finalNode = $null
    if ($components.Length - $first -gt 1 -or -not $isFunction) {
        $name = $components[$first]
        $node = $tags.SelectSingleNode("//compound[@kind='file']/member[@kind='typedef' and name='$name']")
        if ($node) {
            $name = $node.type
            $index = $name.IndexOf("<")
            if ($index -ge 0) {
                $name = $name.Substring(0, $index)
            }
        }

        $className = $name
        if (-not $name.StartsWith("$namespace::")) {
            $className = "$namespace::$name"
        }

        for ($i = $first + 1; $i -lt $components.Count - 1; $i += 1) {
            $className += "::$($components[$i])"
        }

        if (-not $isFunction) {
            if ($components.Length - $first -gt 1) {
                $name = "$className::$leafName"
            }
            else {
                $name = $className
            }

            $finalNode = $tags.SelectSingleNode("//compound[@kind='class' and name='$name']")
            if (-not $finalNode) {
                $finalNode = $tags.SelectSingleNode("//compound[@kind='namespace' and name='$name']")
            }

            if (-not $finalNode -and $components.Length -eq 1) {
                # Workaround for ends-with not being supported.
                $finalNode = $tags.SelectSingleNode("//compound[@kind='class' and substring(name, string-length(name) - string-length('::$leafName') + 1)  = '::$leafName']")
            }
        }
        
        if (-not $finalNode) {
            $startNode = $tags.SelectSingleNode("//compound[@kind='class' and name='$className']")
            if ($components.Length - $first -eq 1) {
                $finalNode = $startNode
            }
        }
    }

    if ($finalNode) {
        $nodes = @($finalNode)

    } else {
        $xpath = ""
        if (-not $startNode) {
            if ($first -gt 0) {
                $xpath = "//compound[@kind='file']/"
            } else {
                $xpath = "//"
            }

            $startNode = $tags
        }

        $xpath += "member["
        if ($isFunction) {
            $xpath += "(@kind='function' or @kind='define') and "
        }

        $xpath += "name='$leafName']"
        $nodes = $startNode.SelectNodes($xpath)
    }

    $options = @{}
    $nodes | ForEach-Object {
        if ($_.filename) {
            $options[$_.filename] = $_.name
        } else {
            $path = "$($_.anchorfile)#$($_.anchor)"
            if (-not $options.Contains($path)) {
                $name = $_.ParentNode.name + "::" + $_.name + $_.arglist
                $options.Add($path, $name)
            }
        }
    }

    if ($options.Count -eq 0) {
        $refs[$reference] = "!UNKNOWN!"
    } else {
        $refs[$reference] = $options.GetEnumerator() | ForEach-Object {
            @{
                name = $_.Value
                path = $_.Name
            }
        }
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

    if (-not $link.GetType().IsArray) {
        $link = @($link)
    }

    return Select-Link $reference $link $labels
}

function Select-Link([string]$reference, $links, $labels) {
    $old = $Host.UI.RawUI.ForegroundColor
    try {
        $Host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Choose link for ``$reference``:"
        for ($i = 0; $i -lt $links.Length; $i += 1) {
            $item = $links[$i]
            if ($item -isnot [string]) {
                $item = $item["name"]
            }

            Write-Host "$($i + 1). $item"
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
        if ($target -isnot [string]) {
            $target = $target["path"]
        }

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

function Update-Generics([string]$Name, [bool]$IsMethod) {
    $index = $Name.IndexOf('<')
    if ($index -lt 0) {
        return $Name
    }

    $after = ""
    $dotIndex = $Name.LastIndexOf("_")
    if ($index -lt $dotIndex) {
        $after = $Name.Substring($dotIndex)
        $Name = $Name.Substring(0, $dotIndex)
        $IsMethod = $false
    }

    $result = $Name.Substring(0, $index) + "_"
    if ($IsMethod) {
        $result += "_"
    }

    $level = 0
    $argCount = 1
    for ($x = 0; $x -lt $Name.Length; $x += 1) {
        switch ($Name[$x]) {
            '<' { $level += 1 }
            '>' { 
                $level -= 1 
            }
            ',' { 
                if ($level -eq 1) {
                    $argCount += 1
                }
            }
        }

        if ($end) {
            break
        }
    }

    return $result + "$argCount" + $after
}