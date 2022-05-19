[CmdletBinding()] Param (
  [Parameter(Mandatory = $True)] [string[]]$path,
  [Parameter(Mandatory = $False)] [string[]] $only,
  [Parameter(Mandatory = $False)] [string[]] $exclude,
  [Parameter(Mandatory = $False)] [switch] $showall
)

. .\"utils\utils.ps1"

$licensemessage = "encoding-checker script is under GNU General Public License v3.0.`r`nDocumentation and latest release: https://github.com/manumuve/encoding-checker`r`n`r`n"

#Defined file types to check or exclude
$definedonly = $PSBoundParameters.ContainsKey('only')
$definedexclude = $PSBoundParameters.ContainsKey('exclude')
$finalregex = ""
$includeregexfragment = ""
$excluderegexfragment = ""
if ($definedexclude) {
  $excluderegexfragment = "(?!.*\.(" + [string]::Join('|', $exclude) + ")$)"
}
if ($definedonly) {
  $includeregexfragment = "(\.(" + [string]::Join('|', $only) + ")$)"
}
else {
  $includeregexfragment = "(\.(.*)$)"
}

$finalregex = $excluderegexfragment + $includeregexfragment

$allfiles = @()
$noutf8files = @()

## First, check if the file is binary. That is, if the first
## 5 lines contain any non-printable characters.
## Empty files are also assumed as binary, just as does UNIX file command.


function Get-encodings($folder) {
    
    $folder.GetFiles() | ForEach-Object {
        
        if ($_.Fullname -match $finalregex) {
            
            [Byte[]]$bytes = Get-Content -Encoding Byte $_.Fullname
            $hex_array = ($bytes|ForEach-Object ToString X2|ForEach-Object {"0x$_"})
            
            if ( $hex_array.Count -eq 0 ) {
            
                $script:allfiles += $_.Fullname + ",`t Empty"
                $script:noutf8files += $_.Fullname + ",`t Empty"

            } elseif ( Get-file-looks-pdf($_) ) {
            
                $script:allfiles += $_.Fullname + ",`t PDF Document"
            
            } elseif (Get-file-looks-utf8-with-BOM($_)) {
            
                $script:allfiles += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
                $script:noutf8files += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
            
            } elseif ( IsUtf8 -hex_array $hex_array ) {
            
                $script:allfiles += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName
            
            } else {
                $script:allfiles += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(20127).EncodingName + " (or unknown encoding)"
                $script:noutf8files += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(20127).EncodingName + " (or unknown encoding)"
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

if ([int]$script:noutf8files.count -gt 0) {
  Write-Host "No UTF-8 files:`r`n"
  $script:noutf8files
  Write-Host ("`r`n" + $script:noutf8files.count + " file/s with wrong encoding found. Please, check list above.`r`n`r`n") -foregroundcolor Red
  Write-Host $licensemessage
  exit 1
}
else {
  Write-Host "Found no files with wrong encoding.`r`n`r`n" -foregroundcolor Green
  Write-Host $licensemessage
}