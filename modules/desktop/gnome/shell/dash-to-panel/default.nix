# Install Dash to Panel and configure the first-monitor layout and typed animation extents.
{ lib, pkgs, ... }:
let
    g = lib.gvariant;
    extents = { PLANK = 4; RIPPLE = 4; SIMPLE = 1; };
in
{
    environment.systemPackages = [
        (pkgs.gnomeExtensions.dash-to-panel.overrideAttrs (old: {
            # Keep Quick Settings indicators stacked on vertical panels.
            postPatch = (old.postPatch or "") + ''
                substituteInPlace panel.js --replace-fail 'isVertical = isVertical && natWidth > this.geom.innerSize' 'isVertical = isVertical && (actor == this.statusArea.quickSettings || natWidth > this.geom.innerSize)'
            '';
        }))
    ];
    programs.dconf.profiles.user.databases = [ {
        settings = {
            "org/gnome/shell/extensions/dash-to-panel" = {
                animate-appicon-hover = false;
                # Preserve the dictionary's element type even when all animation extents are removed.
                animate-appicon-hover-animation-extent = if extents == { }
                    then g.mkEmptyArray (g.type.dictionaryEntryOf g.type.string g.type.int32)
                    else g.mkArray (lib.mapAttrsToList (name: number: g.mkDictionaryEntry name (g.mkInt32 number)) extents);
                appicon-margin = g.mkInt32 0;
                appicon-padding = g.mkInt32 12;
                appicon-style = "NORMAL";
                dot-color-1 = "#ff0075";
                dot-color-dominant = false;
                dot-color-override = true;
                dot-color-unfocused-different = false;
                dot-position = "RIGHT";
                dot-size = g.mkInt32 1;
                dot-style-focused = "SOLID";
                dot-style-unfocused = "SQUARES";
                focus-highlight-color = "#e01b24";
                focus-highlight-dominant = true;
                hotkeys-overlay-combo = "TEMPORARILY";
                isolate-workspaces = true;
                leftbox-padding = g.mkInt32 (-1);
                # These five extension settings store JSON strings, not GVariant dictionaries.
                panel-anchors = builtins.toJSON { "0" = "MIDDLE"; };
                panel-element-positions = builtins.toJSON {
                    "0" = [
                        { element = "showAppsButton"; visible = true; position = "stackedTL"; }
                        { element = "taskbar"; visible = true; position = "stackedTL"; }
                        { element = "activitiesButton"; visible = false; position = "stackedTL"; }
                        { element = "leftBox"; visible = false; position = "stackedTL"; }
                        { element = "centerBox"; visible = false; position = "stackedTL"; }
                        { element = "rightBox"; visible = false; position = "stackedTL"; }
                        { element = "systemMenu"; visible = true; position = "stackedBR"; }
                        { element = "dateMenu"; visible = true; position = "stackedBR"; }
                        { element = "desktopButton"; visible = true; position = "stackedBR"; }
                    ];
                };
                panel-lengths = builtins.toJSON { "0" = 100; };
                panel-positions = builtins.toJSON { "0" = "RIGHT"; };
                panel-side-margins = g.mkInt32 0;
                panel-sizes = builtins.toJSON { "0" = 64; };
                panel-top-bottom-margins = g.mkInt32 0;
                status-icon-padding = g.mkInt32 4;
                stockgs-panelbtn-click-only = true;
                trans-bg-color = "#a51d2d";
                trans-panel-opacity = g.mkDouble 0.0;
                trans-use-custom-bg = false;
                trans-use-custom-opacity = true;
                trans-use-dynamic-opacity = true;
                tray-padding = g.mkInt32 0;
                tray-size = g.mkInt32 0;
                window-preview-title-position = "TOP";
            };
        };
    } ];
}
