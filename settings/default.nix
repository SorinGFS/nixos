# Assemble focused system and initial user defaults from flat concern files.
{ ... }:
{
    imports = [ ./desktop ./files ./shell ./dash-to-panel ./wallpaper ./firefox ./gh ./vlc ./vscodium ];
}
