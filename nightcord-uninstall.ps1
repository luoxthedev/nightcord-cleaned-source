# ==============================================================================
#  Nightcord — Desinstalleur (PowerShell autonome)
#
#  1. Trouve Discord et l'injecte
#  2. Supprime l'injection Nightcord
#  3. Restaure app.asar original (_app.asar -> app.asar)
#  4. Auto-fermeture apres 5 secondes
#
#  Usage : Double-clic sur nightcord-uninstall.bat
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "    ╔═══════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "    ║         NIGHTCORD — DESINSTALLATION           ║" -ForegroundColor Red
    Write-Host "    ╚═══════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

function Write-ProgressBar($Percent, $Label) {
    $width = 36
    $filled = [math]::Floor($width * $Percent / 100)
    $empty  = $width - $filled
    $bar    = ("█" * $filled) + ("░" * $empty)
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

$totalSteps = 4

# ── [1/4] Detection de Discord ────────────────────────────────────────────────
Write-Step 1 $totalSteps "Detection de Discord..."
Write-ProgressBar 10 "Recherche..."

$discord = Find-Discord
if (-not $discord) {
    Write-OK "Discord introuvable — rien a desinstaller."
    Write-ProgressBar 100 "Rien a faire"
    Write-Host ""
    Write-Host "    Fermeture dans 5 secondes..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
    exit 0
}

Write-OK "Trouve : $($discord.Channel)"
Write-ProgressBar 30 "Discord detecte"

# ── [2/4] Fermer Discord ─────────────────────────────────────────────────────
Write-Step 2 $totalSteps "Fermeture de Discord..."
Write-ProgressBar 35 "Arret..."

$procs = Get-Process -Name $discord.Channel -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    Write-OK "Discord ferme"
} else {
    Write-OK "Discord deja ferme"
}
Write-ProgressBar 50 "Pret"

# ── [3/4] Suppression de l'injection ─────────────────────────────────────────
Write-Step 3 $totalSteps "Suppression de l'injection Nightcord..."
Write-ProgressBar 55 "Nettoyage..."

$resourcesDir = Join-Path $discord.AppDir "resources"
$appDir       = Join-Path $resourcesDir "app"
$backupPath   = Join-Path $resourcesDir "_app.asar"
$appAsarPath  = Join-Path $resourcesDir "app.asar"

$uninstalled = $false

# Supprimer le dossier app/ (injection Nightcord)
if (Test-Path $appDir) {
    $pkgFile = Join-Path $appDir "package.json"
    $isNightcord = $false
    if (Test-Path $pkgFile) {
        try {
            $pkg = Get-Content $pkgFile -Raw | ConvertFrom-Json
            if ($pkg.name -eq "discord" -or $pkg.name -eq "nightcord") {
                $isNightcord = $true
            }
        } catch { $isNightcord = $true }
    }
    # Aussi verifier si index.js contient "Nightcord"
    $indexFile = Join-Path $appDir "index.js"
    if (Test-Path $indexFile) {
        $content = Get-Content $indexFile -Raw -ErrorAction SilentlyContinue
        if ($content -match "Nightcord" -or $content -match "patcher") {
            $isNightcord = $true
        }
    }

    if ($isNightcord) {
        Remove-Item $appDir -Recurse -Force
        Write-OK "Injection Nightcord supprimee"
        $uninstalled = $true
    } else {
        Write-Host "         Dossier app/ ne semble pas etre Nightcord, ignore." -ForegroundColor DarkGray
    }
} else {
    Write-Host "         Pas de dossier app/ a supprimer" -ForegroundColor DarkGray
}

Write-ProgressBar 70 "Restauration..."

# Restaurer _app.asar -> app.asar
if (Test-Path $backupPath) {
    if (Test-Path $appAsarPath) {
        Remove-Item $appAsarPath -Force
    }
    Rename-Item -Path $backupPath -NewName "app.asar" -Force
    Write-OK "app.asar original restaure"
    $uninstalled = $true
} else {
    Write-Host "         Pas de backup _app.asar a restaurer" -ForegroundColor DarkGray
}

# ── [4/4] Nettoyage des fichiers Nightcord ────────────────────────────────────
Write-Step 4 $totalSteps "Nettoyage des fichiers..."
Write-ProgressBar 85 "Suppression..."

$nightcordDir = Join-Path $env:LOCALAPPDATA "Nightcord"
if (Test-Path $nightcordDir) {
    Remove-Item $nightcordDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Fichiers Nightcord supprimes"
} else {
    Write-OK "Pas de fichiers a supprimer"
}

Write-ProgressBar 100 "Desinstallation terminee"

# ── Resultat ──────────────────────────────────────────────────────────────────
Write-Host ""
if ($uninstalled) {
    Write-Host "    ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "    ║                                                       ║" -ForegroundColor Green
    Write-Host "    ║     " -NoNewline -ForegroundColor Green
    Write-Host "  NIGHTCORD DESINSTALLE AVEC SUCCES !" -NoNewline -ForegroundColor White
    Write-Host "    ║" -ForegroundColor Green
    Write-Host "    ║                                                       ║" -ForegroundColor Green
    Write-Host "    ║     Redemarrez Discord pour revenir a la version      ║" -ForegroundColor Green
    Write-Host "    ║     originale.                                        ║" -ForegroundColor Green
    Write-Host "    ║                                                       ║" -ForegroundColor Green
    Write-Host "    ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "    Aucune installation Nightcord detectee." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "    Fermeture automatique dans 5 secondes..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5
