# Enable local VM management without additional SSH proxy configuration.
{ ... }:
{
    virtualisation.libvirtd.enable = true;
    virtualisation.libvirtd.sshProxy = false;
    programs.virt-manager.enable = true;
}
