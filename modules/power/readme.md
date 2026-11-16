# Power

[default.nix](default.nix) implements an optional policy that disables suspend, hibernation, hybrid sleep and suspend-then-hibernate, disables power-profiles-daemon, and sets the performance CPU governor with `mkDefault`, so ordinary host definitions can override it. Thermal safeguards remain separate. See [NixOS option priorities](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities) and [module selection](../readme.md).
