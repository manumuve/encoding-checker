[CmdletBinding()] Param (
	[Parameter(Mandatory=$True)]$path,
	[Parameter(Mandatory=$True)] [string[]] $filetypes
)

Write-Host "Checking files encoding in:" $path

$folder = Get-Item $path
$filetypesregex = "(\." + [string]::Join(')$|(\.', $filetypes) + ")$"

$noutf8list = @()

function looks-utf8($file) {
	$f = Get-Content -Encoding utf8 -raw $file.Fullname
	return ($f.length -gt 0 -And !$f.contains([char]0xfffd))
}

function looks-utf8-with-BOM($file) {
	[Byte[]]$bom = Get-Content -Encoding Byte -ReadCount 4 -TotalCount 4 $file.Fullname
	return ($bom[0] -eq 0xef -and $bom[1] -eq 0xbb -and $bom[2] -eq 0xbf)
}

function get-noutf8($folder) {
	$folder.GetFiles() | foreach {
		if (($_.Fullname -match $filetypesregex)) {
			if (looks-utf8($_)) {
				if (looks-utf8-with-BOM($_)) {
					#$_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
					$script:noutf8list += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName + " with BOM"
				}
				else {
					#$_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(65001).EncodingName
				} 
			}
			else {
				#$_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(20127).EncodingName + " (or unknown encoding)"
				$script:noutf8list += $_.Fullname + ",`t " + [Text.Encoding]::GetEncoding(20127).EncodingName + " (or unknown encoding)"
			}
		}
	}
	$folder.GetDirectories() | Foreach { get-noutf8 $_ }
}

get-noutf8 $folder


if ([int]$script:noutf8list.count -gt 0) {
	$script:noutf8list
	Write-Error -Message ("" + $script:noutf8list.count + " file/s with wrong encoding found. Please, check list above.`r`n`r`n") -ErrorAction Stop
}
else {
	Write-Host "Found no files with wrong encoding.`r`n`r`n"
}