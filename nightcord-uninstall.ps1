$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "    ===============================================" -ForegroundColor Red
    Write-Host "    |         NIGHTCORD -- DESINSTALLATION         |" -ForegroundColor Red
    Write-Host "    ===============================================" -ForegroundColor Red
    Write-Host ""
}

function Write-ProgressBar($Percent, $Label) {
    $width = 36
    $filled = [math]::Floor($width * $Percent / 100)
    $empty = $width - $filled
    $bar = ("#" * $filled) + ("." * $empty)
    $color = if ($Percent -ge 100) { "Green" } elseif ($Percent -ge 50) { "Cyan" } else { "Yellow" }

    Write-Host "    [" -NoNewline
    Write-Host $bar -NoNewline -ForegroundColor $color
    Write-Host "] " -NoNewline
    Write-Host ("{0,3}" -f $Percent) -NoNewline -ForegroundColor $color
    Write-Host "% " -NoNewline
    Write-Host $Label -ForegroundColor DarkGray
}

function Write-Step($Number, $Total, $Message) {
    Write-Host ""
    Write-Host "    [$Number/$Total] " -NoNewline -ForegroundColor Yellow
    Write-Host $Message -ForegroundColor White
}

function Write-OK($Message) {
    Write-Host "         " -NoNewline
    Write-Host "  OK  " -NoNewline -ForegroundColor Black -BackgroundColor Green
    Write-Host " $Message" -ForegroundColor Green
}

function Write-Fail($Message) {
    Write-Host ""
    Write-Host "    [ERREUR] $Message" -ForegroundColor Red
    Write-Host ""
    Write-Host "    Appuyez sur une touche pour quitter..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

function Find-Discord {
    $channels = @("Discord", "DiscordPTB", "DiscordCanary")
    foreach ($channel in $channels) {
        $base = Join-Path $env:LOCALAPPDATA $channel
        if (-not (Test-Path $base)) { continue }

        $versions = Get-ChildItem $base -Filter "app-*" -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending

        if ($versions.Count -gt 0) {
            return @{ Channel = $channel; AppDir = $versions[0].FullName; BaseDir = $base }
        }
    }

    return $null
}

function Restart-Discord($Channel) {
    $base = Join-Path $env:LOCALAPPDATA $Channel
    $updateExe = Join-Path $base "Update.exe"
    if (Test-Path $updateExe) {
        Start-Process -FilePath $updateExe -ArgumentList "--processStart", "$Channel.exe" -WindowStyle Hidden
        return
    }

    $discordExe = Join-Path $base "$Channel.exe"
    if (Test-Path $discordExe) {
        Start-Process -FilePath $discordExe -WindowStyle Hidden
    }
}

try {
    Write-Banner
    $totalSteps = 5

    Write-Step 1 $totalSteps "Detection de Discord..."
    Write-ProgressBar 10 "Recherche..."

    $discord = Find-Discord
    if (-not $discord) {
        Write-OK "Discord introuvable - rien a desinstaller."
        Write-ProgressBar 100 "Rien a faire"
        Write-Host ""
        Write-Host "    Fermeture dans 5 secondes..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
        exit 0
    }

    Write-OK "Trouve : $($discord.Channel)"
    Write-ProgressBar 30 "Discord detecte"

    Write-Step 2 $totalSteps "Fermeture de Discord..."
    Write-ProgressBar 35 "Arret..."

    $processes = Get-Process -Name $discord.Channel -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        Write-OK "Discord ferme"
    } else {
        Write-OK "Discord deja ferme"
    }

    Write-ProgressBar 50 "Pret"

    Write-Step 3 $totalSteps "Suppression de l'injection Nightcord..."
    Write-ProgressBar 55 "Nettoyage..."

    $resourcesDir = Join-Path $discord.AppDir "resources"
    $appDir = Join-Path $resourcesDir "app"
    $backupPath = Join-Path $resourcesDir "_app.asar"
    $appAsarPath = Join-Path $resourcesDir "app.asar"
    $uninstalled = $false

    if (Test-Path $appDir) {
        $indexFile = Join-Path $appDir "index.js"
        $packageFile = Join-Path $appDir "package.json"
        $isNightcord = $false

        if (Test-Path $packageFile) {
            try {
                $package = Get-Content $packageFile -Raw | ConvertFrom-Json
                $isNightcord = $package.name -eq "discord" -or $package.name -eq "nightcord"
            } catch {
                $isNightcord = $true
            }
        }

        if (-not $isNightcord -and (Test-Path $indexFile)) {
            $content = Get-Content $indexFile -Raw -ErrorAction SilentlyContinue
            $isNightcord = $content -match "Nightcord" -or $content -match "patcher"
        }

        if ($isNightcord) {
            Remove-Item $appDir -Recurse -Force
            Write-OK "Injection Nightcord supprimee"
            $uninstalled = $true
        } else {
            Write-Host "         Dossier app/ non Nightcord, ignore." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "         Pas de dossier app/ a supprimer" -ForegroundColor DarkGray
    }

    Write-ProgressBar 70 "Restauration..."

    if (Test-Path $backupPath) {
        if (Test-Path $appAsarPath) {
            Remove-Item $appAsarPath -Recurse -Force
        }

        Rename-Item -Path $backupPath -NewName "app.asar" -Force
        Write-OK "app.asar original restaure"
        $uninstalled = $true
    } else {
        Write-Host "         Pas de backup _app.asar a restaurer" -ForegroundColor DarkGray
    }

    Write-Step 4 $totalSteps "Nettoyage des fichiers..."
    Write-ProgressBar 85 "Suppression..."

    $nightcordDir = Join-Path $env:LOCALAPPDATA "Nightcord"
    if (Test-Path $nightcordDir) {
        Remove-Item $nightcordDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Fichiers Nightcord supprimes"
    } else {
        Write-OK "Pas de fichiers a supprimer"
    }

    Write-Step 5 $totalSteps "Redemarrage de Discord..."
    Write-ProgressBar 95 "Redemarrage..."

    Restart-Discord $discord.Channel

    Write-OK "Discord redemarre"
    Write-ProgressBar 100 "Termine"

    Write-Host ""
    if ($uninstalled) {
        Write-Host "    ===============================================" -ForegroundColor Green
        Write-Host "    |                                              |" -ForegroundColor Green
        Write-Host "    |   NIGHTCORD DESINSTALLE AVEC SUCCES !       |" -ForegroundColor Green
        Write-Host "    |                                              |" -ForegroundColor Green
        Write-Host "    |   Discord a ete redemarre en mode normal.    |" -ForegroundColor Green
        Write-Host "    |                                              |" -ForegroundColor Green
        Write-Host "    ===============================================" -ForegroundColor Green
    } else {
        Write-Host "    Aucune installation Nightcord detectee." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "    Fermeture automatique dans 5 secondes..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 5
} catch {
    Write-Fail $_
}
