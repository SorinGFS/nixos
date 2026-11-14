// Exercise provisioning with the editor's SemVer library and an isolated CLI fixture.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const semver = require(process.env.SEMVER_PATH);
const canonical = path.join(__dirname, 'extensions.json');

// Execute the real provisioner against disposable baseline and CLI fixtures.
function exercise(snapshots, options = {}) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vscodium-provision-test-'));
    try {
        const cli = path.join(dir, 'codium');
        const state = path.join(dir, 'state.json');
        const baseline = path.join(dir, 'baseline.json');
        // Prepare an installed-extension fixture for managed Python verification.
        const extension = path.join(dir, 'python-extension');
        fs.mkdirSync(path.join(extension, 'python-env-tools', 'bin'), { recursive: true });
        fs.writeFileSync(path.join(extension, 'package.json'), JSON.stringify(options.manifest || { publisher: 'ms-python', name: 'python', version: '2026.4.0' }));
        if (!options.missingPet) {
            const header = Buffer.alloc(20);
            Buffer.from([0x7f, 0x45, 0x4c, 0x46, 2, 1]).copy(header);
            header.writeUInt16LE(options.wrongPlatform ? 0 : { x64: 62, arm64: 183 }[process.arch], 18);
            fs.writeFileSync(path.join(extension, 'python-env-tools', 'bin', 'pet'), header, { mode: options.nonExecutable ? 0o600 : 0o700 });
        }
        fs.writeFileSync(baseline, JSON.stringify(Object.hasOwn(options, 'baseline') ? options.baseline : { 'example.extension': '1.2.3' }));
        fs.writeFileSync(cli, `#!/usr/bin/env node
const fs = require('node:fs');
const state = process.env.TEST_STATE;
const data = JSON.parse(fs.readFileSync(state));
const args = process.argv.slice(2);
data.calls.push(args);
if (args[0] === '--list-extensions') {
    if (data.failInventory) { fs.writeFileSync(state, JSON.stringify(data)); process.exit(2); }
    console.log(data.snapshots[Math.min(data.index++, data.snapshots.length - 1)] || '');
}
if (args[0] === '--locate-extension' && !data.failLocate) console.log(data.extension);
fs.writeFileSync(state, JSON.stringify(data));
if ((data.failUpdate && args[0] === '--update-extensions') || (data.failInstall && args.includes('--force')) || (data.failLocate && args[0] === '--locate-extension')) process.exit(2);
`, { mode: 0o700 });
        fs.writeFileSync(state, JSON.stringify({ snapshots, index: 0, calls: [], ...options, extension }));
        const managedArgs = options.managedArgs || (options.managed ? ['/fixture/python.vsix', '2026.4.0'] : []);
        const result = spawnSync(process.execPath, [path.join(__dirname, 'extensions.js'), cli, baseline, process.env.SEMVER_PATH, ...managedArgs], {
            encoding: 'utf8', env: { PATH: process.env.PATH, TEST_STATE: state },
        });
        return { result, calls: JSON.parse(fs.readFileSync(state)).calls };
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

// Validate the maintained source independently of synthetic version cases.
test('canonical baseline has unique IDs and valid minimum versions', () => {
    const baseline = JSON.parse(fs.readFileSync(canonical, 'utf8'));
    assert(baseline && typeof baseline === 'object' && !Array.isArray(baseline));
    const ids = new Set();
    for (const [id, version] of Object.entries(baseline)) {
        assert.match(id, /^[a-z0-9][a-z0-9-]*\.[a-z0-9][a-z0-9-]*$/i);
        assert(semver.valid(version), id);
        assert(!ids.has(id.toLowerCase()), id);
        ids.add(id.toLowerCase());
    }
});

// Compare numeric and prerelease versions and verify the native command boundary.
for (const [name, before, after, status, shouldInstall] of [
    ['missing', '', 'example.extension@1.2.3', 0, true],
    ['older', 'example.extension@1.2.2', 'example.extension@1.2.3', 0, false],
    ['equal', 'example.extension@1.2.3', 'example.extension@1.2.3', 0, false],
    ['numeric newer', 'example.extension@1.10.0', 'example.extension@1.10.0', 0, false],
    ['prerelease below', 'example.extension@1.2.3-rc.10', 'example.extension@1.2.3-rc.10', 1, false],
    ['prerelease above', 'example.extension@1.3.0-rc.2', 'example.extension@1.3.0-rc.2', 0, false],
    ['build metadata and case', 'Example.Extension@1.2.3+build.4', 'Example.Extension@1.2.3+build.4', 0, false],
    ['still missing', '', '', 1, true],
]) {
    test(name, () => {
        const { result, calls } = exercise([before, after]);
        assert.equal(result.status, status, result.stderr);
        assert.equal(calls.some(args => args[0] === '--install-extension'), shouldInstall);
        assert(calls.some(args => args[0] === '--update-extensions'));
        assert(!calls.flat().some(arg => arg === '--force' || arg.includes('@') || arg === '--uninstall-extension'));
    });
}

// Report failed checks and never mutate after an invalid input or inventory.
test('empty baseline is valid', () => {
    const { result, calls } = exercise(['', ''], { baseline: {} });
    assert.equal(result.status, 0, result.stderr);
    assert(!calls.some(args => args[0] === '--install-extension'));
});
// Reject invalid baselines before even inventorying the user's extensions.
for (const [name, baseline] of [
    ['array', []], ['null', null], ['number', 42], ['string', 'x'], ['boolean', true],
    ['missing publisher', { '.extension': '1.2.3' }],
    ['missing name', { 'example.': '1.2.3' }],
    ['extra dot', { 'example.foo.bar': '1.2.3' }],
    ['invalid characters', { 'example.bad_name': '1.2.3' }],
    ['leading hyphen', { '-example.extension': '1.2.3' }],
    ['case duplicate', { 'example.extension': '1.2.3', 'Example.Extension': '1.2.3' }],
    ['invalid minimum', { 'example.extension': 'invalid' }],
    ['numeric minimum', { 'example.extension': 123 }],
]) {
    test(`invalid baseline: ${name}`, () => {
        const { result, calls } = exercise([''], { baseline });
        assert.notEqual(result.status, 0);
        assert.deepEqual(calls, []);
    });
}
test('update failure is reported', () => {
    const { result } = exercise(['example.extension@1.2.3', 'example.extension@1.2.3'], { failUpdate: true });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /--update-extensions failed/);
});
test('inventory failure stops mutation', () => {
    const { result, calls } = exercise([''], { failInventory: true });
    assert.equal(result.status, 1);
    assert.deepEqual(calls, [['--list-extensions', '--show-versions']]);
});
test('malformed inventory stops mutation', () => {
    const { result, calls } = exercise(['invalid entry']);
    assert.equal(result.status, 1);
    assert.deepEqual(calls, [['--list-extensions', '--show-versions']]);
});

// Exercise the final managed reconciliation independently of the global updater.
test('managed Python is installed after global updates, not from the gallery', () => {
    const baseline = { 'ms-python.python': '2026.4.0', 'example.extension': '1.2.3' };
    const { result, calls } = exercise(['', 'ms-python.python@2026.4.0\nexample.extension@1.2.3'], { managed: true, baseline });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(calls, [
        ['--list-extensions', '--show-versions'],
        ['--install-extension', 'example.extension'],
        ['--update-extensions'],
        ['--install-extension', '/fixture/python.vsix', '--force', '--do-not-include-pack-dependencies'],
        ['--locate-extension', 'ms-python.python'],
        ['--list-extensions', '--show-versions'],
    ]);
});

test('managed Python replaces even a newer gallery version', () => {
    const baseline = { 'ms-python.python': '2026.4.0' };
    const { result, calls } = exercise(['ms-python.python@2027.1.0', 'ms-python.python@2026.4.0'], { managed: true, baseline });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(calls[2], ['--install-extension', '/fixture/python.vsix', '--force', '--do-not-include-pack-dependencies']);
});

// Every managed failure must be visible to the service.
for (const [name, options, diagnostic] of [
    ['install failure', { failInstall: true }, /--install-extension failed/],
    ['locate failure', { failLocate: true }, /--locate-extension failed/],
    ['missing PET', { missingPet: true }, /Managed Python verification failed/],
    ['non-executable PET', { nonExecutable: true }, /Managed Python verification failed/],
    ['wrong platform', { wrongPlatform: true }, /incorrect platform/],
    ['wrong ID', { manifest: { publisher: 'other', name: 'python', version: '2026.4.0' } }, /incorrect Python extension manifest/],
    ['wrong version', { manifest: { publisher: 'ms-python', name: 'python', version: '2027.1.0' } }, /incorrect Python extension manifest/],
]) {
    test(`managed Python ${name} fails closed`, () => {
        const { result } = exercise(['ms-python.python@2026.4.0', 'ms-python.python@2026.4.0'], { managed: true, baseline: { 'ms-python.python': '2026.4.0' }, ...options });
        assert.equal(result.status, 1);
        assert.match(result.stderr, diagnostic);
    });
}

// Reject partial and invalid managed configuration before invoking the native CLI.
for (const managedArgs of [['/fixture/python.vsix'], ['/fixture/python.vsix', 'invalid'], ['', '2026.4.0']]) {
    test(`invalid managed arguments: ${JSON.stringify(managedArgs)}`, () => {
        const { result, calls } = exercise([''], { managedArgs });
        assert.notEqual(result.status, 0);
        assert.deepEqual(calls, []);
    });
}
