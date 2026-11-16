# Dconf

[default.nix](default.nix) enables the shared dconf backend with `programs.dconf.enable`; GNOME, Files and KeePass import it for their preferences. See [NixOS configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).

[group.nix](group.nix) is a pure curried function, not a NixOS module. It takes `lib` and then values, groups full key paths by schema, and turns empty plain lists into string arrays. Callers supply other GVariant types explicitly. The helper groups values; callers parse authored JSON with `builtins.fromJSON` and adapt it to the consumer's format. Parsing alone cannot prove schema compatibility. See [Nix builtins](https://nix.dev/manual/nix/2.34/language/builtins.html) and the [data adapter explanation](../../../tutorial/nix.md#data-desktop-presets-and-host-composition).

[GNOME](../../desktop/gnome/readme.md) and [Firefox](../../applications/firefox/readme.md) defaults are unlocked and existing user overrides win. [GitHub CLI](../../applications/gh/readme.md) and [VSCodium](../../applications/vscodium/readme.md) instead seed missing writable files once; existing files remain user-owned. Generated immutable results and writable preferences have [different lifecycles](../../../tutorial/nix.md#immutable-results-and-writable-application-data).
