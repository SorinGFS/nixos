# Install Kitty and supply shared terminal preferences.
{ pkgs, ... }:
{
    imports = [
        ../../fonts/meslo.nix
        ./terminal-exec.nix
    ];
    environment.systemPackages = [ pkgs.kitty ];
    environment.etc."xdg/kitty/kitty.conf".text = builtins.concatStringsSep "\n" [
        "font_family MesloLGM Nerd Font Mono"
        "font_size 11.0"
        "cursor_shape beam"
        "copy_on_select clipboard"
        "confirm_os_window_close 0"
        "mouse_map right press ungrabbed paste_from_clipboard"
        ""
    ];
}
