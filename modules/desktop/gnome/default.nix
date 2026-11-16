# Enable GNOME services and supply explicitly typed desktop preferences.
{ lib, pkgs, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    group = import ../../services/dconf/group.nix { inherit lib; };
    g = lib.gvariant;
    typed = values // {
        "org/gnome/desktop/session/idle-delay" = g.mkUint32 values."org/gnome/desktop/session/idle-delay";
        "org/gnome/desktop/privacy/old-files-age" = g.mkUint32 values."org/gnome/desktop/privacy/old-files-age";
        "org/gnome/desktop/input-sources/sources" = if values."org/gnome/desktop/input-sources/sources" == [ ] then g.mkEmptyArray (g.type.tupleOf [ g.type.string g.type.string ]) else g.mkArray (map g.mkTuple values."org/gnome/desktop/input-sources/sources");
        "org/gnome/desktop/input-sources/xkb-options" = if values."org/gnome/desktop/input-sources/xkb-options" == [ ] then g.mkEmptyArray g.type.string else g.mkArray values."org/gnome/desktop/input-sources/xkb-options";
    };
in
{
    imports = [
        ./shell
        ./wallpaper
        ../../fonts/meslo.nix
        ../../services/dconf
    ];

    # Enable GNOME and retain only its selected core services.
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
    services.gnome.core-apps.enable = false;
    environment.gnome.excludePackages = [ pkgs.gnome-tour ];
    services.gnome.gnome-online-accounts.enable = false;
    services.geoclue2.enable = false;
    services.gnome.localsearch.enable = false;
    services.gnome.tinysparql.enable = false;
    services.gnome.gnome-remote-desktop.enable = false;
    services.gnome.gnome-user-share.enable = false;
    services.gnome.rygel.enable = false;
    services.dleyna.enable = false;
    services.gnome.gnome-initial-setup.enable = false;
    services.gnome.gnome-browser-connector.enable = false;

    # Apply typed, unlocked user defaults.
    programs.dconf.profiles.user.databases = [ { settings = group typed; } ];
}
