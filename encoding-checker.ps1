[CmdletBinding()] Param (
  [Parameter(Mandatory = $True)] [string[]]$path,
  [Parameter(Mandatory = $False)] [string[]] $filetypes,
  [Parameter(Mandatory = $False)] [switch] $showall
)

#Defined file types to check
$definedfiletypes = $PSBoundParameters.ContainsKey('filetypes')
$filetypesregex = ""
if ($definedfiletypes) {
  $filetypesregex = "(\." + [string]::Join(')$|(\.', $filetypes) + ")$"
}

$allfiles = @()
$noutf8files = @()

## First, check if the file is binary. That is, if the first
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

function Get-encodings($folder) {
  $folder.GetFiles() | ForEach-Object {
    if (!$definedfiletypes -or $_.Fullname -match $filetypesregex) {
      if (Get-file-looks-binary($_)) {
        $script:allfiles += $_.Fullname + ",`t ASCII-8BIT (binary file)"
      }
      elseif (Get-file-looks-pdf($_)) {
        $script:allfiles += $_.Fullname + ",`t PDF Document"
      }
      elseif (Get-file-looks-utf8($_)) {
        if (Get-file-looks-utf8-with-BOM($_)) {
          $script:allfiles += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
          $script:noutf8files += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
        }
        else {
          $script:allfiles += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName
        } 
      }
      else {
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
  Write-Error -Message ("`r`n" + $script:noutf8files.count + " file/s with wrong encoding found. Please, check list above.`r`n`r`n") -ErrorAction Stop
}
else {
  Write-Host "Found no files with wrong encoding.`r`n`r`n"
}

Write-Host "encoding-checker script is under GNU General Public License v3.0.`r`nDocumentation and latest release: https://github.com/manumuve/encoding-checker`r`n`r`n"
