# Select Kitty for XDG terminal-exec callers.
{ ... }:
{
    xdg.terminal-exec = {
        enable = true;
        settings.default = [ "kitty.desktop" ];
        settings.GNOME = [ "kitty.desktop" ];
    };
}
