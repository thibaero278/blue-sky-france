# Remplace le script de mission dans la .miz DAY (entrée interne "l10n/DEFAULT/script Caucase.lua"), DCS fermé.
# Sauvegarde horodatée dans bakup\ à côté de la .miz, relecture de l'archive, copie du .lua à côté de la .miz.
# Usage : powershell -ExecutionPolicy Bypass -File injecter_script.ps1 [mission.miz] [script.lua]
param(
    [string]$Miz = "$env:USERPROFILE\Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\Blue Sky Multi-joueur DAY_Caucasus.miz",
    [string]$Script = (Join-Path $PSScriptRoot "script Caucase.lua"),
    [string]$Entree = "l10n/DEFAULT/script Caucase.lua"   # nom que le trigger DO SCRIPT FILE de la mission attend (vérifié le 15/11)
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (Get-Process DCS* -ErrorAction SilentlyContinue) { throw "DCS est ouvert : ferme-le (et l'éditeur) avant d'injecter." }
$Miz = (Resolve-Path $Miz).Path
$Script = (Resolve-Path $Script).Path

# Tests hors jeu d'abord (anciens tests + scénarios sur le script entier) : un seul échec = pas d'injection
& python (Join-Path $PSScriptRoot "..\tools\run_tests.py")
if ($LASTEXITCODE -ne 0) { throw "Tests hors jeu en échec (python site\tools\run_tests.py) : injection refusée, .miz pas touchée." }
if ($Script -ne (Resolve-Path (Join-Path $PSScriptRoot "script Caucase.lua")).Path) {
    Write-Warning "Les tests couvrent site\mission\script Caucase.lua, pas $Script."
}

$bakDir = Join-Path (Split-Path $Miz -Parent) "bakup"
New-Item -ItemType Directory -Force $bakDir | Out-Null
$bak = Join-Path $bakDir ("{0}_{1}.miz.bak" -f [IO.Path]::GetFileNameWithoutExtension($Miz), (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"))
Copy-Item $Miz $bak
Write-Host "Sauvegarde : $bak"

$zip = [IO.Compression.ZipFile]::Open($Miz, [IO.Compression.ZipArchiveMode]::Update)
try {
    $e = $zip.GetEntry($Entree)
    if (-not $e) { throw "Entrée '$Entree' absente de la .miz : le nom interne a changé ? Rien modifié (sauvegarde faite)." }
    $e.Delete()
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $Script, $Entree) | Out-Null
} finally { $zip.Dispose() }

# Vérification : archive relue, script identique à la source
$zip = [IO.Compression.ZipFile]::OpenRead($Miz)
try {
    $r = New-Object IO.StreamReader($zip.GetEntry($Entree).Open())
    try { $dedans = $r.ReadToEnd() } finally { $r.Close() }
    if ($dedans -ne [IO.File]::ReadAllText($Script)) { throw "Le script relu dans la .miz ne correspond pas à la source : restaure $bak" }
    Write-Host "Archive OK : $($zip.Entries.Count) entrées, '$Entree' identique à la source"
} finally { $zip.Dispose() }

Copy-Item $Script (Join-Path (Split-Path $Miz -Parent) (Split-Path $Script -Leaf)) -Force
Write-Host "OK : $(Split-Path $Miz -Leaf) (script recopié à côté). Pas testé en jeu : checklist à faire."
