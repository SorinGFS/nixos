# Supply the KeePass shortcut only when its launcher and GNOME are selected.
{ config, lib, ... }:
{
    imports = [ ../../../services/dconf ];
    config = lib.mkIf config.services.desktopManager.gnome.enable {
        programs.dconf.profiles.user.databases = [ {
            settings = {
                "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
                    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
                ];
                "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
                    binding = "<Control><Alt>a";
                    command = "keepass-local --auto-type";
                    name = "KeePass Auto-Type";
                };
            };
        } ];
    };
}
