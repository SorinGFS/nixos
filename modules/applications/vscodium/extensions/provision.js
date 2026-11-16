// Maintain a minimum extension baseline using VSCodium's writable default profile.
const { spawnSync } = require('node:child_process');
const { readFileSync, statSync, accessSync, constants } = require('node:fs');
const path = require('node:path');
const [codium, baselinePath, semverPath, pythonVsix, pythonVersion] = process.argv.slice(2);
const semver = require(semverPath);
const baseline = JSON.parse(readFileSync(baselinePath, 'utf8'));
let failed = false;

// Reject incomplete managed configuration before touching the extension store.
if ((pythonVsix !== undefined || pythonVersion !== undefined) && (!pythonVsix || !pythonVersion || !semver.valid(pythonVersion))) {
    throw new Error('Invalid managed Python VSIX path or version');
}

// Reject malformed source entries before making any extension changes.
if (baseline === null || typeof baseline !== 'object' || Array.isArray(baseline)) {
    throw new Error('Invalid VSCodium extension baseline: expected an object');
}
const ids = new Set();
for (const [id, version] of Object.entries(baseline)) {
    if (!/^[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9-]*$/i.test(id) || !semver.valid(version) || ids.has(id.toLowerCase())) {
        throw new Error(`Invalid VSCodium extension baseline entry: ${id}@${version}`);
    }
    ids.add(id.toLowerCase());
}

// Invoke only the native extension manager, retaining its diagnostics for the journal.
function run(args, capture = false) {
    const result = spawnSync(codium, args, { encoding: 'utf8', stdio: capture ? ['ignore', 'pipe', 'inherit'] : 'inherit' });
    if (result.error || result.status !== 0) {
        console.error(`VSCodium ${args[0]} failed: ${result.error || `exit ${result.status}`}`);
        failed = true;
        return null;
    }
    return capture ? result.stdout : '';
}

// Treat an unreadable or malformed inventory as unknown, never as an empty store.
function inventory() {
    const output = run(['--list-extensions', '--show-versions'], true);
    if (output === null) return null;
    const versions = new Map();
    for (const line of output.split(/\r?\n/).filter(Boolean)) {
        const match = /^([^@\s]+)@([^@\s]+)$/.exec(line);
        if (!match || !semver.valid(match[2])) {
            console.error(`Invalid VSCodium extension inventory entry: ${line}`);
            failed = true;
            return null;
        }
        versions.set(match[1].toLowerCase(), match[2]);
    }
    return versions;
}

// Install missing IDs without version pins, then ask the native manager for updates.
const before = inventory();
if (before) {
    const missing = Object.keys(baseline).filter(id => !(pythonVsix && id.toLowerCase() === 'ms-python.python') && !before.has(id.toLowerCase()));
    if (missing.length) run(missing.flatMap(id => ['--install-extension', id]));
    run(['--update-extensions']);
    // Reconcile Python last: the global updater can replace even pinned VSIX installations.
    if (pythonVsix && run(['--install-extension', pythonVsix, '--force', '--do-not-include-pack-dependencies']) !== null) {
        const location = run(['--locate-extension', 'ms-python.python'], true);
        if (location !== null) {
            try {
                const lines = location.trim().split(/\r?\n/);
                if (lines.length !== 1 || !path.isAbsolute(lines[0])) throw new Error('invalid extension location');
                const manifest = JSON.parse(readFileSync(path.join(lines[0], 'package.json'), 'utf8'));
                if (manifest.publisher !== 'ms-python' || manifest.name !== 'python' || manifest.version !== pythonVersion) throw new Error('incorrect Python extension manifest');
                const pet = path.join(lines[0], 'python-env-tools/bin/pet');
                if (!statSync(pet).isFile()) throw new Error('PET is not a regular file');
                accessSync(pet, constants.R_OK | constants.X_OK);
                const header = readFileSync(pet).subarray(0, 20);
                const machine = { x64: 62, arm64: 183 }[process.arch];
                if (!machine || header.length < 20 || !header.subarray(0, 6).equals(Buffer.from([0x7f, 0x45, 0x4c, 0x46, 2, 1])) || header.readUInt16LE(18) !== machine) throw new Error('PET has an incorrect platform');
            } catch (error) {
                console.error(`Managed Python verification failed: ${error.message}`);
                failed = true;
            }
        }
    }
    // CLI update errors may still return success, so verify every minimum afterwards.
    const after = inventory();
    if (after) {
        for (const [id, minimum] of Object.entries(baseline)) {
            const installed = after.get(id.toLowerCase());
            if (!installed || semver.lt(installed, minimum)) {
                console.error(`VSCodium extension ${id}: installed ${installed || 'missing'}, minimum ${minimum}`);
                failed = true;
            }
        }
    }
}
if (failed) process.exitCode = 1;
