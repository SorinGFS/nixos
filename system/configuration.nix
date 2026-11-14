# Compose the desktop independently of the machine-specific storage profile.
{ ... }:
{
    imports = [
        ./core.nix
        ./firefox.nix
        ./desktop-features.nix
        ../settings
    ];
}
