# Supply the Files list-view defaults without retaining browsing history.
{ lib, ... }:
{
    programs.dconf.profiles.user.databases = [ {
        settings = (import ../group.nix { inherit lib; }) (builtins.fromJSON (builtins.readFile ./index.json));
    } ];
}
