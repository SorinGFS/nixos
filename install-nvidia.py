#!/usr/bin/env python3
"""Resolve NVIDIA hardware against pinned target packages and NVIDIA's published metadata."""
import html.parser
import json
import os
from pathlib import Path
import re
import subprocess
import sys

EXPR = r'''let
    f = builtins.getFlake ("path:" + builtins.getEnv "INSTALL_FLAKE_STAGE");
    n = f.inputs.nixpkgs.lib.nixosSystem {
        system = builtins.currentSystem;
        modules = [ f.inputs.desktop.nixosModules.default { nixpkgs.config.allowUnfree = true; } ];
    };
    inherit (n.pkgs) lib;
    packages = n.config.boot.kernelPackages.nvidiaPackages;
    names = builtins.filter (name: (name == "stable" || builtins.match "legacy_[0-9]+" name != null) && lib.isDerivation packages.${name}) (builtins.attrNames packages);
in assert n.options.hardware.nvidia ? branch; {
    system = n.pkgs.stdenv.hostPlatform.system;
    candidates = map (name: let p = packages.${name}; in {
        branch = name; version = p.version; open = (p.open or null) != null;
        broken = p.meta.broken or false;
    }) names;
}'''


# Fail rather than infer support from incomplete external metadata.
def fail(message):
    raise ValueError(message)


# Read Linux PCI sysfs numeric identifiers from the selected device root.
def probe(root="/sys/bus/pci/devices"):
    devices = []
    # Check each PCI function without requiring a model-name database.
    for path in sorted(Path(root).iterdir()):
        pci_class = (path / "class").read_text().strip()
        vendor = (path / "vendor").read_text().strip()
        if not re.fullmatch(r"0x[0-9a-fA-F]{6}", pci_class) or not re.fullmatch(r"0x[0-9a-fA-F]{4}", vendor):
            fail("Malformed PCI sysfs class or vendor")
        if pci_class[2:4].lower() != "03" or vendor[2:].lower() != "10de":
            continue
        ids = [(path / name).read_text().strip() for name in ("device", "subsystem_vendor", "subsystem_device")]
        if not all(re.fullmatch(r"0x[0-9a-fA-F]{4}", value) for value in ids):
            fail("Malformed NVIDIA PCI sysfs identifiers")
        devices.append(dict(zip(("device", "subvendor", "subdevice"), (value[2:].lower() for value in ids))))
    if not devices:
        fail("No NVIDIA display-class GPU detected")
    return devices


# Fetch public metadata only; retain status separately so a missing version document is skippable.
def fetch(url):
    p = subprocess.run(["curl", "-sS", "-L", "--connect-timeout", "10", "--max-time", "30", "-w", "\\n%{http_code}", url], capture_output=True, text=True)
    if p.returncode or "\n" not in p.stdout:
        fail("Metadata lookup failed: " + url + (": " + p.stderr.strip() if p.stderr.strip() else ""))
    body, status = p.stdout.rsplit("\n", 1)
    if status == "404":
        return None
    if status != "200":
        fail("Metadata HTTP failure " + status + ": " + url)
    return body


# Extract only the first table following the exact current-GPU heading.
class CurrentTable(html.parser.HTMLParser):
    # Track the current heading, table and cell state across HTML events.
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.heading = False
        self.ready = False
        self.table = False
        self.done = False
        self.cell = None
        self.row = None
        self.rows = []
        self.text = ""

    # Enter the current table and capture its rows and cells.
    def handle_starttag(self, tag, attrs):
        if tag == "h3" and not self.done:
            if self.ready:
                fail("Current GPU table missing")
            self.heading = True
            self.text = ""
        elif tag == "table" and self.ready and not self.done:
            self.table = True
            self.ready = False
        elif self.table and tag == "tr":
            self.row = []
        elif self.table and tag in ("td", "th"):
            if self.row is None or self.cell is not None:
                fail("Malformed current GPU table")
            self.cell = ""

    # Preserve text nested in heading or cell markup, including footnotes.
    def handle_data(self, data):
        if self.heading:
            self.text += data
        if self.cell is not None:
            self.cell += data

    # Finish rows and stop at the end of the current table.
    def handle_endtag(self, tag):
        if tag == "h3" and self.heading:
            self.heading = False
            if " ".join(self.text.split()) == "Current NVIDIA GPUs":
                self.ready = True
        elif self.table and tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join(self.cell.split()))
            self.cell = None
        elif self.table and tag == "tr":
            if self.row is None or self.cell is not None:
                fail("Malformed current GPU row")
            if self.row:
                self.rows.append(self.row)
            self.row = None
        elif self.table and tag == "table":
            if self.row is not None or self.cell is not None:
                fail("Malformed current GPU table")
            self.table = False
            self.done = True


# Validate every current row and match generic or subsystem-specific PCI entries.
def supported(body, devices):
    parser = CurrentTable()
    parser.feed(body)
    parser.close()
    if not parser.done or len(parser.rows) < 2 or len(parser.rows[0]) != 3 or parser.rows[0][0] != "NVIDIA GPU product" or not re.fullmatch(r"Device PCI ID\s*\*?", parser.rows[0][1]) or parser.rows[0][2] != "VDPAU features":
        fail("Malformed or missing current NVIDIA GPU table")
    entries = []
    # Reject malformed rows rather than interpreting an incomplete table as support.
    for row in parser.rows[1:]:
        if len(row) != 3 or not row[0] or not re.fullmatch(r"[0-9a-fA-F]{4}(?:\s+[0-9a-fA-F]{4}\s+[0-9a-fA-F]{4})?", row[1]):
            fail("Malformed current NVIDIA GPU table row")
        entries.append(row[1].lower().split())
    return all(any(e[0] == d["device"] and (len(e) == 1 or e[1:] == [d["subvendor"], d["subdevice"]]) for e in entries) for d in devices)


# Select the strongest matching vendor record without treating missing flags as prohibitions.
def vendor_records(data, devices):
    if not isinstance(data, dict) or not isinstance(data.get("chips"), list):
        fail("Malformed NVIDIA JSON")
    result = []
    # Resolve each installed GPU independently before finding a common flavor.
    for device in devices:
        matches = []
        # Prefer exact subsystem records over generic records for the same device.
        for record in data["chips"]:
            if not isinstance(record, dict) or not isinstance(record.get("devid"), str) or not re.fullmatch(r"0x[0-9a-fA-F]{4}", record["devid"], re.I):
                fail("Malformed NVIDIA chip record")
            if record["devid"][2:].lower() != device["device"]:
                continue
            sv, sd = record.get("subvendorid"), record.get("subdevid")
            if (sv is None) != (sd is None) or (sv is not None and not all(isinstance(x, str) and re.fullmatch(r"0x[0-9a-fA-F]{4}", x, re.I) for x in (sv, sd))):
                fail("Malformed NVIDIA subsystem record")
            if sv is not None and [sv[2:].lower(), sd[2:].lower()] != [device["subvendor"], device["subdevice"]]:
                continue
            features, name = record.get("features"), record.get("name")
            if not isinstance(name, str) or not name.strip() or not isinstance(features, list) or not all(isinstance(x, str) for x in features):
                fail("Malformed NVIDIA matching record")
            matches.append((sv is not None, name, frozenset(x.lower() for x in features), record.get("legacybranch")))
        if not matches:
            fail("Unknown NVIDIA GPU " + device["device"])
        strongest = max(x[0] for x in matches)
        chosen = [x for x in matches if x[0] == strongest]
        if any(x != chosen[0] for x in chosen):
            fail("Conflicting NVIDIA records for " + device["device"])
        result.append(chosen[0])
    return result


# Resolve all devices together using the locked target module's kernel packages.
def resolve(devices, stage):
    p = subprocess.run(["nix", "eval", "--extra-experimental-features", "nix-command flakes", "--option", "allow-import-from-derivation", "false", "--impure", "--json", "--expr", EXPR], env={**os.environ, "INSTALL_FLAKE_STAGE": stage}, capture_output=True, text=True, check=True)
    native = json.loads(p.stdout)
    system = native["system"]
    if system not in ("x86_64-linux", "aarch64-linux") or not isinstance(native["candidates"], list):
        fail("Unsupported host system or malformed native packages")
    candidates = []
    # Reject malformed native metadata before comparing package versions.
    for c in native["candidates"]:
        if not isinstance(c, dict) or not re.fullmatch(r"stable|legacy_[0-9]+", c.get("branch", "")) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", c.get("version", "")) or not isinstance(c.get("open"), bool) or not isinstance(c.get("broken"), bool):
            fail("Malformed native NVIDIA candidate")
        if not c["broken"]:
            candidates.append(c)
    body = fetch("https://raw.githubusercontent.com/NVIDIA/nvidia-driver-assistant/main/supported-gpus/supported-gpus.json")
    if body is None:
        fail("NVIDIA GPU metadata missing")
    records = vendor_records(json.loads(body), devices)
    candidates.sort(key=lambda c: (tuple(map(int, c["version"].split("."))), c["branch"]), reverse=True)
    arch = "Linux-x86_64" if system == "x86_64-linux" else "aarch64"
    # Check version-specific support and flavor in descending native version order.
    for c in candidates:
        body = fetch("https://download.nvidia.com/XFree86/" + arch + "/" + c["version"] + "/README/supportedchips.html")
        if body is None or not supported(body, devices):
            continue
        all_open = all("kernelopen" in r[2] for r in records)
        all_closed = all("kernelopen" not in r[2] or "gsp_proprietary_supported" in r[2] for r in records)
        if all_open and c["open"]:
            flavor, reason = True, "all GPUs allow open and native open package is available"
        elif all_closed:
            flavor, reason = False, "all GPUs have verified closed-module support"
        else:
            continue
        return {"branch": c["branch"], "version": c["version"], "open": flavor, "reason": reason,
                "devices": [{"name": r[1], **d} for d, r in zip(devices, records)]}
    fail("No native stable or legacy NVIDIA branch provides verified GPU support and a proven common module flavor; required legacy branch may be missing")


# Keep the hardware probe separate from the network/Nix resolution phase.
def main():
    try:
        if len(sys.argv) in (2, 3) and sys.argv[1] == "probe":
            print(json.dumps(probe(*sys.argv[2:])))
        elif len(sys.argv) == 3 and sys.argv[1] == "resolve":
            print(json.dumps(resolve(json.load(sys.stdin), sys.argv[2])))
        else:
            fail("Invalid NVIDIA helper invocation")
    except subprocess.CalledProcessError as exc:
        print("NVIDIA verification failed: command failed: " + (exc.stderr or str(exc)).strip(), file=sys.stderr)
        sys.exit(1)
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as exc:
        print("NVIDIA verification failed: " + str(exc), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
