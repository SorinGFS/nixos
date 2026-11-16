# Compose the complete desktop preset and its optional policies.
{ ... }:
{
    imports = [
        ./desktop
        ./power
        ./virtualisation/libvirt
        ./applications/keepass
    ];
}
