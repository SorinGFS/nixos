# Firefox Nightly

This module selects Firefox Nightly, configures its application-scoped launcher and supplies unlocked preference defaults.

## Composition and revision ownership

The root [flake.nix](../../../flake.nix) declares Nixpkgs on `nixos-26.05` and the `firefox-nightly` packaging input from `nix-community/flake-firefox-nightly`. This is the upstream packaging source, not a direct Mozilla source checkout. Its Nixpkgs input follows the root Nixpkgs input. The thin output function, `outputs = inputs: import ./modules/exports.nix inputs;`, delegates export assembly:

```text
flake.nix
    |
    +--> inputs.nixpkgs
    +--> inputs.firefox-nightly
    |       +--> nixpkgs follows root nixpkgs
    |
    +--> outputs function --> modules/exports.nix
                                  |
                                  +--> nixosModules.desktop
                                  +--> nixosModules.default
                                  +--> optional policy modules
```

[exports.nix](../../exports.nix) exports `desktop` with `_module.args.desktopInputs = desktopInputs;` and an import of [desktop composition](../../desktop/default.nix). That composition imports GNOME, shared services, security, shell and applications, including this Firefox module. The `default` export combines it with the separately exported power, virtualisation, and KeePass policies. [System composition](../../readme.md#integration-and-ownership) describes selecting these exports.

The Firefox module's `desktopInputs` parameter is an explicit dependency contract: it must contain the Nightly input. The exported desktop supplies it through `_module.args`; importing [Firefox module](default.nix) directly requires supplying that contract too. A source import does not create external dependencies. Passing the whole input set is the current composition's interface, not a requirement for every application module.

The machine-local consumer lock owns the resolved revisions. `follows` shares a Nixpkgs source node, reducing independently selected source revisions; it does not prove ABI compatibility, require one package-set instance, or make platforms equivalent. Modules receiving the same `pkgs` normally reuse that set. Separate Nixpkgs imports, overlays, configuration, or platforms can still produce different package sets and derivations:

```text
one locked Nixpkgs source
    |
    +--> package set for platform A, configuration X
    +--> package set for platform A, configuration Y
    +--> package set for platform B
```

The paper's [external application composition](../../../tutorial/nix.md#9-an-external-application-composition) explains these mechanisms independently of this implementation, including [input sharing limits](../../../tutorial/nix.md#input-sharing-and-its-limits).

## Package selection and launcher customization

[Firefox module](default.nix) selects `desktopInputs.firefox-nightly.packages.${pkgs.stdenv.hostPlatform.system}.firefox-nightly-bin`. The host-platform key selects the produced application's platform. Its `overrideAttrs` appends to the existing `makeWrapperArgs`, preserving upstream wrapper arguments while adding the X11 environment below.

The package is assigned through `lib.mkDefault` to `programs.firefox.package`. An ordinary consumer definition can replace that option default, for example with `pkgs.firefox`; preference defaults remain separately configured. Option priority determines which package value wins, whereas `overrideAttrs` changes the selected package recipe.

```text
external Nightly packaging revision
    |
    v
Nightly package recipe
    |
    +--> wrapper attribute customization
              |
              v
      selected programs.firefox.package
              |
              v
      NixOS browser integration
```

A wrapper change can create a new derivation/output while reusing an unchanged fixed-output browser download. Rebuilding need not mean recompiling the browser; the recipe and available substitutes determine the actual work. The generic explanations distinguish [package customization and overlays](../../../tutorial/readme.md#package-overrides-and-package-set-overlays), [fixed-output fetching](../../../tutorial/nix.md#fixed-output-fetching), and [launcher environments](../../../tutorial/nix.md#script-interpreters-and-launcher-environments).

## X11 compatibility

The native Firefox Nightly launcher in [Firefox module](default.nix) unsets `WAYLAND_DISPLAY` and sets `GDK_BACKEND=x11` and `MOZ_ENABLE_WAYLAND=0` for Firefox and its child processes, including launches from the desktop or `firefox-nightly` command. The session environment and generic default-browser launchers retain their settings. The change takes effect after [project activation](../../readme.md#apply-local-configuration-and-update-the-whole-system) and a Firefox restart.

The compatibility choice trades isolation for X11 compatibility: on a Wayland desktop, Xwayland provides weaker isolation between X11 clients than native Wayland, so other X11 clients may be able to observe or interfere with Firefox input and windows. The compatibility setting is scoped to Firefox.

## Update Firefox Nightly

Firefox Nightly updates through the [operator-triggered whole-system update](../../readme.md#apply-local-configuration-and-update-the-whole-system). Refreshing all flake inputs advances its packaging input alongside Nixpkgs, so an available newer Nightly build is included in the same system build and activation. The machine's lockfile records the selected Nightly packaging revision. Revision selection belongs to the root input declaration and consumer lock; dependency delivery belongs to the composition argument, and package/launcher selection belongs to the Firefox module. The [four-state update model](../../../tutorial/nix.md#11-manual-updates-across-four-kinds-of-state) explains why refreshing a lock, building, activating, and restarting are separate transitions.

Fully quit and restart Firefox after activation to run the installed version. Native unlocked AutoConfig defaults and GUI-managed profile preferences retain their existing ownership and precedence. Browser startup can migrate profile data, so a system rollback alone does not restore that data; keep an independent profile backup.

## Change Firefox defaults

Edits to `modules/applications/firefox/index.json` take effect after [project activation](../../readme.md#apply-local-configuration-and-update-the-whole-system) and a Firefox restart. These are unlocked AutoConfig defaults: existing profile preferences, including an existing `user.js`, retain their values and take precedence. Resetting an individual preference in `about:config` selects its default.

Official documentation: [NixOS option priorities](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities), [Firefox AutoConfig](https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig).
