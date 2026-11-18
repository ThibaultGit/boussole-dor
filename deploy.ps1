# Prepare et deploie le calculateur d'or sur Netlify.
#   .\deploy.ps1            -> copie + zip + deploiement production
#   .\deploy.ps1 -LocalOnly -> copie + zip seulement (pas de deploiement)
param([switch]$LocalOnly)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root "calculateur-or-papa.html"
$site = Join-Path $root "netlify-site"
$dst  = Join-Path $site "index.html"
$zip  = Join-Path $root "calculateur-or-papa-netlify.zip"
$siteID = "a3ee91b6-6da0-4ff6-a0e3-534084224c41"

if (-not (Test-Path -LiteralPath $src)) { throw "Source introuvable : $src" }

# 1. Copie exacte vers le dossier deploye
New-Item -ItemType Directory -Force -Path $site | Out-Null
Copy-Item -LiteralPath $src -Destination $dst -Force

# 2. Archive prete a glisser dans Netlify (voie manuelle)
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path $dst -DestinationPath $zip -CompressionLevel Optimal

$h1 = (Get-FileHash -LiteralPath $src).Hash
$h2 = (Get-FileHash -LiteralPath $dst).Hash
if ($h1 -ne $h2) { throw "La copie differe de la source (encodage ?)." }

$kb = [math]::Round((Get-Item -LiteralPath $src).Length / 1KB, 1)
Write-Host "Source  : $kb Ko  ($h1)"
Write-Host "Copie   : $dst"

if ($LocalOnly) { Write-Host "Archive : $zip"; Write-Host "Mode local uniquement : pas de deploiement."; exit 0 }

# 3. Deploiement production via le CLI
$env:Path = "C:\Program Files\nodejs;$env:APPDATA\npm;" + $env:Path
if (-not (Get-Command netlify -ErrorAction SilentlyContinue)) {
  Write-Host ""
  Write-Host "netlify-cli absent : glisse $zip sur" -ForegroundColor Yellow
  Write-Host "https://app.netlify.com/projects/gold-per-hour-calculator/deploys" -ForegroundColor Yellow
  exit 0
}

Push-Location $root
try {
  & netlify link --id $siteID 2>&1 | Out-Null
  & netlify deploy --prod --dir=$site --message "MAJ calculateur or ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
  if ($LASTEXITCODE -ne 0) { throw "Echec du deploiement Netlify (code $LASTEXITCODE)." }
} finally {
  Pop-Location
}
