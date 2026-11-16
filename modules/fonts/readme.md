# Fonts

[meslo.nix](meslo.nix) sets `fonts.packages` to supply `nerd-fonts.meslo-lg` to both [GNOME](../desktop/gnome/readme.md) and [Kitty](../applications/kitty/readme.md); importing the same module path lets NixOS deduplicate it. See [NixOS configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).
