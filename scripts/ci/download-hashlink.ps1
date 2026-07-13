[CmdletBinding()]
param([string]$OutputDirectory = "out/deps/hashlink")

$ErrorActionPreference = "Stop"
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/HaxeFoundation/hashlink/releases/latest"
$asset = $release.assets | Where-Object name -Like "hashlink-*-win.zip" | Select-Object -First 1
if (-not $asset) {
	throw "Could not find a Windows HashLink release asset."
}

$archive = "$OutputDirectory.zip"
Remove-Item -Recurse -Force $OutputDirectory -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Split-Path $OutputDirectory) | Out-Null
curl.exe --fail --location $asset.browser_download_url --output $archive
if ($LASTEXITCODE) { throw "HashLink download failed." }
Expand-Archive $archive -DestinationPath $OutputDirectory -Force
$root = Get-ChildItem $OutputDirectory -Directory | Where-Object {
	Test-Path (Join-Path $_.FullName "include/hl.h")
} | Select-Object -First 1
if (-not $root) {
	throw "Could not locate the extracted HashLink SDK."
}

if ($env:GITHUB_ENV) { "HASHLINK=$($root.FullName)" | Out-File $env:GITHUB_ENV -Encoding utf8 -Append }
if ($env:GITHUB_PATH) { $root.FullName | Out-File $env:GITHUB_PATH -Encoding utf8 -Append }
$env:HASHLINK = $root.FullName
Write-Output $root.FullName
