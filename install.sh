#!/usr/bin/env bash
# Collect installation choices and run the native NixOS installer after confirmation.
set -euo pipefail

# Accept only the original help and firmware-selection options.
override=
while (( $# )); do
    case $1 in
        --help) printf '%s\n' 'Usage: bash install.sh [--firmware 1|2]' '  1: UEFI' '  2: BIOS'; exit 0;;
        --firmware)
            (( $# >= 2 )) && [[ $2 == 1 || $2 == 2 ]] || { echo 'Invalid --firmware value.' >&2; exit 2; }
            if [[ $2 == 1 ]]; then override=efi; else override=bios; fi
            shift 2;;
        *) echo 'Usage: bash install.sh [--firmware 1|2]' >&2; exit 2;;
    esac
done
[[ $(id -u) == 0 ]] || { echo 'Run the installer as root.' >&2; exit 1; }
# Check native command availability before presenting installation choices.
for tool in cat jq lsblk nixos-generate-config mkfs.ext4 mount mkdir tee nixos-install nixos-enter env nix mktemp rm cp; do
    command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

# Compare decimal integers without shell arithmetic overflow.
at_least() {
    local value=$1 minimum=$2
    [[ $value =~ ^(0|[1-9][0-9]*)$ ]] || return 1
    (( ${#value} > ${#minimum} )) || { (( ${#value} == ${#minimum} )) && [[ $value == "$minimum" || $value > $minimum ]]; }
}
# Linux reports MemTotal in KiB; require at least 8,000,000,000 bytes.
if ! meminfo=$(cat /proc/meminfo); then echo 'Cannot read total RAM.' >&2; exit 1; fi
memtotal= count=0
while IFS= read -r line; do
    if [[ $line == MemTotal:* ]]; then
        ((count+=1))
        if [[ $line =~ ^MemTotal:[[:space:]]+([0-9]+)[[:space:]]+kB[[:space:]]*$ ]]; then memtotal=${BASH_REMATCH[1]}; fi
    fi
done <<<"$meminfo"
if (( count != 1 )) || ! at_least "$memtotal" 7812500; then
    echo 'Invalid or insufficient MemTotal: at least 8,000,000,000 bytes required.' >&2; exit 1
fi

# Display native hardware detection and the current block-device inventory.
if ! inventory=$(lsblk --json --paths --output NAME,TYPE,SIZE,FSTYPE,LABEL,MOUNTPOINTS,PKNAME,RO,PTTYPE,PARTTYPE,PARTUUID); then
    echo 'Could not read lsblk inventory.' >&2; exit 1
fi
if ! byte_inventory=$(lsblk --bytes --json --paths --output NAME,TYPE,SIZE); then
    echo 'Could not read lsblk byte inventory.' >&2; exit 1
fi
if ! rows=$(jq -er --argjson bytes "$byte_inventory" '[$bytes | .. | objects | select(has("name") and has("type"))] as $b | [.. | objects | select(has("name") and has("type"))] | if length == 0 or any(.[]; (.name | type != "string" or test("[[:cntrl:]]")) or (.type | type != "string" or test("[[:cntrl:]]"))) then error("invalid device inventory") else .[] end | . as $d | [$b[] | select(.name == $d.name and .type == $d.type)] as $matches | [.name,.type,.size,(.fstype // ""),(.label // ""),((.mountpoints // []) | map(select(. != null)) | join(",")),(.pkname // ""),(.ro|tostring),(.pttype // ""),(.parttype // ""),(.partuuid // ""),(if ($matches | length) == 1 and ($matches[0].size | type) == "number" and $matches[0].size >= 0 and ($matches[0].size | floor) == $matches[0].size then ($matches[0].size | tostring) else "" end)] | tojson | @base64' <<<"$inventory"); then
    echo 'Invalid or empty lsblk inventory.' >&2; exit 1
fi
if ! hardware=$(nixos-generate-config --show-hardware-config --no-filesystems); then echo 'Hardware detection failed.' >&2; exit 1; fi
if [[ -z ${hardware//[[:space:]]/} ]]; then echo 'Hardware detection returned no configuration.' >&2; exit 1; fi
printf '%s\n' '=== Detected hardware configuration ===' "$hardware" '=== Device inventory ==='
declare -a names types sizes filesystems labels mounts parents readonly tables parttypes partuuids byte_sizes
while IFS= read -r row; do
    decoded=$(printf '%s' "$row" | jq -Rr '@base64d | fromjson | map("x" + @base64) | .[]')
    mapfile -t fields <<<"$decoded"
    for i in "${!fields[@]}"; do fields[$i]=$(printf '%s' "${fields[$i]:1}" | jq -Rr '@base64d'); done
    names+=("${fields[0]}"); types+=("${fields[1]}"); sizes+=("${fields[2]}")
    filesystems+=("${fields[3]}"); labels+=("${fields[4]}"); mounts+=("${fields[5]}")
    parents+=("${fields[6]}"); readonly+=("${fields[7]}"); tables+=("${fields[8]}"); parttypes+=("${fields[9]}"); partuuids+=("${fields[10]}"); byte_sizes+=("${fields[11]}")
    printf '%d) %s  %s  %s  fs=%s label=%s mounts=%s parent=%s\n' "${#names[@]}" "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[3]:--}" "${fields[4]:--}" "${fields[5]:--}" "${fields[6]:--}"
done <<<"$rows"

# Select the detected firmware unless the user chose an override.
if [[ -d /sys/firmware/efi ]]; then current_firmware=efi; else current_firmware=bios; fi
if [[ -n $override ]]; then firmware=$override; echo "Firmware override: $firmware (manual selection)"
else firmware=$current_firmware; printf 'Detected firmware: %s\n' "$firmware"; fi
# Echo redirected input for readable transcripts; terminals already echo typed input.
ask() {
    local answer
    printf '%s ' "$1"
    if ! IFS= read -r answer; then echo; echo 'Cancelled: input ended; no installation started.'; exit 0; fi
    [[ -t 0 ]] || printf '%s\n' "$answer"
    REPLY=$answer
}
# Offer only partitions meeting the existing role and preservation criteria.
select_partition() {
    local prompt=$1 optional=$2 role=$3 index path parent_index valid type allowed limit=${#names[@]}
    local -a eligible=()
    for index in "${!names[@]}"; do
        path=${names[index]}; type=${parttypes[index],,}; valid=no
        for parent_index in "${!names[@]}"; do
            if [[ ${names[parent_index]} == "${parents[index]}" && ${types[parent_index]} == disk && ${readonly[parent_index]} == false ]]; then valid=yes; fi
        done
        if [[ $role == root ]] && ! at_least "${byte_sizes[index]}" 20000000000; then valid=no; fi
        if [[ $role == esp ]]; then
            [[ ${filesystems[index],,} == vfat || ${filesystems[index],,} == fat || ${filesystems[index],,} == fat32 ]] || valid=no
            [[ -z $type || $type == c12a7328-f81f-11d2-ba4b-00a0c93ec93b || $type == 0xef || $type == ef ]] || valid=no
        else
            [[ $type != c12a7328-f81f-11d2-ba4b-00a0c93ec93b && $type != 0xef && $type != ef && $type != 21686148-6449-6e6f-744e656564454649 && $type != e3c9e316-0b5c-4db8-817d-f92df00215ae && $type != de94bba4-06d1-4d40-a16a-bfd50179d6ac ]] || valid=no
            case ${filesystems[index],,} in ntfs|exfat|vfat|fat|fat32|bitlocker|crypto_luks) valid=no;; esac
        fi
        if [[ $valid == yes && ${types[index]} == part && ${readonly[index]} == false && $path =~ ^/dev/[a-zA-Z0-9._/+:-]+$ && $path != "${root-}" && $path != "${boot-}" && ${partuuids[index]} =~ ^[a-zA-Z0-9-]+$ ]]; then eligible+=("$index"); fi
    done
    if (( ${#eligible[@]} == 0 )); then
        if [[ $optional == yes ]]; then echo 'No separate /boot candidate; /boot will be part of root.'; SELECTED=; return; fi
        echo "No eligible $role partition. Installation selection cannot continue." >&2; exit 1
    fi
    if [[ $optional != yes ]] && (( ${#eligible[@]} == 1 )); then
        index=${eligible[0]}; SELECTED=${names[index]}; printf 'Selected %s: %s\n' "$role" "$SELECTED"; return
    fi
    printf 'Eligible %s partitions:\n' "$role"
    for index in "${eligible[@]}"; do printf '%d) %s\n' "$((index+1))" "${names[index]}"; done
    if [[ $optional == yes ]]; then printf '%d) none (use root filesystem)\n' "$((limit+1))"; fi
    while :; do
        ask "$prompt"; index=$REPLY
        if [[ $optional == yes && $index == "$((limit+1))" ]]; then SELECTED=; return; fi
        if [[ $index =~ ^[1-9][0-9]*$ && ${#index} -le ${#limit} ]] && (( index <= ${#names[@]} )); then
            ((index--))
            for allowed in "${eligible[@]}"; do if (( index == allowed )); then SELECTED=${names[index]}; return; fi; done
        fi
        echo 'Invalid, read-only, duplicate or protected/non-partition selection; choose a listed number.'
    done
}

# Select BIOS disks with supported partition layouts.
eligible_disks=()
declare -A reservations=()
if [[ $firmware == bios ]]; then
    for i in "${!names[@]}"; do
        [[ ${types[i]} == disk && ${readonly[i]} == false && ${names[i]} =~ ^/dev/[a-zA-Z0-9._/+:-]+$ ]] || continue
        if [[ ${tables[i],,} == dos ]]; then eligible_disks+=("$i"); continue; fi
        if [[ ${tables[i],,} == gpt ]]; then
            for j in "${!names[@]}"; do
                if [[ ${parents[j]} == "${names[i]}" && ${types[j]} == part && ${readonly[j]} == false && -z ${filesystems[j]} && -z ${mounts[j]} && ${parttypes[j],,} == 21686148-6449-6e6f-744e656564454649 ]]; then eligible_disks+=("$i"); reservations[$i]=${names[j]}; break; fi
            done
        fi
    done
    if (( ${#eligible_disks[@]} == 0 )); then echo 'No eligible BIOS disk: a writable DOS disk or GPT disk with an unformatted, unmounted BIOS boot reservation is required.' >&2; exit 1; fi
fi

# Collect the existing root, boot, ESP, and BIOS installer targets.
root= boot= esp= disk= bios_reservation=
select_partition 'Select existing root partition number:' no root; root=$SELECTED
if [[ $firmware == efi ]]; then
    echo 'Bootloader:'; echo '1) GRUB'; echo '2) systemd-boot'
    while :; do ask 'Select bootloader number:'; case $REPLY in 1) loader=grub; break;; 2) loader=systemd-boot; break;; *) echo 'Choose 1 or 2.';; esac; done
    if [[ $loader == grub ]]; then select_partition 'Select separate Linux /boot partition number:' yes boot; boot=$SELECTED; fi
    select_partition 'Select existing EFI system partition number:' no esp; esp=$SELECTED
else
    loader=grub
    select_partition 'Select separate Linux /boot partition number:' yes boot; boot=$SELECTED
    if (( ${#eligible_disks[@]} == 1 )); then
        index=${eligible_disks[0]}; disk=${names[index]}; bios_reservation=${reservations[$index]-}; printf 'Selected BIOS disk: %s\n' "$disk"
    else
        echo 'Eligible BIOS disks:'
        for i in "${eligible_disks[@]}"; do printf '%d) %s\n' "$((i+1))" "${names[i]}"; done
        limit=${#names[@]}
        while :; do
            ask 'Select BIOS GRUB whole-disk number:'; index=$REPLY
            if [[ $index =~ ^[1-9][0-9]*$ && ${#index} -le ${#limit} ]] && (( index <= ${#names[@]} )); then
                ((index--)); disk=${names[index]}
                for i in "${eligible_disks[@]}"; do if (( index == i )); then bios_reservation=${reservations[$index]-}; break 2; fi; done
                echo 'Unsupported BIOS disk: requires MBR/dos or GPT with a BIOS boot reservation.'
            else echo 'Invalid disk selection.'; fi
        done
    fi
    # Keep the GRUB target stable if Linux later renumbers disks.
    command -v udevadm >/dev/null || { echo 'Missing required BIOS tool: udevadm' >&2; exit 1; }
    disk_aliases=$(udevadm info --query=symlink --root --name "$disk")
    read -r -a disk_aliases <<<"$disk_aliases"
    grub_device=
    # Select an alias that can be embedded unchanged in a Nix string.
    for alias in "${disk_aliases[@]}"; do
        if [[ $alias =~ ^/dev/disk/by-id/[a-zA-Z0-9._:+-]+$ ]]; then grub_device=$alias; break; fi
    done
    [[ -n $grub_device ]] || { echo "No safe whole-disk /dev/disk/by-id alias found for $disk." >&2; exit 1; }
fi

# Pin the shared inputs before graphics selection without touching the installation target.
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
tee "$stage/flake.nix" >/dev/null <<'EOF'
{
    inputs.desktop.url = "github:SorinGFS/nixos";
    inputs.nixpkgs.follows = "desktop/nixpkgs";
    outputs = { ... }: {};
}
EOF
nix --extra-experimental-features 'nix-command flakes' flake lock "path:$stage"
# Derive the initial state version from the same pinned Nixpkgs as the target.
state_version=$(INSTALL_FLAKE_STAGE="$stage" nix eval --extra-experimental-features 'nix-command flakes' --option allow-import-from-derivation false --impure --raw --expr '(builtins.getFlake ("path:" + builtins.getEnv "INSTALL_FLAKE_STAGE")).inputs.nixpkgs.lib.trivial.release')
[[ $state_version =~ ^[0-9]+\.[0-9]+$ ]] || { echo 'Invalid pinned Nixpkgs release.' >&2; exit 1; }

# Resolve an NVIDIA driver only when explicitly selected.
nvidia_info=
echo 'Graphics:'; echo '1) kernel/Mesa defaults'; echo '2) Query compatible NVIDIA driver'
while :; do
    ask 'Select graphics option number:'
    case $REPLY in
        1) break;;
        2)
            for tool in python3 nix curl; do command -v "$tool" >/dev/null || { echo "Missing NVIDIA prerequisite: $tool" >&2; exit 1; }; done
            case ${BASH_SOURCE[0]} in */*) helper="${BASH_SOURCE[0]%/*}/install-nvidia.py";; *) helper=./install-nvidia.py;; esac
            nvidia_devices=$(python3 "$helper" probe)
            nvidia_info=$(python3 "$helper" resolve "$stage" <<<"$nvidia_devices")
            jq -r '.devices[] | "Detected NVIDIA: \(.name) PCI 10de:\(.device)" + (if .subvendor then " subsystem \(.subvendor):\(.subdevice)" else "" end)' <<<"$nvidia_info"
            jq -r '"Selected NVIDIA: branch=\(.branch) version=\(.version) module=" + (if .open then "open" else "closed" end) + " (" + .reason + ")"' <<<"$nvidia_info"
            break;;
        *) echo 'Choose 1 or 2.';;
    esac
done
# Collect the administrator and hostname for the target configuration.
while :; do
    ask 'Administrator username (lowercase ASCII letter, then lowercase letters, digits, _ or -):'
    if [[ $REPLY =~ ^[a-z][a-z0-9_-]*$ && $REPLY != root && ${#REPLY} -le 32 ]]; then admin=$REPLY; break; fi
    echo 'Invalid administrator name.'
done
while :; do
    ask 'Hostname (DNS label; for nixos press Enter):'
    host=${REPLY:-nixos}
    if [[ ${#host} -le 63 && $host =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then break; fi
    echo 'Invalid hostname.'
done
# Preview choices before the user's existing final confirmation.
printf '\nVisualize the projected install:\nhost=%s\nadmin=%s\nfirmware=%s\nloader=%s\n' "$host" "$admin" "$firmware" "$loader"
for role in root boot esp disk reservation; do
    case $role in root) selected=$root;; boot) selected=$boot;; esp) selected=$esp;; disk) [[ $firmware == bios ]] || continue; selected=$disk;; reservation) [[ $firmware == bios && -n $bios_reservation ]] || continue; selected=$bios_reservation;; esac
    if [[ -z $selected ]]; then printf '%s=none\n' "$role"; continue; fi
    for i in "${!names[@]}"; do
        [[ ${names[i]} == "$selected" ]] || continue
        printf '%s=%s size=%s format=%s' "$role" "$selected" "${sizes[i]:-unknown}" "${filesystems[i]:-unknown}"
        case $role in root|boot) printf '%s' '->ext4 (DATA ERASED';; esp) printf '%s' ' (preserved; Linux bootloader/firmware writes';; disk) printf '%s' ' (GRUB writes';; *) printf '\n'; break;; esac
        [[ -z ${mounts[i]} ]] || printf '; mounted:%s' "${mounts[i]}"
        printf ')\n'; break
    done
done
while :; do
    ask 'Continue with this configuration? (yes/no):'
    case $REPLY in yes) break;; no) echo 'Cancelled: no installation started.'; exit 0;; *) echo 'Answer yes or no.';; esac
done

# Use the selected filesystems and native NixOS installation commands.
mkfs.ext4 -F "$root"
if [[ -n $boot ]]; then mkfs.ext4 -F "$boot"; fi
mkdir -p /mnt
mount "$root" /mnt
if [[ -n $boot ]]; then mkdir -p /mnt/boot; mount "$boot" /mnt/boot; fi
if [[ -n $esp ]]; then
    if [[ $loader == systemd-boot ]]; then esp_target=/mnt/boot; else esp_target=/mnt/boot/efi; fi
    mkdir -p "$esp_target"
    mount "$esp" "$esp_target"
fi
nixos-generate-config --root /mnt
# Write machine-local choices while preserving the generated hardware and filesystem configuration.
{
    printf '%s\n' '# Machine-local installation choices.' '{ ... }:' '{' '    imports = [ ./hardware-configuration.nix ];'
    printf '    networking.hostName = "%s";\n' "$host"
    printf '%s\n' '    networking.networkmanager.enable = true;' '    services.xserver.enable = true;' '    services.displayManager.gdm.enable = true;' '    services.desktopManager.gnome.enable = true;' '    security.sudo.enable = false;'
    printf '    users.users.%s = {\n        isNormalUser = true;\n        extraGroups = [ "wheel" "networkmanager" ];\n    };\n' "$admin"
    # Apply the verified NVIDIA branch and module flavor only when selected.
    if [[ -n $nvidia_info ]]; then
        nvidia_branch=$(jq -r '.branch' <<<"$nvidia_info")
        nvidia_open=$(jq -r '.open' <<<"$nvidia_info")
        printf '    nixpkgs.config.allowUnfree = true;\n    services.xserver.videoDrivers = [ "nvidia" ];\n    hardware.nvidia = {\n        open = %s;\n        branch = "%s";\n    };\n' "$nvidia_open" "$nvidia_branch"
    fi
    # Match the bootloader configuration to the selected firmware and mount layout.
    if [[ $firmware == efi ]]; then
        printf '%s\n' '    boot.loader.efi.canTouchEfiVariables = true;'
        if [[ $loader == grub ]]; then
            printf '%s\n' '    boot.loader.efi.efiSysMountPoint = "/boot/efi";' '    boot.loader.systemd-boot.enable = false;' '    boot.loader.grub = { enable = true; efiSupport = true; device = "nodev"; };'
        else
            printf '%s\n' '    boot.loader.efi.efiSysMountPoint = "/boot";' '    boot.loader.systemd-boot.enable = true;' '    boot.loader.grub.enable = false;'
        fi
    else
        printf '    boot.loader.systemd-boot.enable = false;\n    boot.loader.grub = { enable = true; device = "%s"; };\n' "$grub_device"
    fi
    printf '    system.stateVersion = "%s";\n}\n' "$state_version"
} | tee /mnt/etc/nixos/configuration.nix >/dev/null
# The machine-local flake owns identity and uses exactly the inputs pinned for graphics.
{
    printf '%s\n' '{' '    inputs.desktop.url = "github:SorinGFS/nixos";' '    inputs.nixpkgs.follows = "desktop/nixpkgs";' '    outputs = inputs@{ nixpkgs, ... }: {'
    printf '        nixosConfigurations."%s" = nixpkgs.lib.nixosSystem {\n' "$host"
    printf '%s\n' '            modules = [ ./configuration.nix inputs.desktop.nixosModules.default ];' '        };' '    };' '}'
} | tee /mnt/etc/nixos/flake.nix >/dev/null
cp "$stage/flake.lock" /mnt/etc/nixos/flake.lock
env -u TMPDIR nixos-install --root /mnt --flake "path:/mnt/etc/nixos#$host"
# Let the native password tool read the administrator's password directly from the terminal.
nixos-enter --root /mnt -c "passwd '$admin'"
printf 'Installation complete. Target filesystems remain mounted at /mnt; reboot manually when ready.\n'
