# ==============================================================================
#  Nightcord — Installeur autonome (PowerShell)
#
#  Fait TOUT automatiquement :
#  1. Trouve Discord (Stable / PTB / Canary)
#  2. Telecharge les fichiers Nightcord depuis GitHub
#  3. Backup app.asar -> _app.asar
#  4. Injecte Nightcord dans Discord
#  5. Auto-fermeture apres 5 secondes
#
#  Usage : Double-clic sur nightcord-install.bat OU clic droit PowerShell
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# ── Config ────────────────────────────────────────────────────────────────────
$Repo         = "luoxthedev/nightcord-cleaned-source"
$InstallDir   = Join-Path $env:LOCALAPPDATA "Nightcord"
$VersionFile  = Join-Path $InstallDir "version.txt"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "    ===============================================" -ForegroundColor Cyan
    Write-Host "    |           NIGHTCORD  INSTALLER               |" -ForegroundColor Cyan
    Write-Host "    |     Injection dans Discord Desktop           |" -ForegroundColor DarkCyan
    Write-Host "    ===============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-ProgressBar($Percent, $Label) {
    $width = 36
    $filled = [math]::Floor($width * $Percent / 100)
    $empty  = $width - $filled
    $bar    = ("#" * $filled) + ("." * $empty)
    $color  = if ($Percent -ge 100) { "Green" } elseif ($Percent -ge 50) { "Cyan" } else { "Yellow" }

    Write-Host "    [" -NoNewline
    Write-Host $bar -NoNewline -ForegroundColor $color
    Write-Host "] " -NoNewline
    Write-Host ("{0,3}" -f $Percent) -NoNewline -ForegroundColor $color
    Write-Host "% " -NoNewline
    Write-Host $Label -ForegroundColor DarkGray
}

function Write-Step($n, $total, $msg) {
    Write-Host ""
    Write-Host "    [$n/$total] " -NoNewline -ForegroundColor Yellow
    Write-Host $msg -ForegroundColor White
}

function Write-OK($msg) {
    Write-Host "         " -NoNewline
    Write-Host "  OK  " -NoNewline -ForegroundColor Black -BackgroundColor Green
    Write-Host " $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host ""
    Write-Host "    [ERREUR] $msg" -ForegroundColor Red
    Write-Host ""
    Write-Host "    Appuyez sur une touche pour quitter..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

function Find-Discord {
    $channels = @("Discord", "DiscordPTB", "DiscordCanary")
    foreach ($ch in $channels) {
        $base = Join-Path $env:LOCALAPPDATA $ch
        if (-not (Test-Path $base)) { continue }
        $versions = Get-ChildItem $base -Filter "app-*" -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        if ($versions.Count -gt 0) {
            return @{ Channel = $ch; AppDir = $versions[0].FullName; BaseDir = $base }
        }
    }
    return $null
}

# ── Demarrage ─────────────────────────────────────────────────────────────────
Write-Banner

$totalSteps = 5

# ── [1/5] Detection de Discord ────────────────────────────────────────────────
Write-Step 1 $totalSteps "Detection de Discord..."
Write-ProgressBar 10 "Recherche..."

$discord = Find-Discord
if (-not $discord) {
    Write-Fail "Discord introuvable !`n         Installez Discord depuis https://discord.com puis relancez cet installeur."
}

Write-OK "Trouve : $($discord.Channel)"
Write-ProgressBar 20 "Discord detecte"

# ── [2/5] Telechargement des fichiers Nightcord ──────────────────────────────
Write-Step 2 $totalSteps "Telechargement depuis GitHub..."
Write-ProgressBar 25 "Connexion..."

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

try {
    $apiUrl  = "https://api.github.com/repos/$Repo/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing `
        -Headers @{ "User-Agent" = "Nightcord-Installer/3.0"; "Accept" = "application/vnd.github.v3+json" }

    $version  = $release.tag_name
    $assets   = $release.assets

    Write-Host "         Version : $version" -ForegroundColor DarkGray
    Write-ProgressBar 35 "Telechargement..."

    # Telecharger chaque asset dans le dossier dist
    $totalAssets = $assets.Count
    $i = 0
    foreach ($asset in $assets) {
        $i++
        $pct = 35 + [math]::Floor(30 * $i / $totalAssets)
        Write-ProgressBar $pct "$($asset.name)"
        $outPath = Join-Path $InstallDir $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outPath -UseBasicParsing `
            -Headers @{ "User-Agent" = "Nightcord-Installer/3.0" }
    }

    # Si c'est un zip, l'extraire
    $zipFile = $assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if ($zipFile) {
        $zipPath = Join-Path $InstallDir $zipFile.name
        $extractDir = Join-Path $InstallDir "dist"
        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        Remove-Item $zipPath -Force
    }

    Set-Content -Path $VersionFile -Value $version
    Write-OK "Nightcord $version telecharge"
    Write-ProgressBar 65 "Fichiers prets"
} catch {
    Write-Fail "Echec du telechargement.`n         Verifiez votre connexion internet.`n         Detail : $_"
}

# ── [3/5] Backup de Discord ──────────────────────────────────────────────────
Write-Step 3 $totalSteps "Sauvegarde de Discord..."
Write-ProgressBar 70 "Backup..."

$resourcesDir = Join-Path $discord.AppDir "resources"
$appAsarPath  = Join-Path $resourcesDir "app.asar"
$backupPath   = Join-Path $resourcesDir "_app.asar"

# Tuer Discord s'il tourne
$procs = Get-Process -Name $discord.Channel -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "         Fermeture de $($discord.Channel)..." -ForegroundColor DarkGray
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# Backup app.asar -> _app.asar
if (Test-Path $appAsarPath) {
    if (Test-Path $backupPath) { Remove-Item $backupPath -Force }
    Rename-Item -Path $appAsarPath -NewName "_app.asar" -Force
    Write-OK "app.asar sauvegarde"
} elseif (Test-Path $backupPath) {
    Write-OK "Backup deja present"
} else {
    Write-Host "         Pas d'app.asar a sauvegarder (deja injecte ?)" -ForegroundColor DarkGray
}
Write-ProgressBar 75 "Pret pour injection"

# ── [4/5] Injection Nightcord ────────────────────────────────────────────────
Write-Step 4 $totalSteps "Injection de Nightcord..."
Write-ProgressBar 80 "Copie des fichiers..."

# Creer le dossier app/ pour l'injection
$appDir = Join-Path $resourcesDir "app"
if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

# Trouver patcher.js dans les dist telecharges
$patcherSrc = Join-Path $InstallDir "dist\desktop\patcher.js"
if (-not (Test-Path $patcherSrc)) {
    # Essayer dans le root du install dir
    $patcherSrc = Join-Path $InstallDir "patcher.js"
}
if (-not (Test-Path $patcherSrc)) {
    # Chercher recursivement
    $found = Get-ChildItem $InstallDir -Filter "patcher.js" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $patcherSrc = $found.FullName }
}

if (-not (Test-Path $patcherSrc)) {
    Write-Fail "patcher.js introuvable dans les fichiers telecharges !"
}

# Copier les fichiers dist dans le dossier app/
$distSrc = Split-Path $patcherSrc -Parent
$distDst = Join-Path $appDir "dist"
New-Item -ItemType Directory -Force -Path $distDst | Out-Null

# Copier tout le dossier dist
Copy-Item -Path (Join-Path $distSrc "*") -Destination $distDst -Recurse -Force

Write-ProgressBar 85 "Patch en cours..."

# Generer package.json
$packageObj = @{ name = "discord"; main = "index.js" }
$packageObj | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $appDir "package.json")

# Generer index.js qui charge le patcher
$patcherRelative = "dist\desktop\patcher.js"
$indexContent = @"
"use strict";
const path = require("path");
const { app } = require("electron");

try {
    require(path.join(__dirname, "$($patcherRelative.Replace('\', '\\'))"));
} catch (e) {
    console.error("[Nightcord] Injection failed:", e.message);
    const backup = path.join(__dirname, "..", "_app.asar");
    const fs = require("fs");
    if (fs.existsSync(backup)) {
        require(backup);
    }
}
"@

Set-Content -Path (Join-Path $appDir "index.js") -Value $indexContent

Write-OK "Nightcord injecte !"
Write-ProgressBar 95 "Finalisation..."

# ── [5/5] Nettoyage ──────────────────────────────────────────────────────────
Write-Step 5 $totalSteps "Nettoyage..."

# Supprimer les anciens _app.asar orphelins (si existant)
$oldBackup = Join-Path $resourcesDir "_app.asar"
# Garder le backup pour le desinstalleur

Write-OK "Termine"
Write-ProgressBar 100 "Installation completee"

# --- Succes ---
Write-Host ""
Write-Host "    ===============================================" -ForegroundColor Green
Write-Host "    |                                              |" -ForegroundColor Green
Write-Host "    |   NIGHTCORD INSTALLE AVEC SUCCES !          |" -ForegroundColor Green
Write-Host "    |                                              |" -ForegroundColor Green
Write-Host "    |   Redemarrez Discord pour appliquer.        |" -ForegroundColor Green
Write-Host "    |                                              |" -ForegroundColor Green
Write-Host "    ===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "    Pour desinstaller : nightcord-uninstall.bat" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    Fermeture automatique dans 5 secondes..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5
