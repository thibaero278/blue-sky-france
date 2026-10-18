# BLUE SKY - Publie une mise a jour du script de mission dans le changelog du site
# Lancer via publier_maj.bat apres avoir modifie script Caucase.lua

# URL et token : dans secrets.local.ps1 (non versionne), qui definit $url et $token
$url   = 'COLLE_ICI_L_URL_DU_DEPLOIEMENT_APPS_SCRIPT'
$token = 'COLLE_ICI_LE_TOKEN'
$secrets = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path $secrets) { . $secrets }
$file  = Join-Path $PSScriptRoot '..\mission\script Caucase.lua'
$state = Join-Path $PSScriptRoot '.dernier_hash'

$hash = (Get-FileHash $file -Algorithm SHA256).Hash.Substring(0, 12)
if ((Test-Path $state) -and (Get-Content $state) -eq $hash) {
    Write-Host "Aucun changement depuis la derniere publication ($hash)."
    if ((Read-Host 'Publier quand meme ? (o/N)') -ne 'o') { exit }
}

$version = Read-Host 'Version (ex. 2.1)'
$notes   = Read-Host 'Notes de mise a jour'

$body = @{ token = $token; type = 'changelog'; file = 'script Caucase.lua'
           version = $version; hash = $hash; notes = $notes } | ConvertTo-Json
$bytes = [Text.Encoding]::UTF8.GetBytes($body)
$res = Invoke-RestMethod -Uri $url -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8'

if ("$res" -eq 'ok') {
    Set-Content $state $hash
    Write-Host "Publie : $version ($hash)" -ForegroundColor Green
} else {
    Write-Host "Echec : $res" -ForegroundColor Red
}
