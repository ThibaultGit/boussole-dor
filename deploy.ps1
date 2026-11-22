# Prepare index.html, valide le JS et pousse vers GitHub (deploiement auto Vercel).
#   .\deploy.ps1            -> copie + validation + commit + push GitHub (declenche Vercel)
#   .\deploy.ps1 -LocalOnly -> copie + validation locale seulement
param(
  [switch]$LocalOnly,
  [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $root "calculateur-or-papa.html"
$dst  = Join-Path $root "index.html"

if (-not (Test-Path -LiteralPath $src)) { throw "Source introuvable : $src" }

# 1. Copie exacte vers index.html (point d'entree Vercel)
Copy-Item -LiteralPath $src -Destination $dst -Force

$h1 = (Get-FileHash -LiteralPath $src).Hash
$h2 = (Get-FileHash -LiteralPath $dst).Hash
if ($h1 -ne $h2) { throw "La copie differe de la source (encodage ?)." }

$kb = [math]::Round((Get-Item -LiteralPath $src).Length / 1KB, 1)
Write-Host "Source : $kb Ko ($h1)"
Write-Host "Copie  : $dst"

# 2. Validation syntaxique du bloc <script> si Node est disponible
if (Get-Command node -ErrorAction SilentlyContinue) {
  $html = [System.IO.File]::ReadAllText($dst, [System.Text.UTF8Encoding]::new($false))
  $m = [regex]::Match($html, '(?s)<script>(.*)</script>')
  if (-not $m.Success) { throw "Bloc <script> introuvable dans $dst" }
  $tmp = [System.IO.Path]::GetTempFileName() + ".js"
  try {
    [System.IO.File]::WriteAllText($tmp, $m.Groups[1].Value, [System.Text.UTF8Encoding]::new($false))
    & node --check $tmp
    if ($LASTEXITCODE -ne 0) { throw "Erreur de syntaxe JS detectee par node --check." }
    Write-Host "JS OK  : node --check"
  } finally {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
  }
}

if ($LocalOnly) {
  Write-Host "Mode local uniquement : pas de push GitHub."
  exit 0
}

# 3. Verification du depot distant GitHub et push (declenche Vercel)
Push-Location $root
try {
  $origin = (& git remote get-url origin 2>$null)
  if (-not $origin) {
    Write-Host ""
    Write-Host "Aucun remote 'origin' configure." -ForegroundColor Yellow
    Write-Host "1) Cree un depot sur https://github.com/new" -ForegroundColor Yellow
    Write-Host "2) Lie-le avec : git remote add origin <URL_DU_DEPOT_GITHUB>" -ForegroundColor Yellow
    Write-Host "3) Pousse avec : git push -u origin main" -ForegroundColor Yellow
    exit 0
  }

  & git add calculateur-or-papa.html index.html vercel.json deploy.ps1 AGENTS.md .gitignore
  $changes = & git status --porcelain
  if ($changes) {
    $msg = if ($Message) { $Message } else { "MAJ Boussole d'Or ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))" }
    & git commit -m $msg
    if ($LASTEXITCODE -ne 0) { throw "Echec du commit Git." }
  }

  & git push
  if ($LASTEXITCODE -ne 0) { throw "Echec du push GitHub (code $LASTEXITCODE)." }
  Write-Host "Push GitHub termine : Vercel va deployer automatiquement." -ForegroundColor Green
} finally {
  Pop-Location
}
