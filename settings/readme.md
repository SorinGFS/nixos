# Native settings defaults

[default.nix](default.nix) imports the nine source-backed concerns: desktop, files, shell, dash-to-panel, wallpaper, firefox, gh, vlc, and vscodium. [group.nix](group.nix) groups dconf key paths into schema sections; individual modules retain responsibility for their value types.

Project-relative commands use the [system guide's command setup](../system/readme.md#before-running-commands). Each concern's source JSON supplies defaults after [project activation](../system/readme.md#apply-native-configuration-edits). GNOME and Firefox defaults are unlocked; existing user preferences win. GH, VLC, and VSCodium seed missing user files; existing files remain user-owned. Individual guides appear in the [task index](../readme.md).

## Validation

The following project-root command parses the nine settings JSON files:

```bash
node -e 'for (const p of ["desktop", "files", "shell", "dash-to-panel", "wallpaper", "firefox", "gh", "vlc", "vscodium"]) JSON.parse(require("fs").readFileSync(`settings/${p}/index.json`))'
```

This checks JSON syntax. Module types require [full NixOS evaluation](../system/readme.md#apply-native-configuration-edits), and application behavior requires runtime verification. The extension helper test is described in [VSCodium validation](vscodium/readme.md#validation).
