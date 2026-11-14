# Provide the Firefox Nightly launcher with application-scoped X11 settings.
{ firefox-nightly, pkgs, ... }:
{
    programs.firefox = {
        enable = true;
        # Extend the native launcher rather than changing the desktop session environment.
        package = firefox-nightly.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin.overrideAttrs (old: {
            makeWrapperArgs = old.makeWrapperArgs ++ [
                "--unset" "WAYLAND_DISPLAY"
                "--set" "GDK_BACKEND" "x11"
                "--set" "MOZ_ENABLE_WAYLAND" "0"
            ];
        });
    };
}
