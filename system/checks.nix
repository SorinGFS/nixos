# Evaluate exported modules as NixOS consumers and check typed dconf serialization.
{ self, nixpkgs, system }:
let
    lib = nixpkgs.lib;
    # Keep fixtures machine-independent and evaluate only the requested module values.
    evaluate = modules: lib.nixosSystem {
        inherit system;
        modules = modules ++ [ { system.stateVersion = "26.05"; } ];
    };
    full = evaluate [ self.nixosModules.default ];
    desktop = evaluate [ self.nixosModules.desktop ];
    root = evaluate [ self.nixosModules.desktop self.nixosModules.root-administration ];
    power = evaluate [ self.nixosModules.desktop self.nixosModules.power ];
    vm = evaluate [ self.nixosModules.desktop self.nixosModules.virtualisation ];
    keepass = evaluate [ self.nixosModules.desktop self.nixosModules.keepass ];
    overridden = evaluate [
        self.nixosModules.default
        ({ pkgs, ... }: {
            time.timeZone = "UTC";
            i18n.defaultLocale = "en_GB.UTF-8";
            services.xserver.xkb.layout = "gb";
            console.keyMap = "uk";
            powerManagement.cpuFreqGovernor = "powersave";
            programs.firefox.package = pkgs.firefox;
        })
    ];
    # Locate a schema in the separate unlocked dconf databases.
    schema = configuration: name:
        (lib.findFirst (database: builtins.isAttrs database && database ? settings && builtins.hasAttr name database.settings) { settings = { }; }
            configuration.config.programs.dconf.profiles.user.databases).settings.${name} or { };
    # Detect the KeePass command independently of its shortcut registration and launcher.
    hasKeepass = configuration:
        ((schema configuration "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0").command or null) == "keepass-local --auto-type";
    # Read the registered shortcut paths without inferring registration from their definitions.
    shortcutList = configuration:
        (schema configuration "org/gnome/settings-daemon/plugins/media-keys").custom-keybindings or [ ];
    # Verify launcher installation without executing the external application.
    hasLauncher = configuration:
        lib.any (package: lib.getName package == "keepass-local") configuration.config.environment.systemPackages;
    g = lib.gvariant;
    # Serialize representative generated values with Nixpkgs' real dconf generator.
    serialize = value: lib.generators.toDconfINI { test.value = value; };
    desktopValues = schema full "org/gnome/desktop/session";
    inputValues = schema full "org/gnome/desktop/input-sources";
    shellValues = schema full "org/gnome/shell";
    panel = schema full "org/gnome/shell/extensions/dash-to-panel";
    expectedInput = g.mkArray [ (g.mkTuple [ "xkb" "us" ]) ];
    expectedExtent = g.mkArray [
        (g.mkDictionaryEntry "PLANK" (g.mkInt32 4))
        (g.mkDictionaryEntry "RIPPLE" (g.mkInt32 4))
        (g.mkDictionaryEntry "SIMPLE" (g.mkInt32 1))
    ];
in
{
    composition =
        assert full.config.services.displayManager.gdm.enable && full.config.services.desktopManager.gnome.enable;
        assert !full.config.security.sudo.enable && full.config.virtualisation.libvirtd.enable && full.config.programs.virt-manager.enable;
        assert full.config.systemd.sleep.settings.Sleep.AllowSuspend == false && full.config.powerManagement.cpuFreqGovernor == "performance";
        assert full.config.time.timeZone == "Europe/Bucharest" && full.config.i18n.defaultLocale == "en_US.UTF-8";
        assert full.config.services.xserver.xkb.layout == "us" && full.config.console.keyMap == "us";
        assert full.config.programs.firefox.enable && lib.hasInfix "defaultPref(" full.config.programs.firefox.autoConfig;
        assert !full.config.system.autoUpgrade.enable && hasKeepass full && hasLauncher full;
        assert shortcutList full == [ "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/" ];
        assert desktop.config.security.sudo.enable && !desktop.config.virtualisation.libvirtd.enable;
        assert !hasKeepass desktop && !hasLauncher desktop && shortcutList desktop == [ ];
        assert !root.config.security.sudo.enable && !hasKeepass root;
        assert power.config.systemd.sleep.settings.Sleep.AllowSuspend == false && power.config.powerManagement.cpuFreqGovernor == "performance";
        assert vm.config.virtualisation.libvirtd.enable && vm.config.programs.virt-manager.enable && !hasKeepass vm;
        assert hasKeepass keepass && hasLauncher keepass && !keepass.config.virtualisation.libvirtd.enable;
        assert overridden.config.time.timeZone == "UTC" && overridden.config.i18n.defaultLocale == "en_GB.UTF-8";
        assert overridden.config.services.xserver.xkb.layout == "gb" && overridden.config.console.keyMap == "uk";
        assert overridden.config.powerManagement.cpuFreqGovernor == "powersave";
        assert overridden.config.programs.firefox.package.outPath == overridden.pkgs.firefox.outPath;
        assert serialize desktopValues.idle-delay == serialize (g.mkUint32 0);
        assert serialize inputValues.sources == serialize expectedInput;
        assert serialize inputValues.xkb-options == serialize (g.mkEmptyArray g.type.string);
        assert serialize panel."animate-appicon-hover-animation-extent" == serialize expectedExtent;
        assert panel."trans-panel-opacity".type == g.type.double;
        assert serialize panel."trans-panel-opacity" == serialize (g.mkDouble 0.0);
        assert shellValues.app-picker-layout.type == "aa{sv}";
        assert builtins.isString (serialize shellValues.app-picker-layout);
        assert lib.any (package: package.outPath == full.pkgs.vscodium.outPath) full.config.environment.systemPackages;
        assert lib.hasInfix "${full.pkgs.vscodium}/bin/codium" full.config.systemd.user.services.vscodium-extensions.serviceConfig.ExecStart;
        assert builtins.deepSeq (map (item: item.drvPath) full.pkgs.vscodium.desktopItems) true;
        # The service command references the checked VSIX and therefore builds the SemVer guard.
        full.pkgs.writeText "desktop-composition-check" full.config.systemd.user.services.vscodium-extensions.serviceConfig.ExecStart;

    # Build the actual profiles and compiled databases through the upstream dconf module.
    dconf = full.pkgs.runCommand "desktop-dconf-check" { } ''
        test -f ${full.config.environment.etc.dconf.source}/profile/user
        touch "$out"
    '';
}
