# Genere les PNG du kneeboard a partir de kneeboard.html, dans ..\kneeboard\
# Pages en 1536x2048 (mise en page 768x1024, rendu x2 pour la nettete).
# Les fichiers generes commencent par "BS_" : tes propres images dans ..\kneeboard\ ne sont jamais touchees.
# Usage : double-clic sur generer_kneeboard.bat

$ErrorActionPreference = "Stop"
$html = Join-Path $PSScriptRoot "kneeboard.html"
$out = Join-Path (Split-Path $PSScriptRoot -Parent) "kneeboard"

$browser = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw "Edge ou Chrome introuvable." }

$pages = @(
    @{ n = 1; name = "BS_01_comms-nav.png" },
    @{ n = 2; name = "BS_02_menu-bareme.png" },
    @{ n = 3; name = "BS_03_briefing.png" }
)

# Supprime les anciennes pages generees
Get-ChildItem -Path $out -Filter "BS_*.png" -ErrorAction SilentlyContinue | Remove-Item

$url = "file:///" + ($html -replace "\\", "/")
foreach ($p in $pages) {
    $file = Join-Path $out $p.name
    $args = @("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
              "--window-size=768,1024", "--screenshot=`"$file`"", "`"$url#$($p.n)`"")
    Start-Process -FilePath $browser -ArgumentList $args -Wait -WindowStyle Hidden
    Write-Host "  + $($p.name)"
}
Write-Host "OK : pages generees dans $out"
