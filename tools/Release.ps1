# Release.ps1 - lint + test, bygg zip, kopiera till AddOns, commit/tag/push och GitHub-release.
# Kör från valfri katalog: powershell -File tools\Release.ps1 [-Message "vad som ändrats"] [-SkipGit]
param(
    [string]$Message = "",
    [switch]$SkipGit
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$toc = Get-Content "$root\UlatekEggs.toc" -Raw
if ($toc -notmatch '## Version: ([\d.]+)') { throw "Hittar ingen version i UlatekEggs.toc" }
$version = $Matches[1]
Write-Host "UlatekEggs v$version" -ForegroundColor Cyan

# 1. Lint + tester
$luacheck = "$env:USERPROFILE\tools\luacheck.exe"
if (Test-Path $luacheck) {
    & $luacheck --config "$root\.luacheckrc" "$root\UlatekEggs.lua"
    if ($LASTEXITCODE -ne 0) { throw "luacheck fann problem" }
}
python "$root\test\run_lua.py"
if ($LASTEXITCODE -ne 0) { throw "testriggen misslyckades" }

# 2. Zip med addon-mappen i roten (WowUp-kravet) + release.json
$dist = "$root\dist"
New-Item -ItemType Directory -Force $dist | Out-Null
Get-ChildItem $dist | Remove-Item -Force
$stage = "$dist\stage\UlatekEggs"
New-Item -ItemType Directory -Force "$stage\Media" | Out-Null
Copy-Item "$root\UlatekEggs.lua", "$root\UlatekEggs.toc" $stage
Copy-Item "$root\Media\*" "$stage\Media"
$zip = "$dist\UlatekEggs-v$version.zip"
Compress-Archive -Path "$dist\stage\UlatekEggs" -DestinationPath $zip
Remove-Item -Recurse -Force "$dist\stage"
(Get-Content "$root\release.json.template" -Raw).Replace('__VERSION__', $version) | Set-Content "$dist\release.json" -Encoding ascii
Write-Host "byggde $zip"

# 3. Lokal installation
$addons = 'C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\UlatekEggs'
New-Item -ItemType Directory -Force "$addons\Media" | Out-Null
Copy-Item "$root\UlatekEggs.lua", "$root\UlatekEggs.toc" $addons -Force
Copy-Item "$root\Media\*" "$addons\Media" -Force
Write-Host "installerad i AddOns"

if ($SkipGit) { return }

# 4. Git: commit, tag, push
git add -A
$pending = git status --porcelain
if ($pending) {
    $msg = if ($Message) { "v$version - $Message" } else { "v$version" }
    git commit -q -m $msg
}
if (-not (git tag -l "v$version")) { git tag "v$version" }
git push -q origin HEAD --follow-tags

# 5. GitHub-release med zip + release.json
$notes = if ($Message) { $Message } else { "UlatekEggs v$version" }
gh release create "v$version" $zip "$dist\release.json" --title "v$version" --notes $notes
Write-Host "release v$version publicerad" -ForegroundColor Green
