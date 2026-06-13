import { execSync } from "child_process";
import { readFileSync } from "fs";
import { createInterface } from "readline";

const pkg = JSON.parse(readFileSync("package.json", "utf8"));
const currentVersion = pkg.version;

function run(cmd) {
    console.log(`> ${cmd}`);
    execSync(cmd, { stdio: "inherit", shell: true });
}

function runCapture(cmd) {
    return execSync(cmd, { shell: true, encoding: "utf8" }).trim();
}

function ask(question) {
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(question, ans => { rl.close(); resolve(ans.trim()); }));
}

async function releaseNightly() {
    console.log(`\n🚀 Release Nightcord Nightly`);
    console.log(`   Branche: main`);
    console.log(`   Action: push sur main → crée release "nightly"\n`);

    const confirm = await ask("Continuer ? (y/N) ");
    if (confirm.toLowerCase() !== "y") { console.log("Annulé."); return; }

    // Vérifier qu'on est sur main
    const branch = runCapture("git branch --show-current");
    if (branch !== "main") {
        console.log(`⚠️  Tu n'es pas sur main (actuellement: ${branch}).`);
        const switchConfirm = await ask("Switcher sur main ? (y/N) ");
        if (switchConfirm.toLowerCase() !== "y") { console.log("Annulé."); return; }
        run("git checkout main");
        run("git pull origin main");
    }

    // Push
    run("git push origin main");
    console.log("\n✅ Push effectué ! Le workflow Release Nightcord va se lancer.");
    console.log("   → https://github.com/luoxthedev/nightcord-cleaned-source/actions");
}

async function releaseStable() {
    console.log(`\n🏷️  Release Nightcord Stable`);
    console.log(`   Version actuelle: v${currentVersion}\n`);

    // Vérifier le statut git
    const status = runCapture("git status --porcelain");
    if (status) {
        console.log("⚠️  Il y a des changements non commit :");
        console.log(status);
        const pushAnyway = await ask("Continuer quand même ? (y/N) ");
        if (pushAnyway.toLowerCase() !== "y") { console.log("Annulé."); return; }
    }

    // Demander la version
    console.log(`Options:`);
    console.log(`  1) Garder v${currentVersion}`);
    console.log(`  2) Patch (v${bump(currentVersion, "patch")})`);
    console.log(`  3) Minor (v${bump(currentVersion, "minor")})`);
    console.log(`  4) Major (v${bump(currentVersion, "major")})`);
    console.log(`  5) Custom`);

    const choice = await ask("\nChoix (1-5, défaut: 1): ");
    let newVersion;

    switch (choice) {
        case "2": newVersion = bump(currentVersion, "patch"); break;
        case "3": newVersion = bump(currentVersion, "minor"); break;
        case "4": newVersion = bump(currentVersion, "major"); break;
        case "5": newVersion = await ask("Version (sans v): "); break;
        default: newVersion = currentVersion;
    }

    if (!newVersion.startsWith("v")) newVersion = "v" + newVersion;

    console.log(`\n📋 Résumé:`);
    console.log(`   Tag: ${newVersion}`);
    console.log(`   Branche: main`);
    console.log(`   Action: tag push → crée release "${newVersion}"\n`);

    const confirm = await ask("Confirmer ? (y/N) ");
    if (confirm.toLowerCase() !== "y") { console.log("Annulé."); return; }

    // Switch to main & pull
    const branch = runCapture("git branch --show-current");
    if (branch !== "main") {
        console.log("Switching to main...");
        run("git checkout main");
    }
    run("git pull origin main");

    // Update version in package.json if needed
    if (newVersion !== `v${currentVersion}`) {
        const cleanVersion = newVersion.slice(1);
        run(`npm version ${cleanVersion} --no-git-tag-version`);
        run("git add package.json");
        run(`git commit -m "chore: bump version to ${newVersion}" --author="luoxthedev <luox.offi@gmail.com>"`);
    }

    // Create & push tag
    run(`git tag -a ${newVersion} -m "Release ${newVersion}"`);
    run(`git push origin ${newVersion}`);
    console.log(`\n✅ Tag ${newVersion} pushé ! Le workflow Release Stable va se lancer.`);
    console.log(`   → https://github.com/luoxthedev/nightcord-cleaned-source/actions`);
}

function bump(version, type) {
    const [major, minor, patch] = version.split(".").map(Number);
    switch (type) {
        case "major": return `${major + 1}.0.0`;
        case "minor": return `${major}.${minor + 1}.0`;
        case "patch": return `${major}.${minor}.${patch + 1}`;
    }
}

// Main
const mode = process.argv[2];
if (mode === "nightly") releaseNightly();
else if (mode === "stable") releaseStable();
else {
    console.log("Usage: node scripts/release.mjs <nightly|stable>");
    process.exit(1);
}
