# Provide the Firefox Nightly launcher with application-scoped X11 settings.
{ desktopInputs, lib, pkgs, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
in
{
    programs.firefox = {
        enable = true;
        # Supply unlocked preferences without writing user profiles.
        autoConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value:
            "defaultPref(${builtins.toJSON name}, ${builtins.toJSON value});"
        ) values);
        # Extend the native launcher rather than changing the desktop session environment.
        package = lib.mkDefault (desktopInputs.firefox-nightly.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin.overrideAttrs (old: {
            makeWrapperArgs = old.makeWrapperArgs ++ [
                "--unset" "WAYLAND_DISPLAY"
                "--set" "GDK_BACKEND" "x11"
                "--set" "MOZ_ENABLE_WAYLAND" "0"
            ];
        }));
    };
}
