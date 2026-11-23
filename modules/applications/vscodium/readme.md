# VSCodium

The module installs the editor and seeds `~/.config/VSCodium/User/settings.json` from [index.json](index.json) only when missing. The destination is fixed independently of `XDG_CONFIG_HOME`; existing writable settings and subsequent GUI edits remain user-owned. The seed selects Bash, right-click paste, and copy on selection for the integrated terminal, and Kitty for the external terminal. For an existing profile, open **Preferences: Open User Settings (JSON)** from the command palette and add these entries alongside existing settings:

```json
"terminal.integrated.defaultProfile.linux": "bash",
"terminal.integrated.rightClickBehavior": "paste",
"terminal.integrated.copyOnSelection": true,
"terminal.external.linuxExec": "kitty"
```

Workspace or profile settings can override user settings; a new integrated terminal loads saved preferences. See [editor settings](https://code.visualstudio.com/docs/configure/settings).

## Desktop launch environment

An overlay customizes the shared `pkgs.vscodium` used by installation and extension provisioning. Desktop entries and their actions add `--force-user-env`, while terminal CLI launches retain their inherited environment. The system supplies fnm and Bash integration, but Node versions remain user-managed. Integrated-terminal and extension-host Node selection are separate environments. Apply the change and fully exit VSCodium before reopening it. See [Nixpkgs overlays](https://nixos.org/manual/nixpkgs/stable/) and the [launcher environment explanation](../../../tutorial/nix.md#script-interpreters-and-launcher-environments).

## Extensions

The [extension guide](extensions/readme.md) describes the writable default-profile store, minimum baseline, global CLI updates and managed Python reconciliation. The editor package, generated VSIX and mutable profile have separate lifecycles; a system rollback does not rewind user data.
