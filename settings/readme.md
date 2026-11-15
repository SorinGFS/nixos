# Native settings defaults

[default.nix](default.nix) imports nine source-backed concerns: desktop, files, shell, dash-to-panel, wallpaper, firefox, gh, vlc, and vscodium. The optional KeePass policy imports its own [shortcut source](keepass/index.json). [group.nix](group.nix) groups dconf key paths into schema sections; individual modules retain responsibility for their value types.

Project-relative commands use the [system guide's command setup](../system/readme.md#before-running-commands). Each concern's source JSON supplies defaults after [project activation](../system/readme.md#apply-native-configuration-edits). GNOME and Firefox defaults are unlocked; existing user preferences win. GH, VLC, and VSCodium seed missing user files; existing files remain user-owned. Individual guides appear in the [task index](../readme.md).

## Source adapters and mutable preferences

JSON is authored data, not a Nix expression: modules parse it with `builtins.fromJSON` and adapt values to each consumer's format. [group.nix](group.nix) groups dconf paths; individual modules provide the required GVariant types. Dash to Panel's object-valued layout maps, for example, become strings for the extension. JSON syntax validation alone cannot establish those type and schema contracts.

The [data and adapter explanation](../tutorial/nix.md#data-desktop-presets-and-host-composition) describes why generated configuration does not require converting authored JSON into Nix syntax. [Typed Nix values](../tutorial/readme.md#values-lists-and-attribute-sets) provide the language foundation; GNOME schema compatibility remains a separate concern.

Unlocked defaults and missing-file seeds have different update behavior. Dconf and Firefox defaults remain below user overrides; GH, VLC, and VSCodium seeds initialize absent writable files without replacing existing preferences. Generated store artifacts and user-owned files therefore have separate lifecycles, as explained in [immutable results and writable application data](../tutorial/nix.md#immutable-results-and-writable-application-data).
