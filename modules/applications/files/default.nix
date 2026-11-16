# Supply the Files list-view defaults without retaining browsing history.
{ pkgs, ... }:
{
    imports = [ ../../services/dconf ];
    environment.systemPackages = [ pkgs.nautilus ];
    xdg.mime.defaultApplications."inode/directory" = [ "nautilus.desktop" "org.gnome.Nautilus.desktop" ];
    programs.dconf.profiles.user.databases = [ {
        settings = {
            "org/gnome/nautilus/preferences" = {
                default-folder-viewer = "list-view";
                date-time-format = "detailed";
            };
            "org/gnome/nautilus/list-view" = {
                default-column-order = [
                    "name" "type" "permissions" "owner" "group" "date_accessed"
                    "date_created" "date_modified" "size" "recency" "detailed_type"
                ];
                default-visible-columns = [ "name" "permissions" "owner" "group" "date_modified" "size" ];
                use-tree-view = true;
            };
        };
    } ];
}
