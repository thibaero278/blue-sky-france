# Genere les PNG du kneeboard a partir de kneeboard.html, dans ..\kneeboard\
# Pages en 1536x2048 (mise en page 768x1024, rendu x2 pour la nettete).
# Les fichiers generes commencent par un numero a 3 chiffres ("001_", "002_"...) : DCS trie les pages par nom,
# donc l'ordre du kneeboard = l'ordre de cette liste. Les anciens "BS_*.png" (avant le 11/11) sont aussi supprimes.
# Tes propres images dans ..\kneeboard\ ne sont jamais touchees, sauf si leur nom commence par 3 chiffres + "_".
# Usage : double-clic sur generer_kneeboard.bat
# Ensuite : ..\kneeboard\ajouter_kneeboard.bat pour les injecter dans la .miz (DCS / editeur fermes).

$ErrorActionPreference = "Stop"
$html = Join-Path $PSScriptRoot "kneeboard.html"
$out = Join-Path (Split-Path $PSScriptRoot -Parent) "kneeboard"

$browser = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw "Edge ou Chrome introuvable." }

# Une ligne par page, dans l'ordre (n = numero de la page dans kneeboard.html)
$pages = @(
    @{ n = 1; name = "comms-nav" },
    @{ n = 2; name = "menu-bareme" },
    @{ n = 3; name = "briefing" },
    @{ n = 4; name = "missions-code" },
    # Memo radio (phraseologie ATC humain, guide v1.8, calls en anglais) : une page par page du PDF
    @{ n = 5; name = "radio-decollage-piste" },
    @{ n = 6; name = "radio-catapultage-case1" },
    @{ n = 7; name = "radio-catapultage-case2" },
    @{ n = 8; name = "radio-catapultage-case3" },
    @{ n = 9; name = "radio-atterrissage-piste" },
    @{ n = 10; name = "radio-appontage-case1" },
    @{ n = 11; name = "radio-appontage-case2" },
    @{ n = 12; name = "radio-appontage-case3" },
    @{ n = 13; name = "radio-awacs" },
    @{ n = 14; name = "radio-jtac-contact" },
    @{ n = 15; name = "radio-jtac-9line" },
    @{ n = 16; name = "radio-jtac-attaque" },
    @{ n = 17; name = "radio-jtac-apres-passe" },
    @{ n = 18; name = "lexique-radio-nav" },
    @{ n = 19; name = "lexique-awacs" },
    @{ n = 20; name = "lexique-air-air" },
    @{ n = 21; name = "lexique-pa-depart" },
    @{ n = 22; name = "lexique-appontage" },
    @{ n = 23; name = "lexique-jtac" },
    @{ n = 24; name = "lexique-tir-jtac" },
    @{ n = 25; name = "alphabet-acronymes" }
)

# Supprime les anciennes pages generees (nouveau format "001_*.png" et ancien "BS_*.png")
Get-ChildItem -Path $out -Filter "*.png" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(\d{3}_|BS_)' } | Remove-Item

$url = "file:///" + ($html -replace "\\", "/")
foreach ($p in $pages) {
    $name = "{0:D3}_{1}.png" -f $p.n, $p.name
    $file = Join-Path $out $name
    $args = @("--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=2",
              "--window-size=768,1024", "--screenshot=`"$file`"", "`"$url#$($p.n)`"")
    Start-Process -FilePath $browser -ArgumentList $args -Wait -WindowStyle Hidden
    if (-not (Test-Path $file)) { throw "Page $name non generee." }
    Write-Host "  + $name"
}
Write-Host "OK : $($pages.Count) pages generees dans $out"
