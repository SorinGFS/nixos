# VSCodium extensions

[index.json](index.json) defines baseline extension IDs and minimum versions, not an uninstall list. A removed baseline ID remains installed; a missing non-Python ID is installed at the latest compatible version on the next service run. Minimum versions are not exact pins; compatible newer versions remain eligible. The writable default-profile extension store and GUI updater remain user-owned.

At login, after activation and daily while the user manager runs, the user service asks the native CLI to update all installed extensions, including pinned and non-baseline IDs. It then reinstalls managed Python from a complete Nixpkgs-source VSIX and verifies its manifest and executable PET. The VSIX installation pins Python for the GUI updater; the CLI can briefly replace it, but each successful run reconciles it back. Python pack dependencies are not automatically installed; debugpy and Python Environments have separate baseline entries. The service checks all minimum versions and reports failures. It does not restart the editor.

The VSIX build checks source identity, version and platform PET; invalid input fails the build. Runtime network or provisioning failures fail the service, appear in the user journal, and retry on a later scheduled run, login or activation. Activation only queues the independent service, so provisioning failure does not fail activation. The service's `ConditionUser = "!@system"` excludes system users such as the greeter. Refreshing the local flake inputs updates the Nixpkgs source on a subsequent build. Rollback does not rewind mutable extension or profile data.

```bash
systemctl --user status vscodium-extensions.service
```

```bash
journalctl --user -u vscodium-extensions.service
```

```bash
codium --list-extensions --show-versions
```

See [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/) and [editor extension CLI](https://code.visualstudio.com/docs/configure/command-line#_working-with-extensions).
