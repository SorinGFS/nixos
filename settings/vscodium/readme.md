# VSCodium

Project-relative commands require the [system guide's command setup](../../system/readme.md#before-running-commands).

## Manage extensions

`settings/vscodium/extensions.json` defines baseline IDs and minimum versions; edits take effect after [project activation](../../system/readme.md#apply-native-configuration-edits). IDs removed from the baseline remain installed. A baseline extension removed in the GUI is reinstalled on the next check. Except for managed Python, the service installs missing IDs at the latest compatible version. It reports versions still below their minimums; compatible newer versions of other extensions remain eligible. VSCodium keeps its normal writable default-profile extension store and GUI update settings.

The user service runs at login, after a rebuild, and daily while the user manager is running. It asks the native CLI to update **all** installed extensions, including IDs outside the baseline and pinned extensions. Other extensions retain the native updater's behavior. The managed Python extension is then reinstalled from a complete platform VSIX, without automatically installing its extension-pack dependencies; debugpy and Python Environments are provisioned separately by the baseline. This VSIX installation pins Python for the GUI updater. The CLI update can briefly replace it, but each successful service run reconciles it back to the managed version and verifies its manifest and executable PET; a failed installation or verification fails the service. No editor restart is triggered.

The VSIX is generated from the Python extension source and version in Nixpkgs, with build-time checks for identity, version and platform PET. Nixpkgs is the source of truth: the managed version refreshes with a manual update of the local flake's locked inputs and rebuild. Failed checks appear in the user journal and retry on the next scheduled run, login, or rebuild; system activation proceeds independently.

```bash
systemctl --user status vscodium-extensions.service
journalctl --user -u vscodium-extensions.service
codium --list-extensions --show-versions
```

Official references: [VSCodium usage](https://github.com/VSCodium/vscodium/blob/master/docs/usage.md), [upstream editor extension CLI](https://code.visualstudio.com/docs/configure/command-line#_working-with-extensions).

## Change initial VSCodium preferences

Edits to `settings/vscodium/index.json` change initial preferences after [project activation](../../system/readme.md#apply-native-configuration-edits). Native user tmpfiles seeds `~/.config/VSCodium/User/settings.json` when missing as a writable user-owned file. Existing files and later GUI edits retain their values; source changes affect future seeds. The seed destination is fixed at this standard path, independent of `XDG_CONFIG_HOME`.

The seed selects the built-in Linux `bash` terminal profile and sets `terminal.integrated.rightClickBehavior` to `paste`. For an existing profile, **Preferences: Open User Settings (JSON)** in the command palette opens the user settings object. These two entries apply the preferences alongside existing settings:

```json
"terminal.integrated.defaultProfile.linux": "bash",
"terminal.integrated.rightClickBehavior": "paste"
```

A new integrated terminal loads the saved preferences. Workspace or profile settings can override user settings.

Official documentation: [editor settings](https://code.visualstudio.com/docs/configure/settings) and [terminal profiles](https://code.visualstudio.com/docs/terminal/profiles).

## Desktop launch environment

[Setup rationale](../../readme.md#setup-rationale) describes package and environment ownership.

Desktop-launch verification follows [project activation](../../system/readme.md#apply-native-configuration-edits) and a full VSCodium exit. It tests an extension invoking external Node after a dash launch, then repeats through Open With after another full exit. Integrated-terminal `node --version` verifies the terminal environment; extension-host Node selection requires its own test for each relevant extension.

## Validation

The system build checks the editor-bundled SemVer library with the helper tests before producing the managed VSIX. The [native checks](../../system/readme.md#native-checks) also build this guard. The tests use disposable CLI fixtures; they do not run the editor or provision extensions.

From the repository root, the helper test builds its VSCodium package dependency from the local flake at `/etc/nixos` and runs separately from system building and activation:

```bash
    SEMVER_PATH="$(nix build --no-link --print-out-paths "path:/etc/nixos#nixosConfigurations.$(uname -n).pkgs.vscodium")/lib/vscode/resources/app/node_modules/semver" node --test settings/vscodium/extensions.test.js
```
