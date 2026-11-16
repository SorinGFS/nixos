# Compose shared desktop applications, services, shell, and security.
{ ... }:
{
    imports = [
        ./gnome
        ../nix
        ../services/networkmanager.nix
        ../services/pipewire.nix
        ../services/flatpak.nix
        ../security/sudo.nix
        ../security/gnupg
        ../shell/bash
        ../applications/firefox
        ../applications/files
        ../applications/gh
        ../applications/kitty
        ../applications/vscodium
        ../applications/packages.nix
    ];
}
