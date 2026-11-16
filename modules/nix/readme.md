# Nix settings and retention

[default.nix](default.nix) enables `nix-command` and flakes and automatically deduplicates newly imported store files. The separate [ld.nix](ld.nix) supports dynamically linked binaries downloaded by fnm; it is imported by the Bash integration, not required by the Nix daemon. See [NixOS configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax).

## Garbage collection and rollback retention

Ordinary collection removes unreferenced objects while preserving retained profile generations:

```bash
su -c 'nix-collect-garbage'
```

**Warning:** the next command removes every other generation of the system profile, keeping only its current generation, including removing newer generations if the current selection was rolled back. Rollback to deleted system generations is lost. Other roots can still retain store objects, so reclaimed space is not guaranteed.

```bash
su -c 'nix-env --profile /nix/var/nix/profiles/system --delete-generations old && nix-collect-garbage'
```

See the Nix 2.34 manuals for [garbage collection](https://nix.dev/manual/nix/2.34/command-ref/nix-collect-garbage.html) and [generation deletion](https://nix.dev/manual/nix/2.34/command-ref/nix-env/delete-generations.html).

## One-off tools

In a normal user terminal, replace the placeholders with a documented exported program or package. These commands can download and cache store objects; programs can make their own persistent changes. They do not update the host flake lock.

```bash
nix run github:OWNER/REPO#APP
```

```bash
nix shell github:OWNER/REPO#PACKAGE
```

Type `exit` to leave the temporary shell. Not every flake exports either kind of entry.
