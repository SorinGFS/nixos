# Export reusable desktop compositions and independently selectable policies.
desktopInputs:
{
    nixosModules = {
        desktop = {
            imports = [ ./desktop ];
            _module.args.desktopInputs = desktopInputs;
        };
        default = {
            imports = [ ./default.nix ];
            _module.args.desktopInputs = desktopInputs;
        };
        power = import ./power;
        virtualisation = import ./virtualisation/libvirt;
        keepass = import ./applications/keepass;
    };
}
