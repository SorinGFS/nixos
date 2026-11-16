# Enable local libvirt management without the libvirt SSH proxy.
{ ... }:
{
    imports = [ ./virt-manager.nix ];
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.sshProxy = false;
}
