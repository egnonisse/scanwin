Param(
  [string]$ProjectName = "ticket_scanner"
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host ""
    Write-Host "ERREUR: '$Name' n'est pas disponible dans ce terminal." -ForegroundColor Red
    Write-Host "Action: installe Flutter et ajoute 'flutter\\bin' au PATH, puis relance un nouveau terminal." -ForegroundColor Yellow
    Write-Host "Test: flutter --version" -ForegroundColor Yellow
    exit 1
  }
}

Require-Command "flutter"

Write-Host "Flutter:" -ForegroundColor Cyan
flutter --version

if (-not (Test-Path $ProjectName)) {
  Write-Host ""
  Write-Host "Création du projet Flutter '$ProjectName'..." -ForegroundColor Cyan
  flutter create $ProjectName
} else {
  Write-Host ""
  Write-Host "Le dossier '$ProjectName' existe déjà, skip flutter create." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "OK. Prochaine étape: génération de l'architecture (features/settings + devise paramétrable)." -ForegroundColor Green

