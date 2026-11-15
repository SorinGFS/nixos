# Provision the writable default-profile extension store through VSCodium's CLI.
{ pkgs, ... }:
let
    baseline = pkgs.writeText "vscodium-extension-baseline.json" (builtins.toJSON (builtins.fromJSON (builtins.readFile ./extensions.json)));
    semver = "${pkgs.vscodium}/lib/vscode/resources/app/node_modules/semver";
    python = pkgs.vscode-extensions.ms-python.python;
    # Generate a checked VSIX from the Nixpkgs source; refresh it through Nixpkgs updates.
    pythonVsix = pkgs.runCommand "vscodium-python.vsix" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 - ${python.src} ${python.version} ${pkgs.stdenv.hostPlatform.parsed.cpu.name} "$out" <<'PY'
        import json
        import shutil
        import stat
        import sys
        import zipfile

        source, version, arch, output = sys.argv[1:]
        # Inspect archive metadata and ELF architecture without extracting any entries.
        with zipfile.ZipFile(source) as archive:
            manifest = json.loads(archive.read('extension/package.json'))
            assert (manifest['publisher'], manifest['name'], manifest['version']) == ('ms-python', 'python', version)
            pet = archive.getinfo('extension/python-env-tools/bin/pet')
            mode = pet.external_attr >> 16
            assert stat.S_ISREG(mode) and mode & 0o111
            header = archive.read(pet)[:20]
            machine = {'x86_64': 62, 'aarch64': 183}[arch]
            assert header[:6] == b'\x7fELF\x02\x01' and int.from_bytes(header[18:20], 'little') == machine
        shutil.copyfile(source, output)
        PY
    '';
in
{
    # The activation hook only queues the independent service; network failure cannot fail activation.
    system.userActivationScripts.vscodiumExtensions = {
        deps = [ "tmpfiles" ];
        text = ''
            ${pkgs.systemd}/bin/systemctl --user start --no-block vscodium-extensions.service || echo 'Could not queue VSCodium extension provisioning' >&2
        '';
    };

    # The activation hook starts this outside default.target's startup critical path.
    systemd.user.services.vscodium-extensions = {
        description = "Provision and update VSCodium extensions";
        after = [ "nixos-activation.service" "systemd-tmpfiles-setup.service" ];
        unitConfig.ConditionUser = "!@system";
        serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "15min";
            ExecStart = "${pkgs.nodejs}/bin/node ${./extensions.js} ${pkgs.vscodium}/bin/codium ${baseline} ${semver} ${pythonVsix} ${python.version}";
        };
    };

    # The CLI also updates legacy pinned extensions that the GUI auto-updater skips.
    systemd.user.timers.vscodium-extensions = {
        description = "Check for VSCodium extension updates daily";
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
        };
    };
}
