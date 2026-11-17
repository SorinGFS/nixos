# Restore favorites, enabled extensions and the explicitly ordered app grid.
{ lib, ... }:
let
    g = lib.gvariant;
    apps = [
        "mpv.desktop"
        "org.qbittorrent.qBittorrent.desktop"
        "org.gnome.Extensions.desktop"
        "virt-manager.desktop"
        "nvidia-settings.desktop"
        "xterm.desktop"
        "nixos-manual.desktop"
        "org.gnome.Settings.desktop"
    ];
    # GNOME expects each page as a dictionary of app IDs to variant position dictionaries.
    page = if apps == [ ] then g.mkEmptyArray (g.type.dictionaryEntryOf g.type.string g.type.variant) else g.mkArray (lib.imap0 (position: app:
        g.mkDictionaryEntry app (g.mkVariant (g.mkArray [
            (g.mkDictionaryEntry "position" (g.mkVariant (g.mkInt32 position)))
        ]))
    ) apps);
in
{
    imports = [ ./dash-to-panel ];
    programs.dconf.profiles.user.databases = [ {
        settings = {
            "org/gnome/shell" = {
                enabled-extensions = [ "dash-to-panel@jderose9.github.com" ];
                favorite-apps = [ "kitty.desktop" "org.gnome.Nautilus.desktop" "firefox-nightly.desktop" "codium.desktop" ];
                app-picker-layout = g.mkArray [ page ];
            };
            "org/gnome/shell/app-switcher" = {
                current-workspace-only = true;
            };
        };
    } ];
}
