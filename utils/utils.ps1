<#
    http://www.unicode.org/versions/Unicode7.0.0/UnicodeStandard-7.0.pdf (page 124, 3.9 "Unicode Encoding Forms", "UTF-8")

    https://sites.google.com/site/markusicu/unicode/utf-8-bytes

    Table 3-7. Well-Formed UTF-8 Byte Sequences
    -----------------------------------------------------------------------------
    |  Code Points        | First Byte | Second Byte | Third Byte | Fourth Byte |
    |  U+0000..U+007F     |     00..7F |             |            |             |
    |  U+0080..U+07FF     |     C2..DF |      80..BF |            |             |
    |  U+0800..U+0FFF     |         E0 |      A0..BF |     80..BF |             |
    |  U+1000..U+CFFF     |     E1..EC |      80..BF |     80..BF |             |
    |  U+D000..U+D7FF     |         ED |      80..9F |     80..BF |             |
    |  U+E000..U+FFFF     |     EE..EF |      80..BF |     80..BF |             |
    |  U+10000..U+3FFFF   |         F0 |      90..BF |     80..BF |      80..BF |
    |  U+40000..U+FFFFF   |     F1..F3 |      80..BF |     80..BF |      80..BF |
    |  U+100000..U+10FFFF |         F4 |      80..8F |     80..BF |      80..BF |
    -----------------------------------------------------------------------------
#>

Function IsUtf8 {

    [CmdletBinding()] 
    Param (
        [Parameter(Mandatory = $False)] [string[]]$hex_array
    )

    $i = 0

    $hex_array_size = $hex_array.Count

    while ($i -lt $hex_array_size)
    {

        if ($hex_array[$i] -le "0x7F") # 00..7F */
        {
            $i += 1
        }
        elseif ($hex_array[$i] -ge "0xC2" -and $hex_array[$i] -le "0xDF") # C2..DF 80..BF */
        {
            if ($i + 1 -lt $hex_array_size) # Expect a 2nd byte */
            {
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 2
        }
        elseif ($hex_array[$i] -eq "0xE0") # E0 A0..BF 80..BF */
        {
            if ($i + 2 -lt $hex_array_size) # Expect a 2nd and 3rd byte */
            {
                if ($hex_array[$i + 1] -lt "0xA0" -or $hex_array[$i + 1] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -ge "0xE1" -and $hex_array[$i] -le "0xEC") # E1..EC 80..BF 80..BF */
        {
            if ($i + 2 -lt $hex_array_size) # Expect a 2nd and 3rd byte */
            {
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -eq "0xED") # ED 80..9F 80..BF */
        {
            if ($i + 2 -lt $hex_array_size) # Expect a 2nd and 3rd byte */
            {
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0x9F")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -ge "0xEE" -and $hex_array[$i] -le "0xEF") # EE..EF 80..BF 80..BF */
        {
            if ($i + 2 -lt $hex_array_size) # Expect a 2nd and 3rd byte */
            {
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -eq "0xF0") # F0 90..BF 80..BF 80..BF */
        {
            if ($i + 3 -lt $hex_array_size) # Expect a 2nd, 3rd 3th byte */
            {
                if ($hex_array[$i + 1] -lt "0x90" -or $hex_array[$i + 1] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 3] -lt "0x80" -or $hex_array[$i + 3] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 4
        }
        elseif ($hex_array[$i] -ge "0xF1" -and $hex_array[$i] -le "0xF3") # F1..F3 80..BF 80..BF 80..BF */
        {

            if ($i + 3 -lt $hex_array_size) # Expect a 2nd, 3rd 3th byte */
            {
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 3] -lt "0x80" -or $hex_array[$i + 3] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 4
        }
        elseif ($hex_array[$i] -eq "0xF4") # F4 80..8F 80..BF 80..BF */
        {
            if ($i + 3 -lt $hex_array_size) # Expect a 2nd, 3rd 3th byte */
            {
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0x8F")
                {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF")
                {
                    return $false
                }
                if ($hex_array[$i + 3] -lt "0x80" -or $hex_array[$i + 3] -gt "0xBF")
                {
                    return $false
                }
            }
            else
            {
                return $false
            }
            $i += 4
        }
        else
        {
            return $false
        }
    }

    return $true
}

function Get-file-looks-utf8-with-BOM($file) {
    [Byte[]]$bom = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 $file.Fullname
    return ($bom.length -gt 3 -And $bom[0] -eq 0xef -and $bom[1] -eq 0xbb -and $bom[2] -eq 0xbf)
}

function Get-file-looks-binary($file) {
    $nonPrintable = [char[]] (0..8 + 10..31 + 127 + 129 + 141 + 143 + 144 + 157)
    $lines = Get-Content $file.Fullname -ErrorAction Ignore -TotalCount 5
    $result = @($lines | Where-Object { $_.IndexOfAny($nonPrintable) -ge 0 })
    
    return ($result.Count -gt 0 -Or (Get-Item $file.Fullname).length -eq 0)
}

function Get-file-looks-pdf($file) {
  [Byte[]]$head = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 $file.Fullname
  return ($head.length -gt 3 -And $head[0] -eq 0x25 -and $head[1] -eq 0x50 -and $head[2] -eq 0x44 -and $head[3] -eq 0x46)
}

