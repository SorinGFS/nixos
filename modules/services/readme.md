# Services

The desktop composition selects the service modules below. Dependent modules also import dconf as a shared capability. Definitions participate in normal NixOS module merging; see [configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).

| Source | Owned setting |
| --- | --- |
| [networkmanager.nix](networkmanager.nix) | Enables NetworkManager. |
| [pipewire.nix](pipewire.nix) | Enables PipeWire. |
| [flatpak.nix](flatpak.nix) | Enables Flatpak. |
| [dconf/default.nix](dconf/default.nix) | Enables the dconf preference backend. |

## Guides

- [Dconf](dconf/readme.md)
