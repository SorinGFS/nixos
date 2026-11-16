# Supply the Meslo Nerd Font used by the desktop and terminal.
{ pkgs, ... }:
{
    fonts.packages = [ pkgs.nerd-fonts.meslo-lg ];
}
