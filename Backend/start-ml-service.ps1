$ErrorActionPreference = "Stop"

$serviceDir = Join-Path $PSScriptRoot "ml_model_service"
$venvDir = Join-Path $serviceDir ".venv"
$pythonExe = Join-Path $venvDir "Scripts\\python.exe"
$fallbackPython = "C:\Users\Cosmo Mochebelele\AppData\Local\Programs\Python\Python311\python.exe"
$requirementsFile = Join-Path $serviceDir "requirements.txt"
$entryPoint = Join-Path $serviceDir "flask_api.py"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    if (Test-Path $fallbackPython) {
        $env:Path = "C:\Users\Cosmo Mochebelele\AppData\Local\Programs\Python\Python311;C:\Users\Cosmo Mochebelele\AppData\Local\Programs\Python\Python311\Scripts;$env:Path"
    } else {
        Write-Host "Python is not installed or not on PATH." -ForegroundColor Red
        Write-Host "Install Python 3.11+ first, then re-run this script." -ForegroundColor Yellow
        exit 1
    }
}

if (-not (Test-Path $venvDir)) {
    Write-Host "Creating ML virtual environment..." -ForegroundColor Cyan
    if (Test-Path $fallbackPython) {
        & $fallbackPython -m venv $venvDir
    } else {
        python -m venv $venvDir
    }
}

Write-Host "Installing ML dependencies..." -ForegroundColor Cyan
& $pythonExe -m pip install -r $requirementsFile

Write-Host "Starting Explore Lesotho ML service..." -ForegroundColor Green
Push-Location $serviceDir
try {
    $env:PYTHONIOENCODING = "utf-8"
    & $pythonExe $entryPoint
} finally {
    Pop-Location
}
