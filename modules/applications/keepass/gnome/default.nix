# Supply the KeePass shortcut only when its launcher and GNOME are selected.
{ config, lib, ... }:
{
    imports = [ ../../../services/dconf ];
    config = lib.mkIf config.services.desktopManager.gnome.enable {
        programs.dconf.profiles.user.databases = [ {
            settings = (import ../../../services/dconf/group.nix { inherit lib; }) (builtins.fromJSON (builtins.readFile ./index.json));
        } ];
    };
}
