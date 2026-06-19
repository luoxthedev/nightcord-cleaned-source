/*
 * Nightcord — Launch Discord with Nightcord injected
 * Builds, injects into Discord, and launches it. No external tools needed.
 *
 * Usage: pnpm start
 */

import { execSync, exec } from "child_process";
import { existsSync, mkdirSync, readdirSync, renameSync, rmSync, statSync, writeFileSync, cpSync } from "fs";
import { join } from "path";

const BASE_DIR = join(import.meta.dirname, "..");
const DIST_DIR = join(BASE_DIR, "dist");

// ── Find Discord installation ──────────────────────────────────────────────
function findDiscord() {
    const localAppData = process.env.LOCALAPPDATA || "";
    const channels = ["Discord", "DiscordPTB", "DiscordCanary"];

    for (const channel of channels) {
        const base = join(localAppData, channel);
        if (!existsSync(base)) continue;

        let versions;
        try {
            versions = readdirSync(base)
                .filter(d => /^app-\d+\.\d+\.\d+$/.test(d))
                .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
        } catch { continue; }

        if (versions.length > 0) {
            return {
                channel,
                base,
                appDir: join(base, versions[0]),
                resources: join(base, versions[0], "resources")
            };
        }
    }
    return null;
}

// ── Kill Discord ───────────────────────────────────────────────────────────
function killDiscord(channel) {
    try {
        execSync(`taskkill /F /IM "${channel}.exe" 2>nul`, { stdio: "ignore" });
    } catch { }
    // Wait for process to fully exit
    const end = Date.now() + 2000;
    while (Date.now() < end) { /* busy wait 2s */ }
}

// ── Build ──────────────────────────────────────────────────────────────────
function build() {
    console.log("[launch] Building Nightcord...");
    execSync("node --require=./scripts/suppressExperimentalWarnings.js scripts/build/build.mjs --standalone", {
        cwd: BASE_DIR,
        stdio: "inherit"
    });

    // Also build desktop (patcher.js, renderer.js, etc.)
    try {
        execSync("npx tsx scripts/build/buildDesktop.mts", {
            cwd: BASE_DIR,
            stdio: "inherit"
        });
    } catch {
        // buildDesktop might not exist or fail — that's OK if standalone already built desktop
    }

    console.log("[launch] Build done.");
}

// ── Backup validation ───────────────────────────────────────────────────────
const MIN_VALID_ASAR_SIZE = 500_000; // Real Discord asar is several MB

function isValidAsarBackup(filePath) {
    if (!existsSync(filePath)) return false;
    try {
        const stat = statSync(filePath);
        if (stat.isDirectory()) return false;
        if (stat.size < MIN_VALID_ASAR_SIZE) return false;
        return true;
    } catch {
        return false;
    }
}

// ── Inject ─────────────────────────────────────────────────────────────────
function inject(discord) {
    const { resources, channel, base } = discord;
    const appAsarPath = join(resources, "app.asar");
    const backupPath = join(resources, "_app.asar");
    const appDir = join(resources, "app");

    // Validate existing backup
    if (!isValidAsarBackup(backupPath)) {
        if (existsSync(backupPath)) {
            console.log("[launch] _app.asar is corrupted. Removing it...");
            rmSync(backupPath, { force: true });
        }
    }

    // Clean injected app/ dir from previous attempts
    if (existsSync(appDir)) {
        rmSync(appDir, { recursive: true, force: true });
    }

    // Backup app.asar -> _app.asar (only if not already backed up)
    if (existsSync(appAsarPath) && !existsSync(backupPath)) {
        if (!isValidAsarBackup(appAsarPath)) {
            console.error("[launch] ERROR: app.asar is also missing or corrupted.");
            console.error("[launch] Reinstall Discord from https://discord.com/download");
            console.error("[launch] Then run 'pnpm start' again.");
            process.exit(1);
        }
        console.log("[launch] Backing up app.asar -> _app.asar...");
        renameSync(appAsarPath, backupPath);
    } else if (existsSync(backupPath)) {
        console.log("[launch] Backup already exists.");
    }

    // Create app/ directory
    mkdirSync(appDir, { recursive: true });

    // Write package.json
    writeFileSync(join(appDir, "package.json"), JSON.stringify({
        name: "discord",
        main: "index.js"
    }, null, 2));

    // Write index.js — loads nightcord-index.js which handles everything
    writeFileSync(join(appDir, "index.js"), `"use strict";
const path = require("path");
const fs = require("fs");

// Nightcord injection entry point
const nightcordEntry = path.join(__dirname, "nightcord-index.js");

if (fs.existsSync(nightcordEntry)) {
    require(nightcordEntry);
} else {
    console.error("[Nightcord] nightcord-index.js not found, falling back to patcher.js");
    try {
        require(path.join(__dirname, "dist", "desktop", "patcher.js"));
    } catch (e) {
        console.error("[Nightcord] Injection failed:", e.message);
        const backup = path.join(__dirname, "..", "_app.asar");
        if (fs.existsSync(backup)) {
            require(backup);
        }
    }
}
`);

    // Copy nightcord-index.js and nightcord-preload.js into app/
    for (const file of ["nightcord-index.js", "nightcord-preload.js"]) {
        const src = join(BASE_DIR, file);
        const dst = join(appDir, file);
        if (existsSync(src)) {
            cpSync(src, dst);
        }
    }

    // Copy dist/desktop/ into app/dist/desktop/
    const distDesktopSrc = join(DIST_DIR, "desktop");
    const distDesktopDst = join(appDir, "dist", "desktop");
    if (existsSync(distDesktopSrc)) {
        mkdirSync(distDesktopDst, { recursive: true });
        for (const f of readdirSync(distDesktopSrc)) {
            const srcPath = join(distDesktopSrc, f);
            const dstPath = join(distDesktopDst, f);
            cpSync(srcPath, dstPath);
        }
    }

    console.log("[launch] Injection done.");
}

// ── Launch Discord ─────────────────────────────────────────────────────────
function launchDiscord(discord) {
    const { channel, base } = discord;
    const updateExe = join(base, "Update.exe");
    const directExe = join(discord.appDir, channel + ".exe");

    console.log(`[launch] Starting ${channel}...`);

    if (existsSync(updateExe)) {
        exec(`"${updateExe}" --processStart "${channel}.exe"`, { detached: true, stdio: "ignore" }).unref();
    } else if (existsSync(directExe)) {
        exec(`"${directExe}"`, { detached: true, stdio: "ignore" }).unref();
    } else {
        console.error(`[launch] Could not find ${channel} executable.`);
        process.exit(1);
    }
}

// ── Main ───────────────────────────────────────────────────────────────────
const discord = findDiscord();
if (!discord) {
    console.error("[launch] Discord not found. Install Discord first.");
    process.exit(1);
}

console.log(`[launch] Found ${discord.channel} at ${discord.appDir}`);

build();
killDiscord(discord.channel);
inject(discord);
launchDiscord(discord);

console.log("[launch] Done! Discord is starting with Nightcord.");
