$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$version = ([xml](Get-Content (Join-Path $workspace 'mouse_pickup\metadata.xml') -Raw)).metadata.version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version.' }
$stage = Join-Path $workspace ("dist\ICanTouchForever-$version\mouse_pickup")
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'mpickup') | Out-Null
foreach ($file in @('main.lua','metadata.xml')) {
    Copy-Item -LiteralPath (Join-Path $workspace ('mouse_pickup\' + $file)) -Destination (Join-Path $stage $file) -Force
}
Get-ChildItem -LiteralPath (Join-Path $workspace 'mouse_pickup\mpickup') -Filter '*.lua' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stage ('mpickup\' + $_.Name)) -Force
}
Copy-Item -LiteralPath (Join-Path $workspace 'mouse_pickup\resources') -Destination $stage -Recurse -Force
Copy-Item -LiteralPath (Join-Path $workspace 'workshop\README-release.md') -Destination (Join-Path $stage 'README.md') -Force
Copy-Item -LiteralPath (Join-Path $workspace 'LICENSE') -Destination (Join-Path $stage 'LICENSE') -Force
if ((Get-Content -LiteralPath (Join-Path $stage 'mpickup\development.lua') -Raw).Trim() -ne 'return false') {
    throw 'Refusing to package an enabled development harness.'
}
$archive = Join-Path $workspace ("dist\ICanTouchForever-$version.zip")
Compress-Archive -Path $stage -DestinationPath $archive -Force
Write-Output $archive
Get-FileHash -LiteralPath $archive -Algorithm SHA256 | Select-Object Hash
