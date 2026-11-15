# Keep the desktop awake and prefer performance without changing thermal safeguards.
{ lib, ... }:
{
    systemd.sleep.settings.Sleep = {
        AllowSuspend = false;
        AllowHibernation = false;
        AllowHybridSleep = false;
        AllowSuspendThenHibernate = false;
    };
    powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
    services.power-profiles-daemon.enable = false;
}
