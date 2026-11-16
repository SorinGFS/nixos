# Reference the portable wallpaper asset through its immutable store path.
{ ... }:
let
    uri = "file://${./wallpaper.jpg}";
in
{
    programs.dconf.profiles.user.databases = [ {
        settings = {
            "org/gnome/desktop/background" = {
                picture-options = "zoom";
                picture-uri = uri;
                picture-uri-dark = uri;
            };
        };
    } ];
}
