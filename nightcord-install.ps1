# ==============================================================================
#  Nightcord -- Installeur autonome (PowerShell)
#
#  Fait TOUT automatiquement :
#  1. Trouve Discord (Stable / PTB / Canary)
#  2. Telecharge nightcord-dist.zip depuis GitHub
#  3. Backup app.asar -> _app.asar
#  4. Injecte Nightcord dans Discord
#  5. Redemarre Discord
#  6. Auto-fermeture apres 5 secondes
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# --- Config ---
$Repo         = "luoxthedev/nightcord-cleaned-source"
$InstallDir   = Join-Path $env:LOCALAPPDATA "Nightcord"
$VersionFile  = Join-Path $InstallDir "version.txt"

# --- Helpers ---

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

function Restart-Discord($Channel) {
    $base = Join-Path $env:LOCALAPPDATA $Channel
    $exe = Join-Path $base "Update.exe"
    if (Test-Path $exe) {
        Start-Process -FilePath $exe -ArgumentList "--processStart", "$Channel.exe" -WindowStyle Hidden
    } else {
        $exe = Join-Path $base "$Channel.exe"
        if (Test-Path $exe) {
            Start-Process -FilePath $exe -WindowStyle Hidden
        }
    }
}

# --- Demarrage ---
Write-Banner

$totalSteps = 5

# --- [1/5] Detection de Discord ---
Write-Step 1 $totalSteps "Detection de Discord..."
Write-ProgressBar 10 "Recherche..."

$discord = Find-Discord
if (-not $discord) {
    Write-Fail "Discord introuvable !`n         Installez Discord depuis https://discord.com puis relancez cet installeur."
}

Write-OK "Trouve : $($discord.Channel)"
Write-ProgressBar 20 "Discord detecte"

# --- [2/5] Telechargement ---
Write-Step 2 $totalSteps "Telechargement depuis GitHub..."
Write-ProgressBar 25 "Connexion..."

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

try {
    $apiUrl  = "https://api.github.com/repos/$Repo/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing `
        -Headers @{ "User-Agent" = "Nightcord-Installer/3.0"; "Accept" = "application/vnd.github.v3+json" }

    $version = $release.tag_name
    $zipAsset = $release.assets | Where-Object { $_.name -eq "nightcord-dist.zip" } | Select-Object -First 1

    if (-not $zipAsset) {
        Write-Fail "nightcord-dist.zip introuvable dans la release $version"
    }

    Write-Host "         Version : $version" -ForegroundColor DarkGray
    Write-ProgressBar 35 "Telechargement..."

    $zipPath = Join-Path $InstallDir "nightcord-dist.zip"
    Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -UseBasicParsing `
        -Headers @{ "User-Agent" = "Nightcord-Installer/3.0" }

    Write-ProgressBar 60 "Extraction..."

    # Extraire
    $extractDir = Join-Path $InstallDir "dist"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    Remove-Item $zipPath -Force

    Set-Content -Path $VersionFile -Value $version
    Write-OK "Nightcord $version telecharge"
    Write-ProgressBar 65 "Fichiers prets"
} catch {
    Write-Fail "Echec du telechargement.`n         Detail : $_"
}

# --- [3/5] Backup ---
Write-Step 3 $totalSteps "Sauvegarde de Discord..."
Write-ProgressBar 70 "Backup..."

$resourcesDir = Join-Path $discord.AppDir "resources"
$appAsarPath  = Join-Path $resourcesDir "app.asar"
$backupPath   = Join-Path $resourcesDir "_app.asar"

# Fermer Discord
$procs = Get-Process -Name $discord.Channel -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "         Fermeture de $($discord.Channel)..." -ForegroundColor DarkGray
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Backup app.asar -> _app.asar
if (Test-Path $appAsarPath) {
    if (Test-Path $backupPath) { Remove-Item $backupPath -Force }
    Rename-Item -Path $appAsarPath -NewName "_app.asar" -Force
    Write-OK "app.asar sauvegarde"
} elseif (Test-Path $backupPath) {
    Write-OK "Backup deja present"
} else {
    Write-Host "         Pas d'app.asar a sauvegarder" -ForegroundColor DarkGray
}
Write-ProgressBar 75 "Pret"

# --- [4/5] Injection ---
Write-Step 4 $totalSteps "Injection de Nightcord..."
Write-ProgressBar 80 "Copie des fichiers..."

$appDir = Join-Path $resourcesDir "app"
if (Test-Path $appDir) { Remove-Item $appDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

# Copier dist/desktop/ vers app/dist/desktop/
$distSrc = Join-Path $InstallDir "dist\dist\desktop"
if (-not (Test-Path $distSrc)) {
    $distSrc = Join-Path $InstallDir "dist\desktop"
}
$distDst = Join-Path $appDir "dist"
New-Item -ItemType Directory -Force -Path $distDst | Out-Null
Copy-Item -Path $distSrc -Destination (Join-Path $distDst "desktop") -Recurse -Force

# Copier les JSON de plugins si presents
$pluginSrc = Join-Path $InstallDir "dist"
$jsonFiles = Get-ChildItem $pluginSrc -Filter "*.json" -ErrorAction SilentlyContinue
if ($jsonFiles) {
    $appDistRoot = Join-Path $appDir "dist"
    foreach ($f in $jsonFiles) {
        Copy-Item $f.FullName -Destination $appDistRoot -Force
    }
}

Write-ProgressBar 85 "Patch en cours..."

# Generer package.json
@{ name = "discord"; main = "index.js" } | ConvertTo-Json -Depth 3 |
    Set-Content -Path (Join-Path $appDir "package.json")

# Generer index.js
@indexContent = @"
"use strict";
const path = require("path");
const { app } = require("electron");

try {
    require(path.join(__dirname, "dist", "desktop", "patcher.js"));
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

# --- [5/5] Redemarrage ---
Write-Step 5 $totalSteps "Redemarrage de Discord..."
Write-ProgressBar 98 "Redemarrage..."

Restart-Discord $discord.Channel

Write-OK "Discord redemarre !"
Write-ProgressBar 100 "Installation terminee"

# --- Succes ---
Write-Host ""
Write-Host "    ===============================================" -ForegroundColor Green
Write-Host "    |                                              |" -ForegroundColor Green
Write-Host "    |   NIGHTCORD INSTALLE AVEC SUCCES !          |" -ForegroundColor Green
Write-Host "    |                                              |" -ForegroundColor Green
Write-Host "    |   Discord a ete redemarre.                   |" -ForegroundColor Green
Write-Host "    |                                              |" -ForegroundColor Green
Write-Host "    ===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "    Pour desinstaller : nightcord-uninstall.bat" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    Fermeture automatique dans 5 secondes..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5
