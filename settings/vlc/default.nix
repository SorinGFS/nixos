# Seed missing VLC preferences without replacing later user edits.
{ lib, ... }:
let
    values = builtins.fromJSON (builtins.readFile ./index.json);
    # Render VLC's key=value format before escaping the tmpfiles argument syntax.
    content = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name}=${toString value}") values) + "\n";
    argument = lib.replaceStrings [ "\\" "\n" "%" ] [ "\\\\" "\\n" "%%" ] content;
in
{
    # The ':' mode prefix preserves permissions when the file already exists.
    systemd.user.tmpfiles.rules = [ "f %h/.config/vlc/vlcrc :0644 - - - ${argument}" ];
}
