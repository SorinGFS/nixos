# Supply the Files list-view defaults without retaining browsing history.
{ lib, pkgs, ... }:
{
    imports = [ ../../services/dconf ];
    environment.systemPackages = [ pkgs.nautilus ];
    xdg.mime.defaultApplications."inode/directory" = [ "nautilus.desktop" "org.gnome.Nautilus.desktop" ];
    programs.dconf.profiles.user.databases = [ {
        settings = (import ../../services/dconf/group.nix { inherit lib; }) (builtins.fromJSON (builtins.readFile ./index.json));
    } ];
}
