import { execFileSync } from "child_process";
import { readFileSync } from "fs";
import { createInterface } from "readline";

const pkg = JSON.parse(readFileSync("package.json", "utf8"));
const currentVersion = pkg.version;

function runWorkflow(workflow, fields) {
    const args = ["workflow", "run", workflow];
    for (const [name, value] of Object.entries(fields)) {
        args.push("-f", `${name}=${value}`);
    }

    console.log(`> gh ${args.join(" ")}`);
    execFileSync("gh", args, { stdio: "inherit" });
}

function ask(question) {
    const rl = createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(question, ans => { rl.close(); resolve(ans.trim()); }));
}

async function releaseNightly() {
    console.log("\nRelease Nightcord Nightly");
    console.log('   Action: lance le workflow manuel "Release Nightcord"\n');

    const confirm = await ask("Continuer ? (y/N) ");
    if (confirm.toLowerCase() !== "y") { console.log("Annule."); return; }

    runWorkflow("build.yml", { tag: "nightly", prerelease: "true" });
    console.log("\nWorkflow lance.");
    console.log("   -> https://github.com/luoxthedev/nightcord-cleaned-source/actions");
}

async function releaseStable() {
    console.log("\nRelease Nightcord Stable");
    console.log(`   Version actuelle: v${currentVersion}\n`);

    console.log("Options:");
    console.log(`  1) Garder v${currentVersion}`);
    console.log(`  2) Patch (v${bump(currentVersion, "patch")})`);
    console.log(`  3) Minor (v${bump(currentVersion, "minor")})`);
    console.log(`  4) Major (v${bump(currentVersion, "major")})`);
    console.log("  5) Custom");

    const choice = await ask("\nChoix (1-5, defaut: 1): ");
    let newVersion;

    switch (choice) {
        case "2": newVersion = bump(currentVersion, "patch"); break;
        case "3": newVersion = bump(currentVersion, "minor"); break;
        case "4": newVersion = bump(currentVersion, "major"); break;
        case "5": newVersion = await ask("Version (sans v): "); break;
        default: newVersion = currentVersion;
    }

    if (!newVersion.startsWith("v")) newVersion = "v" + newVersion;

    console.log("\nResume:");
    console.log(`   Tag: ${newVersion}`);
    console.log('   Action: lance le workflow manuel "Release Stable"\n');

    const confirm = await ask("Confirmer ? (y/N) ");
    if (confirm.toLowerCase() !== "y") { console.log("Annule."); return; }

    runWorkflow("release.yml", { tag: newVersion });
    console.log(`\nWorkflow lance pour ${newVersion}.`);
    console.log("   -> https://github.com/luoxthedev/nightcord-cleaned-source/actions");
}

function bump(version, type) {
    const [major, minor, patch] = version.split(".").map(Number);
    switch (type) {
        case "major": return `${major + 1}.0.0`;
        case "minor": return `${major}.${minor + 1}.0`;
        case "patch": return `${major}.${minor}.${patch + 1}`;
    }
}

const mode = process.argv[2];
if (mode === "nightly") releaseNightly();
else if (mode === "stable") releaseStable();
else {
    console.log("Usage: node scripts/release.mjs <nightly|stable>");
    process.exit(1);
}
