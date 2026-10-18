# Ajoute les pages de kneeboard dans une mission DCS (.miz)
#
# Organisation du dossier "kneeboard" (celui de ce script) :
#   kneeboard\*.png / *.jpg                  -> pages pour TOUS les avions
#   kneeboard\FA-18C_hornet\*.png            -> pages pour le Hornet uniquement
#   (un sous-dossier par type d'avion DCS)
#
# Usage : glisser la .miz sur "ajouter_kneeboard.bat"
#         ou : powershell -ExecutionPolicy Bypass -File ajouter_kneeboard.ps1 "mission.miz"
# Sans argument : prend la .miz du dossier parent.

param([string]$Miz)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$src = $PSScriptRoot
$exts = @(".png", ".jpg", ".jpeg")

if (-not $Miz) {
    $found = @(Get-ChildItem -Path (Split-Path $src -Parent) -Filter *.miz)
    if ($found.Count -ne 1) { throw "Indique la .miz a modifier (trouve : $($found.Count) .miz dans le dossier parent)." }
    $Miz = $found[0].FullName
}
$Miz = (Resolve-Path $Miz).Path

# Liste des images : chemin dans la .miz -> fichier local
$pages = [ordered]@{}
foreach ($f in Get-ChildItem -Path $src -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name) {
    $pages["KNEEBOARD/IMAGES/" + $f.Name] = $f.FullName
}
foreach ($dir in Get-ChildItem -Path $src -Directory) {
    foreach ($f in Get-ChildItem -Path $dir.FullName -File | Where-Object { $exts -contains $_.Extension.ToLower() } | Sort-Object Name) {
        $pages["KNEEBOARD/" + $dir.Name + "/IMAGES/" + $f.Name] = $f.FullName
    }
}
if ($pages.Count -eq 0) { throw "Aucune image (.png/.jpg) trouvee dans $src" }

# Sauvegarde avant modification, dans le dossier "bakup" a cote de la .miz (horodatee, jamais ecrasee)
$backupDir = Join-Path (Split-Path $Miz -Parent) "bakup"
New-Item -ItemType Directory -Force $backupDir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backup = Join-Path $backupDir ("{0}_{1}.miz.bak" -f [System.IO.Path]::GetFileNameWithoutExtension($Miz), $stamp)
Copy-Item $Miz $backup
Write-Host "Sauvegarde : $backup"

$zip = [System.IO.Compression.ZipFile]::Open($Miz, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    # On remplace l'ancien kneeboard entierement (pages supprimees = retirees de la mission)
    $old = @($zip.Entries | Where-Object { $_.FullName -like "KNEEBOARD/*" })
    foreach ($e in $old) { $e.Delete() }
    Write-Host "Anciennes pages retirees : $($old.Count)"

    foreach ($entry in $pages.Keys) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $pages[$entry], $entry) | Out-Null
        Write-Host "  + $entry"
    }
}
finally {
    $zip.Dispose()
}

Write-Host ""
Write-Host "OK : $($pages.Count) page(s) ajoutee(s) dans $(Split-Path $Miz -Leaf)"
Write-Host "Ne pas resauvegarder la mission dans l'editeur apres (ou relancer ce script)."
