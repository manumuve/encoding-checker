[CmdletBinding()] Param (
    [Parameter(Mandatory = $True)] [string[]]$path,
    [Parameter(Mandatory = $False)] [string[]] $only,
    [Parameter(Mandatory = $False)] [string[]] $exclude,
    [Parameter(Mandatory = $False)] [switch] $showall,
    [Parameter(Mandatory = $False)] [int] $timeout,
    [Parameter(Mandatory = $False)] [switch] $ignorewarning
)

$version = 0.5
$licensemessage = "encoding-checker v$version - This script is under GNU General Public License v3.0.`r`nDocumentation and latest release: https://github.com/manumuve/encoding-checker`r`n`r`n"


#Defined parameters
$definedonly = $PSBoundParameters.ContainsKey('only')
$definedexclude = $PSBoundParameters.ContainsKey('exclude')
$definedtimeout = $PSBoundParameters.ContainsKey('timeout')
$definedignorewarning = $PSBoundParameters.ContainsKey('ignorewarning')
$finalregex = ""
$includeregexfragment = ""
$excluderegexfragment = ""
$deepmethodtimeout = 30
$setwarningaction = "Stop"
if ($definedexclude) {
    $excluderegexfragment = "(?!.*\.(" + [string]::Join('|', $exclude) + ")$)"
}
if ($definedonly) {
    $includeregexfragment = "(\.(" + [string]::Join('|', $only) + ")$)"
}
else {
    $includeregexfragment = "(\.(.*)$)"
}
if ($definedtimeout) {
    $deepmethodtimeout = $timeout
}
if ($definedignorewarning) {
    $setwarningaction = "Continue"
}

$finalregex = $excluderegexfragment + $includeregexfragment

$allfiles = @()
$noutf8files = @()
$undeterminedfiles = @()

## Checks if the file is binary. That is, if the first
## 5 lines contain any non-printable characters.
## Empty files are also assumed as binary, just as does UNIX file command.
function Get-file-looks-binary($file) {
    $nonPrintable = [char[]] (0..8 + 10..31 + 127 + 129 + 141 + 143 + 144 + 157)
    $lines = Get-Content $file.Fullname -ErrorAction Ignore -TotalCount 5
    $result = @($lines | Where-Object { $_.IndexOfAny($nonPrintable) -ge 0 })

    ##[Byte[]]$head = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 $file.Fullname
    ##Write-Host "HEAD:" $head "`r`n"

    return ($result.Count -gt 0 -Or (Get-Item $file.Fullname).length -eq 0)
}

## Search for '%PDF' in file header.
function Get-file-looks-pdf($file) {
    [Byte[]]$head = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 $file.Fullname
    return ($head.length -gt 3 -And $head[0] -eq 0x25 -and $head[1] -eq 0x50 -and $head[2] -eq 0x44 -and $head[3] -eq 0x46)
}

## Check if the file is UTF-8 encoded. That is, if once read as UTF-8,
## the text contains the unicode replacement character.
function Get-file-looks-utf8($file) {
    $f = Get-Content -Encoding utf8 -raw $file.Fullname
    return ($f.length -gt 0 -And !$f.contains([char]0xfffd))
}

## Check if an UTF-8 encoded file has the BOM signature present.
function Get-file-looks-utf8-with-BOM($file) {
    [Byte[]]$bom = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 $file.Fullname
    return ($bom.length -gt 3 -And $bom[0] -eq 0xef -and $bom[1] -eq 0xbb -and $bom[2] -eq 0xbf)
}

<#
    Powershell port of isutf8 from moreutils: https://joeyh.name/code/moreutils
    Author: Rubén Cherif: https://github.com/rabiixx
    This should be used only if previous detection methods were unable to determine the file encoding.
    WARN: Takes so much time on large files since it checks the full file content.
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
function Get-file-looks-utf8-content-deep-method($file) {
    $TimeOut = New-TimeSpan -Seconds $script:deepmethodtimeout
    $Sw = [Diagnostics.Stopwatch]::StartNew()

    [Byte[]]$bytes = Get-Content -Encoding Byte $file.Fullname

    if ($Sw.Elapsed -gt $TimeOut) {
        throw "Timeout, file too large: " + $file.Fullname
    }
  
    $hex_array = "0x" + [System.BitConverter]::ToString($bytes) | ForEach-Object {$_.replace("-",",0x")} | ForEach-Object Split(",")
  
    if ($Sw.Elapsed -gt $TimeOut) {
        throw "Timeout, file too large: " + $file.Fullname
    }

    $i = 0

    $hex_array_size = $hex_array.Count
    while ($i -lt $hex_array_size) {
        if ($Sw.Elapsed -gt $TimeOut) {
            throw "Timeout, file too large: " + $file.Fullname
        }

        if ($hex_array[$i] -le "0x7F") { # 00..7F */
            $i += 1
        }
        elseif ($hex_array[$i] -ge "0xC2" -and $hex_array[$i] -le "0xDF") { # C2..DF 80..BF */
            if ($i + 1 -lt $hex_array_size) { # Expect a 2nd byte */
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 2
        }
        elseif ($hex_array[$i] -eq "0xE0") { # E0 A0..BF 80..BF */
            if ($i + 2 -lt $hex_array_size) { # Expect a 2nd and 3rd byte */
                if ($hex_array[$i + 1] -lt "0xA0" -or $hex_array[$i + 1] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -ge "0xE1" -and $hex_array[$i] -le "0xEC") { # E1..EC 80..BF 80..BF */
            if ($i + 2 -lt $hex_array_size) { # Expect a 2nd and 3rd byte */
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -eq "0xED") { # ED 80..9F 80..BF */
            if ($i + 2 -lt $hex_array_size) { # Expect a 2nd and 3rd byte */
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0x9F") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -ge "0xEE" -and $hex_array[$i] -le "0xEF") { # EE..EF 80..BF 80..BF */
            if ($i + 2 -lt $hex_array_size) { # Expect a 2nd and 3rd byte */
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 3
        }
        elseif ($hex_array[$i] -eq "0xF0") { # F0 90..BF 80..BF 80..BF */
            if ($i + 3 -lt $hex_array_size) { # Expect a 2nd, 3rd 3th byte */
                if ($hex_array[$i + 1] -lt "0x90" -or $hex_array[$i + 1] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 3] -lt "0x80" -or $hex_array[$i + 3] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 4
        }
        elseif ($hex_array[$i] -ge "0xF1" -and $hex_array[$i] -le "0xF3") { # F1..F3 80..BF 80..BF 80..BF */

            if ($i + 3 -lt $hex_array_size) { # Expect a 2nd, 3rd 3th byte */
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 3] -lt "0x80" -or $hex_array[$i + 3] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 4
        }
        elseif ($hex_array[$i] -eq "0xF4") { # F4 80..8F 80..BF 80..BF */
            if ($i + 3 -lt $hex_array_size) { # Expect a 2nd, 3rd 3th byte */
                if ($hex_array[$i + 1] -lt "0x80" -or $hex_array[$i + 1] -gt "0x8F") {
                    return $false
                }
                if ($hex_array[$i + 2] -lt "0x80" -or $hex_array[$i + 2] -gt "0xBF") {
                    return $false
                }
                if ($hex_array[$i + 3] -lt "0x80" -or $hex_array[$i + 3] -gt "0xBF") {
                    return $false
                }
            }
            else {
                return $false
            }
            $i += 4
        }
        else {
            return $false
        }
    }

    return $true
}

## Simply gets a timestamp to use when logging results.
function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]`t" -f (Get-Date)
}

function Get-encodings($folder) {
    $folder.GetFiles() | ForEach-Object {
        if ($_.Fullname -match $finalregex) {
            if (Get-file-looks-binary($_)) {
                $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t ASCII-8BIT (binary file)"
            }
            elseif (Get-file-looks-pdf($_)) {
                $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t PDF Document"
            }
            elseif (Get-file-looks-utf8($_)) {
                if (Get-file-looks-utf8-with-BOM($_)) {
                    $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
                    $script:noutf8files += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
                }
                else {
                    $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName
                } 
            }
            else {
                $deepSuccess = $false
                $exceptionwasthrown = $false
                Try {
                    $deepSuccess = Get-file-looks-utf8-content-deep-method($_)
                }
                Catch [system.exception] {
                    $exceptionWasThrown = $true
                }
                Finally {
                    if ($exceptionWasThrown -eq $true) {
                        $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t(undetermined encoding)"
                        $script:undeterminedfiles += $(Get-TimeStamp) + $_.Fullname + ",`t(undetermined encoding)"
                    }
                    elseif ($deepSuccess -eq $true) {
                        $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName
                    }
                    else {
                        $script:allfiles += $(Get-TimeStamp) + $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(20127).EncodingName + " (or another encoding)"
                        $script:noutf8files += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(20127).EncodingName + " (or another encoding)"
                    }
                }
            }
        }
    }
    $folder.GetDirectories() | ForEach-Object { Get-encodings $_ }
}

$path | ForEach-Object {
    $folder = Get-Item $_
    Write-Host "Checking file encodings in:" $folder "`r`n"
    Get-encodings($folder)
}

if ($showall) {
    Write-Host "All files:`r`n"
    $script:allfiles
    Write-Host "`r`n`r`n"
}

if ([int]$script:noutf8files.count -gt 0 -or [int]$script:undeterminedfiles.count -gt 0) {
    if ([int]$script:noutf8files.count -gt 0) {
        Write-Host "No UTF-8 files:`r`n"
        $script:noutf8files
        Write-Host ("`r`n" + $script:noutf8files.count + " file/s with wrong encoding found. Please, check list above.`r`n`r`n") -foregroundcolor Red
    }

    if ([int]$script:undeterminedfiles.count -gt 0) {
        Write-Host ("File/s with undetermined encoding:`r`n") -foregroundcolor Yellow
        $script:undeterminedfiles
        Write-Warning ("`r`n" + $script:undeterminedfiles.count + " file/s whith undetermined encoding that must be checked manually.`r`n`r`n") -WarningAction $script:SetWarningAction
    }
    Write-Host $licensemessage
    exit 1
}
else {
    Write-Host "Found no files with wrong encoding.`r`n`r`n" -foregroundcolor Green
    Write-Host $licensemessage
}
