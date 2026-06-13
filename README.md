<div align="center">

# Nightcord

**A custom Discord client built for people who actually care about how Discord runs.**

[![License](https://img.shields.io/badge/license-GPL%20v3-a855f7)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-3b82f6.svg?logo=windows&logoColor=white)](https://github.com/luoxthedev/nightcord-cleaned-source)

---

</div>

Nightcord is a fork of [Equicord](https://github.com/Equicord/Equicord), which itself builds on top of [Vencord](https://github.com/Vendicated/Vencord). We stripped out the obfuscation, cleaned things up, added our own improvements, and kept what works. No bloat, no nonsense.

---

## What's in it

* **Faster startup** — no obfuscation means the client loads noticeably quicker and sits lighter on your CPU and RAM.
* **Plugin support** — compatible with the existing plugin ecosystem. Install community plugins straight from Git links.
* **Better audio** — hardware-optimized voice modules for cleaner, louder audio out of the box.
* **Custom styling** — smoother UI, custom icons, and various quality-of-life improvements.

---

## Installation (Windows)

### Easy way — One-click installer

1. Go to [Releases](https://github.com/luoxthedev/nightcord-cleaned-source/releases)
2. Download the latest **`nightcord-install.ps1`** (or grab it from this repo)
3. Double-click **`nightcord-install.bat`**
4. Wait for the progress bar to finish — Discord will be patched automatically
5. Restart Discord — done!

### What the installer does

```
Detection de Discord...      ████████████████████  OK
Telechargement depuis GitHub  ████████████████████  OK
Backup app.asar...           ████████████████████  OK
Injection de Nightcord...    ████████████████████  OK
Nettoyage...                 ████████████████████  OK

  NIGHTCORD INSTALLE AVEC SUCCES !
```

* Finds your Discord installation (Stable / PTB / Canary)
* Downloads the latest Nightcord build from GitHub
* Backs up the original `app.asar` (so you can always uninstall)
* Injects Nightcord into Discord
* Auto-closes after 5 seconds

### Uninstall

Double-click **`nightcord-uninstall.bat`** — it restores the original Discord in one click.

---

## Building from source

### Requirements

* Git
* Node.js (LTS — v18+)
* pnpm

```bash
npm install -g pnpm
```

### Clone & Build

```bash
git clone https://github.com/luoxthedev/nightcord-cleaned-source
cd nightcord-cleaned-source
pnpm install
pnpm build
```

### Inject into Discord

```bash
pnpm inject
```

### Restore stock Discord

```bash
pnpm uninject
```

---

## Releasing

```bash
# Push a nightly (auto-creates "nightly" release on GitHub)
npm run release:nightly

# Push a stable version (asks for version number, creates git tag)
npm run release:stable
```

---

## Repository

https://github.com/luoxthedev/nightcord-cleaned-source

---

## Credits

Nightcord wouldn't exist without [Equicord](https://github.com/Equicord/Equicord) and [Vencord](https://github.com/Vendicated/Vencord). A huge chunk of what makes this work comes directly from their projects. We're fully aware of that and genuinely appreciate everything they've built — we're just taking it in a different direction. Big thanks to everyone who's contributed to both.

---

## Disclaimer

*Nightcord is not affiliated with Discord Inc. in any way.*

Using third-party clients is technically against Discord's Terms of Service. Use at your own risk.
