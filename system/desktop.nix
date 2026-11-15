# Compose the shared desktop without the separately selectable policies.
{ ... }:
{
    imports = [ ./core.nix ./firefox.nix ./desktop-features.nix ../settings ];
}
