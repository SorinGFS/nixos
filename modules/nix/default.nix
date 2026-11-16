# Enable the Nix features used by the desktop and deduplicate store files.
{ ... }:
{
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.auto-optimise-store = true;
}
