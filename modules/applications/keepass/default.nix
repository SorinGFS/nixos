# Provide the external KeePass launcher and optional GNOME integration.
{ pkgs, lib, ... }:
let
    # Restrict GTK2 lookup to KeePass and strip CR from the generated launcher.
    keepass-local = pkgs.writeShellScriptBin "keepass-local" (lib.replaceStrings [ "\r" ] [ "" ] ''
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [ pkgs.gtk2 pkgs.glib pkgs.pango pkgs.atk pkgs.gdk-pixbuf pkgs.cairo ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        # Make KeePass auto-type tools available without changing the system PATH.
        export PATH="${lib.makeBinPath [ pkgs.xdotool ]}:$PATH"
        exec ${pkgs.mono}/bin/mono "$HOME/.logins/KeePass.exe" "$@"
    '');
in
{
    imports = [ ./gnome ];
    environment.systemPackages = [ keepass-local ];
}
