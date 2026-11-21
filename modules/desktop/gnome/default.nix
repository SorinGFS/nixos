# Enable GNOME services and supply explicitly typed desktop preferences.
{ lib, pkgs, ... }:
let
    g = lib.gvariant;
    sources = [ [ "xkb" "us" ] ];
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

    # Prevent missing XDG folders from being remapped to $HOME, which apps
    # could mistake for the directory intended for public sharing.
    environment.etc."xdg/user-dirs.conf".text = "enabled=False\n";

    # Apply typed, unlocked user defaults.
    programs.dconf.profiles.user.databases = [ {
        settings = {
            "org/gnome/desktop/interface" = {
                accent-color = "blue";
                clock-show-date = true;
                clock-show-seconds = false;
                clock-show-weekday = false;
                color-scheme = "prefer-dark";
                enable-animations = false;
                monospace-font-name = "MesloLGM Nerd Font Mono 11";
            };
            "org/gnome/desktop/session".idle-delay = g.mkUint32 0;
            "org/gnome/desktop/screensaver".lock-enabled = false;
            "org/gnome/desktop/input-sources" = {
                sources = if sources == [ ] then g.mkEmptyArray (g.type.tupleOf [ g.type.string g.type.string ]) else g.mkArray (map g.mkTuple sources);
                xkb-options = g.mkEmptyArray g.type.string;
            };
            "org/gnome/desktop/peripherals/mouse".accel-profile = "flat";
            "org/gnome/desktop/peripherals/touchpad".two-finger-scrolling-enabled = true;
            "org/gnome/desktop/privacy" = {
                old-files-age = g.mkUint32 0;
                remember-app-usage = false;
                remember-recent-files = false;
                remove-old-trash-files = true;
            };
            "org/gnome/desktop/search-providers" = {
                disable-external = true;
                sort-order = [ "org.gnome.Settings.desktop" "org.gnome.Contacts.desktop" "org.gnome.Nautilus.desktop" ];
            };
            "org/gnome/gnome-session".logout-prompt = false;
            "org/gnome/system/location".enabled = false;
            "org/gnome/settings-daemon/plugins/color" = {
                night-light-enabled = false;
                night-light-schedule-automatic = false;
                night-light-temperature = g.mkUint32 4459;
            };
            "org/gnome/settings-daemon/plugins/power" = {
                idle-dim = true;
                sleep-inactive-ac-type = "nothing";
                sleep-inactive-battery-type = "suspend";
            };
            "org/gnome/desktop/notifications" = {
                show-banners = false;
                show-in-lock-screen = false;
            };
        };
    } ];
}
