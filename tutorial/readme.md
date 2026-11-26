# NixOS, progressively: from first principles to reusable systems

## 1. Scope, safety, and the mental model

<details>
<summary>Read this section</summary>

### What this tutorial covers

This tutorial starts with the basics of the Nix language, functional programming, and declarative configuration. By the end, you’ll be able to explain how a small NixOS configuration fits together, inspect its inputs, edit it, build and activate it, update its dependencies, recover earlier selections, and share reusable modules. Use the references for your installed version when you’re ready to go deeper.

The system examples begin with an **already installed NixOS machine**. Installation, partitioning, bootloader selection, hardware drivers, and migration from another distribution require machine-specific decisions covered by the [official NixOS manual](https://nixos.org/manual/nixos/stable/). Package and language exercises also apply on other supported systems with Nix installed; NixOS activation requires a NixOS host.

The reference baseline is **NixOS 26.05 and Nix 2.34.9**, dated **2026-11-14**. Installed versions determine the applicable manuals and option names. Maintaining the installed release branch and planning a release upgrade are separate choices.

Check the installed versions from any directory (**READ-ONLY**). On any supported host with Nix installed, check Nix itself:

```bash
nix --version
```

On a NixOS host, also check the OS release:

```bash
nixos-version
```

Use those versions to decide whether the system stages apply and which release documentation to consult.

### Source, store, selection, and runtime

**Source describes a desired result; Nix prepares artifacts in the store; profiles and activation determine availability and running-system effects.** A text edit changes source. Downloading or building obtains artifacts. Updating a pin changes a selected input revision. Declared service enablement reaches the running machine through system activation.

A recipe book, a pantry of prepared dishes, and a selected menu illustrate description, storage, and selection. The analogy has a boundary: computers also contain mutable files, processes, devices, and databases. Their persistence and recovery require separate arrangements. The [derivation reference](https://nix.dev/manual/nix/stable/language/derivations.html) explains build descriptions; the [NixOS configuration manual](https://nixos.org/manual/nixos/stable/#sec-changing-config) explains activation.

For example, editing a package list leaves the existing terminal and services as they were. Building prepares the new result; selecting it in a profile makes it available in that environment, and activating a system configuration applies the chosen OS changes. Before running a command, ask which of these transitions you intend.

### Progressive roadmap and operational prerequisites

The learning sequence progresses through [the mental model](#1-scope-safety-and-the-mental-model), [evaluation](#2-components-and-first-expression-evaluation), [the language](#3-reading-the-nix-language), [installed modules](#4-inspecting-installed-configuration-and-modules), [package scope](#5-choosing-package-scope), [the flake spine](#6-wrapping-the-existing-system-in-one-flake), [activation](#7-building-testing-and-activating-the-system), [optional system services](#8-accounts-networking-services-and-an-optional-desktop), [updates](#9-updating-inputs-and-planning-release-upgrades), [recovery](#10-recovery-and-garbage-collection), [development tools](#11-extending-the-flake-with-development-tools), [reuse](#12-reusing-modules-and-customizing-package-sets), and [diagnosis](#13-systematic-diagnosis-and-next-step-selection). Advanced stages extend the same small configuration. The appendices provide a [task command reference](#appendix-a-command-reference-by-task), [glossary](#appendix-b-glossary), [next-step plan](#appendix-c-next-step-plan), and [official sources](#appendix-d-sources-and-evidence-limits).

Complete the [one-time user Nix setup](#evaluation-before-building) before running the modern Nix examples. You do not need to activate a NixOS configuration to start.

A terminal provides an interface for entering commands; a shell interprets them. The shell examples use Bash syntax. Sequential execution with inspection of each result keeps failures attributable to individual operations. The working directory is the shell's current folder. `PATH` lists executable-search directories, so different environments can resolve the same command name to different installed copies. Nix expressions belong in Nix files or explicitly quoted expression arguments rather than unquoted shell input.

| Effect label | Operational meaning |
| --- | --- |
| **READ-ONLY** | Intended inspection. Evaluation involving external sources can still fetch inputs, write caches or store metadata, and build through import-from-derivation. |
| **BUILD-ONLY** | Downloading, store/cache writes, and builder execution are possible; OS activation remains unchanged. |
| **SOURCE EDIT** | Configuration or lock files change; locking can also fetch inputs. |
| **USER-PROFILE CHANGE** | Package selections change for the invoking user, independently of OS generations. |
| **SYSTEM CHANGE** | Services, accounts, networking, boot selections, passwords, or store retention can change; the specific operation determines the risks. |

Application execution and development-shell entry add effects beyond building. Applications and `shellHook` code execute with the invoking account's permissions, including normal user-level file and network access.

`root` is the system administrator account. Administrative examples using `sudo` require an installed, configured `sudo` and authorization for the invoking account. An authorized alternative, where a root password is available, is a root shell entered with `su -`; administrative commands in that shell omit `sudo`, and `exit` leaves it. Ordinary package and build experiments belong to a normal user account. Edits under `/etc/nixos` require the existing authorized source-editing workflow, with ownership and permissions preserved.

“From any directory” indicates that the current folder does not affect the reference. “From `/etc/nixos`” identifies a required working directory; explicit `path:/etc/nixos` references identify that source independently. `REPLACE_WITH_SYSTEM`, `COMMIT`, and `PROFILE_NAME` denote verified platform, revision, and profile-name values. `workstation` is a fictional flake output label, separate from the machine's actual hostname.

Before each operation, check the account, source location, substitutions, and possible effects. Verify missing machine details rather than guessing them.

### Practice: classifying a proposed change

You've edited a package list, updated `flake.lock`, and built the system. Has the newly declared SSH service started yet? Name the missing transition and the runtime observation that would show whether the service is actually running.

Building alone does not start the service. System activation applies the declared SSH configuration; a runtime service inspection establishes the resulting state. Editing, locking, and building prepare the transition. Activation output and service inspection remain necessary because a failure can leave a partially changed system.

</details>

## 2. Components and first-expression evaluation

<details>
<summary>Read this section</summary>

### Nix, Nixpkgs, NixOS, the store, and flakes

Start by separating the names. **Nix** denotes both a language and package-management/build tooling. **Nixpkgs** supplies package definitions and supporting libraries, largely written in that language. **NixOS** is a Linux distribution assembled through Nix and Nixpkgs. The **Nix store**, normally `/nix/store`, contains source snapshots, build descriptions, packages, and generated files. A **flake** is a source tree whose standardized `flake.nix` entrypoint declares inputs and outputs; other NixOS entrypoints also exist.

Package management with Nix is independent of NixOS. NixOS additionally composes operating-system files and services. The official introductions cover [language basics](https://nix.dev/tutorials/nix-language.html), [profiles](https://nix.dev/manual/nix/stable/package-management/profiles.html), and [flake concepts](https://nix.dev/concepts/flakes.html).

For example, a shell containing Nixpkgs' Hello package is a package exercise on a supported Nix host. An SSH server declaration is NixOS module configuration. A locked Nixpkgs revision is an input-selection mechanism.

### Evaluation before building

An **expression** produces a value; **evaluation** computes it. The modern Nix CLI and flakes remain experimental in the reference version. Enabling them makes those interfaces available but does not imply stability.

**One-time user setup — SOURCE EDIT.** Do this as your ordinary user, without `sudo` or a root shell. If `nix-command` and `flakes` are already enabled for that account, skip this edit. Otherwise, edit the user `nix.conf` that Nix reads, creating it if missing. Normally this is `~/.config/nix/nix.conf`; if you set `XDG_CONFIG_HOME`, use `$XDG_CONFIG_HOME/nix/nix.conf`. If `NIX_USER_CONF_FILES` is set, it specifies the user configuration files instead; update the appropriate file in that list.

Add this line as **file content**, not as a shell command. If the file already has an `extra-experimental-features` line, add only the missing names to it. Keep existing settings and features; the `extra-` form adds to the configured feature list rather than replacing it.

```ini
extra-experimental-features = nix-command flakes
```

See the [Nix 2.34 configuration reference](https://nix.dev/manual/nix/2.34/command-ref/conf-file.html) for configuration file selection and settings, and the [`nix eval` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html) for evaluation behavior.

Try this **READ-ONLY** expression as your ordinary user from any directory; the inputs are only arithmetic literals:

```bash
nix eval --expr '1 + 2'
```

Evaluation prints `3`. If Nix reports a disabled experimental feature, check that it reads the user file you edited. If the executable is missing or a flag is unsupported, check the installed version before continuing.

### Evaluation, realization, and running systems

A rebuild need not compile everything again: it can reuse store results or fetch binary substitutes. Evaluation can produce a **derivation**: a structured recipe identifying a builder and its inputs. Nix records store-level build descriptions and **realizes** required outputs by fetching substitutes from configured caches or running builds. Dependencies form a graph. A package's **closure** includes the store objects referenced transitively at runtime. NixOS composes a top-level system result; activation applies relevant changes to the running machine.

Different versions and variants can coexist at distinct store paths. Store results are treated as immutable; source changes followed by rebuilding replace direct edits to `/nix/store`. Documents and application databases remain mutable and require independent backups. The hash-like part of a store path is **not necessarily a checksum of its output contents**. Input-addressed derivations commonly identify outputs from build inputs; byte-for-byte reproducibility requires separate verification. The [NixOS manual](https://nixos.org/manual/nixos/stable/), [derivation reference](https://nix.dev/manual/nix/stable/language/derivations.html), and [profile explanation](https://nix.dev/manual/nix/stable/package-management/profiles.html) describe these mechanisms.

Explicit dependencies and retained generations improve inspectability and recovery choices. Their costs include disk use, evaluation complexity, cache/network dependence, and expensive downstream rebuilds after foundational changes. Non-Nix binary downloads may require compatibility work on NixOS.

A text-configuration change can reuse most packages; a foundational-library change can require many downstream builds if substitutes are unavailable. Once the artifacts are ready, service-specific migration plans and data backups still cover mutable state outside the store results. A failure needs different evidence and recovery depending on whether it occurred during evaluation, fetch/build, or activation/runtime.

### Practice: tracing dependency reachability

A selected editor references a runtime library in the store, but the library is not on the explicit package list. Does that make the library disposable? Explain the difference between explicit selection and transitive reachability.

No. The editor's closure retains the referenced library. Nix's reachability and garbage-collection mechanisms identify unused store objects; manual deletion based on package-list membership would disregard runtime dependencies.

</details>

## 3. Reading the Nix language

<details>
<summary>Read this section</summary>

### Values, lists, and attribute sets

Start with the types you will encounter in configuration. A **string** is double-quoted text. A **Boolean** is `true` or `false`; numbers are unquoted; `null` expresses absence where an interface accepts it. A **list** has square brackets and whitespace-separated elements. An **attribute set** maps names to values inside braces, with semicolons ending assignments. A dot selects a nested attribute; dotted assignments construct nested sets.

These constructs belong to the language. The module system supplies the NixOS meaning of paths such as `services.openssh.enable`. The [language tutorial](https://nix.dev/tutorials/nix-language.html) explains the underlying syntax.

This complete standalone expression represents sample data:

```nix
# Standalone sample data with strings, lists, and nested attributes.
{
    title = "Learning Nix";
    enabled = true;
    attempts = 2;
    optionalValue = null;
    tools = [ "hello" "git" ];
    machine.role = "practice";
}
```

`machine.role = "practice";` represents the same nesting as `machine = { role = "practice"; };`. Duplicate attributes in one ordinary set are errors rather than sequential variable updates.

Read the semicolons as assignment terminators and the spaces as list separators here; these examples use Nix syntax, not shell syntax.

### Local names, interpolation, and operators

Use local names to reuse values without repeating them. `let ... in ...` defines local bindings and returns the expression following `in`. `${expression}` interpolates a string-compatible value; `toString` converts a number for interpolation. `'' ... ''` delimits an indented multiline string. `./file.nix` resolves relative to the containing Nix file, whereas `"./file.nix"` is text rather than a path value.

`++` concatenates lists. `//` combines ordinary sets by replacing matching top-level keys from the right; this shallow operation differs from typed NixOS option merging. `==` tests equality, `&&` expresses Boolean conjunction, and `if condition then value else otherValue` selects a value. `inherit name;` abbreviates `name = name;`; `inherit (set) name;` abbreviates `name = set.name;`.

Explicit package references such as `[ pkgs.hello pkgs.git ]` expose their origin. The alternative `let inherit (pkgs) hello git; in [ hello git ]` binds only the locally needed attributes.

Evaluate the local bindings and list concatenation together with this **READ-ONLY** command from any directory. Its inputs are literals:

```bash
nix eval --expr 'let count = 2; tools = [ "hello" ]; in { message = "${toString count} tools"; selected = tools ++ [ "git" ]; }'
```

The resulting set contains `message = "2 tools"` and `selected = [ "hello" "git" ]`; printed attribute order can differ from source order.

### Functions, imports, and laziness

NixOS module argument lists use ordinary Nix function syntax. A **function** accepts an input and returns a value. `x: x + 1` accepts one number; `(x: x + 1) 2` applies it using whitespace. `{ name, suffix ? "!" }: name + suffix` accepts named arguments with a default suffix. `...` in a parameter pattern accepts additional arguments; it is actual syntax, not an omission marker. Thus `{ pkgs, ... }:` accepts a set containing `pkgs` and possibly other fields.

`import ./file.nix` evaluates a file and returns its value. A returned function receives arguments separately: `(import ./function.nix) { name = "Learner"; }`. `builtins.import` is the underlying builtin; ordinary `import` is available by default. NixOS `imports` instead identifies modules for collection and merging. It is neither textual inclusion nor simply a language-level `import` call.

Nix is **functional**: bindings describe values instead of repeated mutation. It is **lazy**: values are computed when needed, which can defer errors and make traces indirect. Evaluation can still fetch inputs, write caches, or trigger import-from-derivation builds. These properties are covered in [language basics](https://nix.dev/tutorials/nix-language.html).

In this standalone expression, the pattern before `:` accepts the supplied `name` and falls back to the default `suffix`. Whitespace applies `greet` to the argument set, so the return expression produces `"Hello, Learner!"`:

```nix
# Function application with a named argument and a default suffix.
let
    greet = { name, suffix ? "!" }: "Hello, ${name}${suffix}";
in
    greet { name = "Learner"; }
```

### Practice: representing typed values

Write an attribute set with Boolean `enabled` set to `true`, `tools` as a list of the strings `hello` and `git`, and numeric `count` equal to the list's length (`2`). Check that the Boolean and number are unquoted and the list elements are separated by whitespace.

The complete set preserves each value's intended type:

```nix
# Sample attributes with Boolean, list, and numeric values.
{
    enabled = true;
    tools = [ "hello" "git" ];
    count = 2;
}
```

</details>

## 4. Inspecting installed configuration and modules

<details>
<summary>Read this section</summary>

### Preserving the installed-machine foundation

Keep the working hardware, storage, boot, and access settings as the foundation for any additions. `/etc/nixos/configuration.nix` commonly imports `hardware-configuration.nix` and defines system options. Installations can have additional files or other entrypoints; the actual import graph establishes ownership. The existing hardware imports, file systems, boot settings, accounts, authentication, networking, and `system.stateVersion` remain part of the system composition.

An independently recoverable configuration/data backup, a known-good bootable generation, and recovery access are prerequisites for source changes. `system.stateVersion` selects compatibility defaults for stateful behavior; the input branch selects the release independently. The installed state version remains appropriate unless a deliberate state migration requires a documented change. The [NixOS manual](https://nixos.org/manual/nixos/stable/) covers installation and configuration responsibilities.

Use `less` from any directory for these **READ-ONLY** inspections; press `q` to leave each file. Start with the conventional entrypoint:

```bash
less /etc/nixos/configuration.nix
```

If the installation uses the conventional hardware module, inspect it too:

```bash
less /etc/nixos/hardware-configuration.nix
```

If an expected file is absent, identify the actual entrypoint and follow its imports rather than guessing a replacement. Confirm the entrypoint, hardware imports, recoverable source and data, and boot/access fallback before editing.

### Options and supplied module arguments

A module can be a set or a function returning definitions. The module system supplies arguments including `pkgs`, the package set; `lib`, helper functions; and `config`, the merged configuration. An **option declaration** establishes its name, type, documentation, and often a default. An **option definition** supplies a value. Unknown options and wrong types fail evaluation.

`environment.systemPackages` makes executables available system-wide. Required service registration, D-Bus integration, or other system behavior belongs to the relevant NixOS service/program interface rather than package selection alone. The manual covers [configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax) and [package management](https://nixos.org/manual/nixos/stable/#sec-package-management).

**SOURCE EDIT:** With authorized editing access, put this complete module in `/etc/nixos/modules/cli-tools.nix`. Use an ordinary `modules/` directory if one does not yet exist, and leave the installed `configuration.nix` intact:

```nix
# Additional command-line tools alongside existing hardware and service settings.
{ pkgs, ... }:
{
    environment.systemPackages = [ pkgs.hello pkgs.git ];
}
```

This module is the single owner of the additional tool definitions. Stage 6 adds it to the composition; the running system remains unchanged until activation.

### Merging definitions by type and priority

Module composition is not last-file-wins. The module system collects definitions and merges them according to type and priority. Package lists generally concatenate. Conflicting scalar values at equal effective priority can fail. `lib.mkDefault` permits ordinary definitions to replace a default; `lib.mkForce` deliberately overrides ordinary definitions. A force override therefore requires an understood priority conflict and an intentional policy choice. Helpers such as `mkBefore` affect list ordering rather than winning priority.

Language-level `//` instead performs shallow set replacement. Module `imports` forms a graph, not a sequence of imperative updates. The manual's [modularity guidance](https://nixos.org/manual/nixos/stable/) and [priority rules](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities) describe the distinction.

This standalone illustrative module offers a default; the progressive spine retains its existing hostname definitions:

```nix
# A hostname default replaceable by ordinary machine definitions.
{ lib, ... }:
{
    networking.hostName = lib.mkDefault "workstation";
}
```

An ordinary `networking.hostName = "another-name";` definition wins over this default. Two different ordinary hostname definitions require investigation of their owners and intended policy.

### Practice: preserving configuration ownership

Someone proposes replacing your installed `configuration.nix` with an online editor module. The installed file contains hardware imports and administrator definitions. How would you add the editor definition without discarding any machine-specific settings?

The existing `configuration.nix` and its imports remain included. A separate module supplies the new package definition alongside them. Storage identifiers, bootloader settings, users, and `stateVersion` remain specific to the installed machine.

</details>

## 5. Choosing package scope

<details>
<summary>Read this section</summary>

### Running a package for a single use

To try a tool without changing your user profile, system package list, or selected OS generation, pick one of the following ways to run Hello. Both are **BUILD-ONLY plus application execution** and work from any directory, provided you trust the referenced source. Direct GitHub flake references do not require a local flake input. An explicit branch avoids relying on the machine's `nixpkgs` registry alias, but it still moves over time; it is not an enduring pin.

Use `nix run` to build or fetch an app or suitable package and run it. The `--` passes the remaining arguments to Hello, which prints the supplied greeting.

```bash
nix run github:NixOS/nixpkgs/nixos-26.05#hello -- --greeting 'Hello from Nix'
```

Alternatively, use `nix shell` to put the tool on `PATH` in a temporary environment. Here `--command hello` runs it directly and prints the default greeting. Neither approach isolates the program from ordinary user-level file and network access.

```bash
nix shell github:NixOS/nixpkgs/nixos-26.05#hello --command hello
```

The Nix 2.34 manual documents `nix shell` on the `nix env shell` reference page; the installed version determines which spelling works. These examples use `nix shell`, not the legacy `nix-shell` interface. See the [`run` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html) and [shell reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-env-shell.html).

### User-profile selections and history

A user profile lets one account keep a package without declaring it for all system users. Adding a package to the profile is **imperative**: it changes the selection immediately. **Declarative** management instead records the desired package set in source and rebuilds from it. Both selections can coexist, and when they overlap it can be less obvious which executable the shell finds.

Run the following choices from any directory as the normal user whose profile you intend to inspect or change; `sudo` targets a different account. Modern `nix profile` and legacy `nix-env` profile formats are not interchangeable. If you see a format error, identify the existing workflow rather than forcing the two interfaces together.

**READ-ONLY — list the current selections:**

```bash
nix profile list
```

**USER-PROFILE CHANGE — add Hello** if you want a persistent selection for this account:

```bash
nix profile add github:NixOS/nixpkgs/nixos-26.05#hello
```

**READ-ONLY — inspect profile history**, particularly before deciding whether to roll back:

```bash
nix profile history
```

**USER-PROFILE CHANGE — roll back** only if the most recent older profile version is the intended target. Intervening operations can make it a different version from the one you want. This changes the user profile, not the selected NixOS generation.

```bash
nix profile rollback
```

See the references for [adding](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-add.html), [listing](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-list.html), and [rolling back](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-rollback.html).

### Removing and upgrading at the owning layer

Change the selection where it is owned. For a modern profile, use the exact `PROFILE_NAME` reported by `profile list`. Both alternatives below are **USER-PROFILE CHANGE** operations and work from any directory as the account that owns the profile.

To remove a profile selection, use [remove](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html). This does not immediately delete store files: dependencies and older generations can still retain them, and Nix manages cleanup according to reachability.

```bash
nix profile remove PROFILE_NAME
```

To refresh a selection instead, use [upgrade](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-upgrade.html). An unlocked reference is followed; a locked commit reference does not automatically move to a newer commit.

```bash
nix profile upgrade PROFILE_NAME
```

For a system package, edit the owning module instead. Omitting `pkgs.hello` from the stage 4 list removes that system-wide selection after the stage 7 rebuild and activation. Other profiles or environments can still expose Hello.

### Practice: explaining a persistent executable

You removed Hello from your profile, but it still runs after you activate `cli-tools.nix`. The system, a user profile, and a temporary development shell can each put tools on `PATH`. Which definition still selects Hello in this scenario, and what declarative change would remove that selection without confusing it with profile history?

`environment.systemPackages` also selects Hello. Removing its entry from `modules/cli-tools.nix`, rebuilding, and deliberately activating changes the system selection. A fresh shell verifies the resulting lookup; an existing temporary shell can expose another copy independently.

</details>

## 6. Wrapping the existing system in one flake

<details>
<summary>Read this section</summary>

### Inputs, outputs, and the lock file

A flake lets you inspect the system's dependency choices without relying on the current state of a channel. `flake.nix` declares requested inputs and computes outputs. `flake.lock` records resolved dependencies, typically including revisions and content hashes. `inputs.nixpkgs.url` requests a source, and the lock resolves a branch to a particular revision. The `outputs` function accepts inputs and returns named results. An input declaration by itself installs no package.

Common output families are `packages.<system>.<name>`, `apps.<system>.<name>`, `devShells.<system>.<name>`, complete `nixosConfigurations.<name>`, and reusable `nixosModules.<name>`. A platform pair such as `x86_64-linux` or `aarch64-linux` matters for packages and systems. A NixOS configuration's attribute name is a selected label, not its architecture.

Pins support repeatable evaluation by recording input choices. User-data backups, runtime requirements, source archives for long-term availability, and independent byte-for-byte build verification cover different guarantees. Flakes remain experimental, and non-flake NixOS workflows remain legitimate. The [NixOS 26.05 highlights](https://nixos.org/manual/nixos/stable/release-notes.html#sec-release-26.05-highlights) describe `system.nix` as another entrypoint alongside `configuration.nix` and `flake.nix`. This sequence develops the flake workflow specified by the [flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).

Read the branch request in `flake.nix` to see the input policy and the resolved tree in `flake.lock` to see the exact choice. Inspect the running machine separately: neither file activates it.

### Source layout and verified platform selection

Keep the wrapper thin so it can reuse the installation without assuming its processor architecture or hostname. The source root is `/etc/nixos`. Explicit `path:/etc/nixos` references make local-source behavior independent of Git membership. This form requires a source tree containing only configuration safe for other local users to read: path snapshots can include untracked/private files that Git-backed filtering would omit. Source snapshots enter the normally world-readable store.

Passwords, private keys, tokens, and sensitive backups require storage outside that tree and the store. Other local users can normally read store paths regardless of whether those paths appear on their `PATH`. The layout extends existing files rather than replacing additional installed configuration.

For the **SOURCE EDIT**, add the new files shown here and keep the installed ones:

```text
/etc/nixos/
    configuration.nix              existing; preserve
    hardware-configuration.nix     existing, if used; preserve
    flake.nix                      new thin wrapper
    flake.lock                     generated by Nix
    modules/
        cli-tools.nix                from stage 4
        nix-cli.nix                  new if no feature setting exists
```

The following **READ-ONLY** platform inspection works from any directory:

```bash
nix eval --impure --raw --expr builtins.currentSystem
```

Here `--impure` obtains the current installation's native platform; it is not a general flake workaround. A native configuration requires agreement with any existing `nixpkgs.hostPlatform` setting. Cross-compilation is outside this sequence. Every `REPLACE_WITH_SYSTEM` occurrence denotes that verified platform pair and requires substitution before use.

### Creating the initial configuration spine

The complete flake makes the system's composition visible without moving machine-specific settings out of the installed configuration. `nixpkgs.lib.nixosSystem` composes modules into a complete system. `workstation` is the output attribute selected after `#`; `networking.hostName` remains owned by the existing configuration. The module list retains the installed `configuration.nix` and its hardware imports and adds the tool module and, if needed, the feature module.

The Nixpkgs branch must match the release intended for maintenance, with its documentation and option names checked. An installed release other than 26.05 requires its corresponding branch or a separately planned stage 9 upgrade. The verified platform substitution is equally necessary.

**SOURCE EDIT:** Declare persistent system-wide features in NixOS source. If the existing configuration already declares `nix.settings.experimental-features`, keep that definition and its entries, add only missing names there, and omit the `./modules/nix-cli.nix` entry in the wrapper below. Otherwise, put this supplemental module in `/etc/nixos/modules/nix-cli.nix`:

```nix
# Persistent CLI features taking effect after system activation.
{ ... }:
{
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

The setting takes effect only when this configuration becomes active. The [user setup](#evaluation-before-building) lets you evaluate and build before then; you do not need to copy it to root or edit the generated system `nix.conf` by hand.

`/etc/nixos/flake.nix` contains the complete wrapper below, with `REPLACE_WITH_SYSTEM` replaced by the verified value:

```nix
# Installed-machine composition retaining hardware and account setup.
{
    description = "Progressive NixOS configuration";
    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # System composition from existing and additional modules.
    outputs = { self, nixpkgs, ... }:
        let
            system = "REPLACE_WITH_SYSTEM";
        in
        {
            nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                    ./configuration.nix
                    ./modules/nix-cli.nix
                    ./modules/cli-tools.nix
                ];
            };
        };
}
```

`self` refers to this flake and can reference its outputs. The selected Nixpkgs input supplies `lib` and the composition interface.

This composition adds CLI tools and declares system-wide Nix features while retaining the installed hardware, users, boot settings, hostname, and state compatibility settings.

### Locking and inspecting before activation

Before building or activating, settle the input pins and check the output you intend to use. `nix flake lock` fills missing entries and preserves still-valid pins. A changed input URL can require a corresponding lock change. Nix generates the resolved revisions and hashes in the lock JSON. A known-good source/lock pair remains the recovery reference before edits.

Implicit local Git-backed references differ from the explicit `path:` form used here. New files need Git-index membership to enter a Git-backed snapshot. Dirty edits to tracked files are normally included with a warning and can be tested before a commit. Portable pure evaluation requires imports inside the captured source tree; private material remains outside. The official contracts cover [local flake sources](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) and [locking](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html).

**SOURCE EDIT plus input fetching:** Lock the source using the established administrative workflow, preserving ownership and permissions. The account running Nix must already have the features enabled and be authorized to write to `/etc/nixos`:

```bash
nix flake lock path:/etc/nixos
```

Then inspect the candidate from any directory (**READ-ONLY with evaluation/fetch/cache caveats**). `--no-update-lock-file` makes inspection fail if a lock change is required rather than silently accepting new pins:

```bash
nix eval --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

The lock should now contain resolved inputs, and evaluation should print the machine's preserved hostname. Neither operation activates the candidate.

### Practice: distinguishing output names from hostnames

The machine's hostname is not `workstation`. Can you still use `path:/etc/nixos#workstation` without renaming the machine? Explain how selecting `nixosConfigurations.workstation` explicitly differs from automatic hostname-based selection, and what still determines `networking.hostName`.

Yes. The selector directly chooses the `workstation` configuration attribute. Its composed modules retain the machine's actual hostname, so the two names can differ.

</details>

## 7. Building, testing, and activating the system

<details>
<summary>Read this section</summary>

### Building the system artifacts

Build the candidate first so that evaluation or build failures surface before you change any services. A complete configuration exposes `config.system.build.toplevel`. `nix build --no-link` realizes that result without creating a local `result` symlink; `--print-out-paths` reports its locations. Build success establishes realization with the selected inputs, not correct hardware behavior, remote access, or application operation. An unused result without an enduring garbage-collection root can later be collected. The [`build` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-build.html) specifies these flags.

After substituting the platform and locking the inputs, run this **BUILD-ONLY** command as a normal user from any directory. It can download substantial data, run package builders, and consume disk and CPU:

```bash
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel
```

On success, Nix prints a realized `/nix/store/…-nixos-system-…` path. The running system and boot default stay unchanged, and there is no new result link in the working directory. If the build fails, diagnose it before activating.

### Choosing an activation mode

Decide separately whether the candidate should run now and whether it should become the next boot default. The [configuration manual](https://nixos.org/manual/nixos/stable/#sec-changing-config) distinguishes four modes:

| Mode | Running-system effect | Future default-boot effect |
| --- | --- | --- |
| `build` | Artifact preparation only | Existing default retained |
| `test` | Candidate activated now | Existing default retained |
| `boot` | Current services retained | Candidate selected |
| `switch` | Candidate activated now | Candidate selected |

The direct `nix build --no-link` above avoids the result link commonly produced by `nixos-rebuild build`. For administrative activation with `nixos-rebuild`, keep the same explicit selector and a coherent, unchanged source/lock pair so that you act on the candidate you reviewed.

Choose one of the following **SYSTEM CHANGE** alternatives from any directory, with local console/recovery access and backups in place. Stage 1 describes authorized administrative alternatives. If flag support differs, check the installed `nixos-rebuild --help`.

Standard NixOS enables `sudo` by default, but it still requires authorization; this repository's desktop preset disables it. If a root password is available, use authorized `su -`, omit `sudo` only for administrative examples, then `exit` the root shell after the admin work (see stage 1). Do not run unprivileged commands as root.

**First privileged flake rebuild:** The ordinary user's feature settings need not be available to the account running the rebuild. If that account lacks the features, append `--option extra-experimental-features 'nix-command flakes'` to the chosen command below, using the same authorized `sudo` or `su -` workflow. This is an option for that invocation, not a separate command. The declared NixOS setting applies once the candidate is active: for `test` and `switch`, that is on successful activation; for `boot`, it is only after booting into the candidate.

**Test the candidate now without changing the boot default.** This really activates services: expect possible restarts, dropped connections, and stateful-service writes or migrations. Rebooting into the previous default does not undo those persistent effects; they require independent data recovery. An activation that fails partway through can still leave service changes: inspect runtime state and follow the prepared recovery plan. The same activation risks apply when switching immediately.

```bash
sudo nixos-rebuild test --flake path:/etc/nixos#workstation
```

**Select the candidate for the next boot without activating it now.**

```bash
sudo nixos-rebuild boot --flake path:/etc/nixos#workstation
```

**Activate the candidate now and make it the next boot default.**

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#workstation
```

### Observing activation and runtime results

After activation, check the changed feature, existing access methods, and relevant logs. Successful build and activation exit codes alone do not show that these workflows still work. Kernel and boot-sensitive changes can require a reboot; userspace activation is different from a fresh boot. User services also have lifecycles that a system rebuild does not universally restart, as described by the [configuration warnings](https://nixos.org/manual/nixos/stable/#sec-changing-config).

After successfully activating `cli-tools.nix`, run these **READ-ONLY** checks from any directory. `hello --version` executes the selected trusted program to inspect its version:

```bash
command -v hello
hello --version
nixos-version
systemctl --failed
```

A fresh terminal can clear stale shell-command lookup. Use the observed result and the previously working access methods to judge whether the transition succeeded. If something does not match, diagnose that specific mismatch before attempting another activation.

### Practice: classifying activation effects

First you want to verify that the candidate builds while leaving the running services alone. Later you want to select it for the next boot, still without activating it now. Which operation fits each goal, and why would `test` not fit the second one?

The direct top-level `nix build --no-link` prepares artifacts using the [ordinary-user setup](#evaluation-before-building). Authorized `nixos-rebuild boot --flake path:/etc/nixos#workstation` selects the later boot candidate; see the [first privileged rebuild note above](#choosing-an-activation-mode) if the rebuild account lacks the features. `test` would activate immediately and therefore has a different effect from the second goal.

</details>

## 8. Accounts, networking, services, and an optional desktop

<details>
<summary>Read this section</summary>

### Adding an account while preserving administrator access

If you want a separate practice account, add it without replacing the working administrator or authentication path. Existing administrator definitions and `users.mutableUsers` policy remain authoritative; changing that policy to `false` changes account-management semantics. With ordinary mutable user management, a newly declared user has no password by default. Password login requires an interactive password-setting operation after account creation.

Plaintext passwords and private keys belong outside Nix source and generated artifacts because those can enter the store. The [user-management manual](https://nixos.org/manual/nixos/stable/#sec-user-management) specifies account behavior and password options.

For this optional **SOURCE EDIT**, use the complete module below in `/etc/nixos/modules/practice-user.nix`. `learner` denotes a fictional, non-conflicting new account name, replaced consistently where necessary. Existing accounts remain intact, and this practice account has ordinary non-administrative groups:

```nix
# Optional non-administrative account with credentials managed outside source.
{ ... }:
{
    users.users.learner = {
        isNormalUser = true;
        description = "Practice account";
    };
}
```

Each selected optional module in this stage enters the existing `flake.nix` modules list as `./modules/NAME.nix`, alongside all current entries. Stage 7's inspection, build, and deliberate activation precede account use. Once the account exists under mutable user management, set its password interactively with this authorized **SYSTEM CHANGE** from any directory. If you substituted another account name, use it here too. For an existing immutable-account policy, use its documented password-file options and established secret-management process instead; the mutable-account procedure does not establish compatibility with that policy.

```bash
sudo passwd learner
```

Interactive entry keeps credentials out of source and the store. The optional login is separate from the existing administrator access.

### Separating networking policy from service experiments

Keep network changes separate from a service experiment, especially when administering a remote machine. The installed backend, interfaces, Wi-Fi credentials, firewall policy, and hostname remain the baseline. A deliberately selected networking backend and a coordinated migration avoid competing configuration owners. `networking.hostName` is separate from the flake selector; hostname changes can affect applications and remote access.

A service package and its OS integration have different roles. OpenSSH enablement starts an SSH server after activation, while authentication and firewall exposure require independent review. `openFirewall = false` prevents the SSH module's automatic allow rule; separately configured allow rules can still expose the service. The [NixOS networking and configuration manual](https://nixos.org/manual/nixos/stable/) supplies the system context.

Before changing passwords or keys, verify an alternate login. If administering remotely with no local access, arrange recovery access before experimenting with accounts, networking, or SSH. Reconcile any existing SSH settings before adding this module to the list.

Once you've reviewed authentication and the existing firewall rules, you can make this optional **SOURCE EDIT** using the complete module below in `/etc/nixos/modules/ssh.nix`:

```nix
# SSH integration with automatic firewall opening disabled.
{ ... }:
{
    services.openssh = {
        enable = true;
        openFirewall = false;
    };
}
```

### Inspecting services and selecting an optional desktop

After authorized SSH activation, service status and recent logs reveal actual behavior. Additional log privileges require corresponding authorization. Logs can expose hostnames, addresses, and other private details, so shared excerpts require redaction.

Once SSH is enabled, check its current status and then inspect the recent log entries for this boot. These **READ-ONLY** commands work from any directory:

```bash
systemctl status sshd
journalctl -u sshd -b --no-pager -n 50
```

A desktop is a separate integration decision, not just a package-list entry. If a graphical host needs GNOME, NixOS 26.05 uses `services.desktopManager.gnome.enable` and `services.displayManager.gdm.enable`. Check the option names for the selected release; see [GNOME enablement](https://nixos.org/manual/nixos/stable/#sec-gnome-enable). Keep the current display manager until a deliberate migration, and leave GPU and display-driver settings machine-specific.

Keep desktop inclusion, building, and activation separate from networking and accounts. Large downloads and graphical-session disruption are possible, so arrange a recovery console before proceeding. Leave a headless host on its existing server/console configuration.

For a reviewed GNOME choice, this optional **SOURCE EDIT** is the complete `/etc/nixos/modules/desktop.nix`:

```nix
# GNOME and display-manager integration with machine-specific hardware settings.
{ ... }:
{
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;
}
```

### Practice: analyzing SSH exposure

You set `services.openssh.openFirewall = false;`. Does that make SSH unreachable from every remote host? Explain which automatic rule the setting prevents and how binding, independently configured firewall rules, upstream networking, and authentication still matter.

Not necessarily. The SSH module adds no automatic firewall opening. Existing separate allow rules remain effective, and upstream isolation is a separate property. Reviewed firewall/network exposure and observed authentication/access establish the actual boundary.

</details>

## 9. Updating inputs and planning release upgrades

<details>
<summary>Read this section</summary>

### Refreshing pins as a separate maintenance step

Treat an input refresh as its own source change so you can review it before rebuilding or activating. Modern `nix flake update` accepts **input names** as positional arguments. The current directory selects the flake unless `--flake` supplies another location. The command changes `flake.lock`, not the branch request in `flake.nix`, and leaves OS activation unchanged. Omitting input names refreshes all inputs. In contrast, `nix flake lock` fills missing or changed-request entries without intentionally refreshing every valid pin. The [update](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html) and [lock](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html) references specify these distinctions.

Channels, user profiles, and the OS flake lock have separate update workflows. The system flake's input revisions are refreshed through its own `nix flake update` operation.

Both alternatives below are **SOURCE EDIT plus input fetching**. Run the one that matches your intent from any directory with authorized source-write access. In each, `--flake path:/etc/nixos` names the source location; a positional argument names an input.

Refresh only `nixpkgs`:

```bash
nix flake update nixpkgs --flake path:/etc/nixos
```

Or refresh every input:

```bash
nix flake update --flake path:/etc/nixos
```

These have the same scope only while the spine has one input. Compare the old and new lock revisions to confirm the intended changes and build the candidate before deciding whether to activate.

### Pinning and restoring coherent source

When diagnosing a regression, keep the source and lock together so you can reproduce the candidate you meant to test. A branch request already resolves to an exact lock revision. A known-good record therefore includes compatible source and lock files. Restoring only the lock leaves source changes, such as a newly enabled service, intact. Full behavior restoration requires the relevant source and lock data from known-good backup/history.

An explicit source pin uses `github:NixOS/nixpkgs/COMMIT`, where `COMMIT` is a verified full revision from the known-good lock or upstream repository. The changed request requires locking, inspection, and another build. A held pin can exclude security fixes, so its maintenance policy includes a review date or process. The [flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) covers source references and resolved locks.

For example, a release-branch policy accepts new `nixos-26.05` lock revisions after review. A regression-investigation policy holds a known-good commit temporarily. Both retain the installed `system.stateVersion`. After a deliberate source edit, resolve the request with authorized source-write access from any directory (**SOURCE EDIT plus fetching**):

```bash
nix flake lock path:/etc/nixos
```

Record the dependency tree you intend to use, why you picked that pin, and when or how you will reconsider it, alongside the compatible source.

### Planning release transitions separately

Plan a branch transition separately: it can change options, packages, and persistent service data formats. Current/target release notes and service-specific upgrade instructions establish the transition requirements. Verified backups, free space, a known-good boot generation, and recovery access precede a branch change. The transition then consists of editing `inputs.nixpkgs.url`, refreshing the intended lock entry, inspecting warnings, building, and separately scheduling activation or reboot. Remote-only upgrades require verified recovery access in advance.

The installed `system.stateVersion` remains unchanged unless a separately documented state migration requires otherwise. It protects compatibility defaults rather than freezing packages. Stable branches receive maintenance changes; unstable can involve broader changes, and both can contain bugs. The [upgrade manual](https://nixos.org/manual/nixos/stable/#sec-upgrading) and [release notes](https://nixos.org/manual/nixos/stable/release-notes.html) provide the authoritative starting requirements.

Adapting this tutorial to another installed release's maintained branch preserves that release. Moving the machine to 26.05 is a separate upgrade objective with its own prerequisites and reviewed branch edit.

### Practice: identifying an update's changed artifact

`nix flake update nixpkgs --flake path:/etc/nixos` finishes, but `flake.nix` still requests the same branch. Which file changed, and what review, build, and activation decisions remain before a new system is running?

`flake.lock` records the updated resolution. The branch request in `flake.nix` and OS activation remain unchanged. Pin review and system building precede a deliberate activation-mode selection.

</details>

## 10. Recovery and garbage collection

<details>
<summary>Read this section</summary>

### Generations and rollback boundaries

First identify what you need to recover: selected software, the source that produced it, or mutable data. NixOS retains system generations, often selectable through the bootloader. Modern user profiles retain separate versions. Retained store results permit selection of an earlier environment without rebuilding every artifact; they are not snapshots of every disk or process.

OS rollback selects earlier software and generated system configuration. Configuration source, including `configuration.nix` and `flake.lock`, requires separate restoration from known-good history. Documents, databases, passwords, and other mutable state require independent backups and recovery procedures. An older service can be incompatible with a migrated database.

Atomic package-environment pointer selection is narrower than system activation, service restarts, and data migrations, which can have partial or persistent effects. The [profile explanation](https://nix.dev/manual/nix/stable/package-management/profiles.html) describes that narrower selection mechanism.

On the documented NixOS interface, inspect the machine's generation history from any directory (**READ-ONLY**):

```bash
nixos-rebuild list-generations
```

The inspected machine history identifies actual generation numbers. A recorded known-good target is a generation that has been tested, rather than simply an older number.

Record that fallback separately from the source and data backups.

### Recovering running and unbootable systems

Choose a recovery path that works even if the candidate source cannot evaluate. A usable system can select a suitable previous generation through rollback. A broken boot can instead use a retained older generation through the installed bootloader's documented menu and keys. Where no retained generation boots, suitable recovery media and official recovery/install guidance apply to the verified storage layout, preserving data and using actual disk identifiers.

After runtime recovery, source and lock repair precede the next ordinary rebuild; otherwise the failed candidate can recur. Errors and logs remain useful diagnostic evidence. Partial activation requires explicit service inspection because failure does not imply unchanged runtime state. The [rebuild recovery guidance](https://wiki.nixos.org/wiki/Nixos-rebuild) supplements the primary [NixOS manual](https://nixos.org/manual/nixos/stable/), which takes precedence over dated examples.

If the system is usable and the previous system generation is your intended target, use authorized administration for this **SYSTEM CHANGE** from any directory:

```bash
sudo nixos-rebuild switch --rollback
```

A user-profile mistake has a different path: inspected `nix profile history` and normal-user `nix profile rollback`. That operation affects the user selection rather than OS boot, services, or networking.

### Garbage collection and history retention

Before reclaiming space, decide how much recovery history you need to retain. A **garbage-collection root** keeps a store object and its references reachable. Current and retained profile generations can provide roots. A removed package selection can remain reachable through an older generation or another dependency. Garbage collection removes unreachable store paths; generation deletion can make additional paths unreachable and eliminate rollback choices. A `--no-link` build avoids a local result link but may lack a persistent root.

Inspection of reachability and recovery requirements precedes cleanup. Known-good generations remain useful recovery assets, particularly during learning. `nix-collect-garbage -d` combines broad deletion of old profile generations with collection; that deliberate retention-policy decision can remove rollback targets. The official references cover [GC concepts](https://nix.dev/manual/nix/stable/package-management/garbage-collection.html), [`nix store gc`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-store-gc.html), and [`nix-collect-garbage`](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage.html).

Preview collection from any directory (**READ-ONLY inspection**):

```bash
nix store gc --dry-run
```

After reviewing reachability, retained generations, and recovery requirements, optionally collect unreachable paths from any directory (**SYSTEM CHANGE: store deletion**). The account needs whatever cleanup authorization the installed Nix setup requires:

```bash
nix store gc
```

Collection removes unreachable paths. Retained generations still provide roots, which can explain continued disk use. Removing that history is a separate retention decision with consequences for rollback.

### Practice: matching recovery assets to state

A service upgrade migrated its database, and the older service cannot read the new format. Does booting an older generation recover the data? Identify the service-specific recovery procedure and backup you would need separately from the software rollback.

Not by itself. The older generation restores selected software and generated configuration. Database recovery requires the service's documented migration/recovery procedure and a suitable data backup. Separate source/lock restoration ensures that the next rebuild describes the intended recovered system.

</details>

## 11. Extending the flake with development tools

<details>
<summary>Read this section</summary>

### Adding a development shell

Give a project its own tool environment without adding those tools to the system package list. `pkgs.mkShell` describes a development environment; `packages` supplies executable tools. `nix develop` enters the selected environment. Shell programs retain normal user file/network permissions. A `shellHook` executes on entry with those same permissions and can write files or run arbitrary commands. Tool-input pins do not replace separate pins for language package-manager dependencies and the project checkout. The [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/) documents `pkgs.mkShell`, and the [`develop` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-develop.html) covers entry behavior.

For this **SOURCE EDIT**, use the complete extended `/etc/nixos/flake.nix` below. Keep your verified platform, chosen branch/pin, and deliberately selected optional modules; the displayed module list is the minimal spine:

```nix
# One pinned Nixpkgs source for the system and explicit development package set.
{
    description = "Progressive NixOS configuration";
    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # System, package, and shell outputs for one selected platform.
    outputs = { self, nixpkgs, ... }:
        let
            system = "REPLACE_WITH_SYSTEM";
            pkgs = import nixpkgs {
                inherit system;
                config = {};
                overlays = [];
            };
        in
        {
            nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                    ./configuration.nix
                    ./modules/nix-cli.nix
                    ./modules/cli-tools.nix
                ];
            };

            packages.${system}.default = pkgs.hello;
            devShells.${system}.default = pkgs.mkShell {
                packages = [ pkgs.git pkgs.hello ];
            };
        };
}
```

`import nixpkgs { inherit system; config = {}; overlays = []; }` evaluates the locked source for the selected platform. Explicit `config` and `overlays` make this standalone package set independent of ambient user configuration, following the [official best-practices guide](https://nix.dev/guides/best-practices#nixpkgs-config). The NixOS module system configures its own package set independently. Existing NixOS configuration and overlays remain intact; stage 12 explains deliberate system customization and explicit overlay sharing.

The wrapper now exposes a platform-specific package and development shell while the NixOS module system retains ownership of its own package set.

### Entering and leaving the shell

A development shell changes which tools are available, not how long your files live. `nix develop` selects `devShells.<system>.default` before falling back to a package's build environment. Tools and build-related environment variables become available inside the shell. The current directory and ordinary file permissions still apply. `exit` returns to the outer shell, while created or modified files persist. Repeatable tool selection and project-state cleanup are separate responsibilities.

After reviewing the flake and its hooks, enter the environment as a normal user from any directory (**BUILD-ONLY plus interactive shell execution**):

```bash
nix develop --no-update-lock-file path:/etc/nixos
```

Inside that environment, trusted-tool version inspection is **READ-ONLY program inspection**; the final command leaves the shell:

```bash
hello --version
git --version
exit
```

An actual application project normally owns its own flake and lock in the project directory. `/etc/nixos` supplies a continuous learning example here rather than ownership of every application's dependencies.

There is no OS rebuild: the tools are available inside the shell, and leaving it restores the outer environment without discarding your work.

### Building and running named outputs

Choose a command based on what you want from the output. `nix build` realizes packages. `nix run` prefers an app when present and otherwise runs a suitable package executable. `nix develop` supplies a development/build environment. The [`run`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html) reference specifies its behavior.

Run either operation from any directory. Neither changes NixOS activation.

**BUILD-ONLY — realize the default package** and print its store path without creating a local link:

```bash
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#default
```

**BUILD-ONLY plus application execution — run the default output** if you trust the selected source and executable. Here the package fallback executes Hello with the supplied greeting:

```bash
nix run --no-update-lock-file path:/etc/nixos#default -- --greeting 'One flake, several outputs'
```

### Practice: selecting a development interface

You want to run Hello once, realize its artifact without creating a result link, and enter the declared environment with several tools. Which command fits each task, and which one starts a shell?

`nix run --no-update-lock-file path:/etc/nixos#default` performs single execution. `nix build --no-link --no-update-lock-file path:/etc/nixos#default` prepares the artifact. `nix develop --no-update-lock-file path:/etc/nixos` enters the declared shell. All can fetch or build; run and develop additionally execute code with the invoking user's permissions.

</details>

## 12. Reusing modules and customizing package sets

<details>
<summary>Read this section</summary>

### Declaring a reusable module interface

Use a documented option to share tool policy without sharing hardware settings. A reusable module declares an interface and conditionally supplies definitions. `lib.mkEnableOption` creates a documented Boolean switch. `lib.mkIf` delays conditional definitions in the form expected by the module system, avoiding common recursion from whole-configuration conditionals. `config` denotes merged configuration rather than a file-local mutable object. The manual explains [module construction](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

For this **SOURCE EDIT**, use the complete `/etc/nixos/modules/common-tools.nix`:

```nix
# Reusable opt-in command-line tool selection.
{ config, lib, pkgs, ... }:
{
    options.tutorial.commonTools.enable = lib.mkEnableOption "the shared tutorial tools";

    # Conditional tools controlled by the module's public option.
    config = lib.mkIf config.tutorial.commonTools.enable {
        environment.systemPackages = [ pkgs.hello pkgs.git ];
    };
}
```

The existing flake output set gains `nixosModules.commonTools = import ./modules/common-tools.nix;`. In the `workstation` modules list, `self.nixosModules.commonTools` replaces `./modules/cli-tools.nix`; a separate inline item `{ tutorial.commonTools.enable = true; }` enables it. `./configuration.nix`, `./modules/nix-cli.nix`, and any selected optional modules remain included.

This replacement retains a single owner for shared tool definitions. The old unreferenced file has no module effect and can remain in source pending a deliberate removal decision.

### Package overrides and package-set overlays

Decide whether to customize one result or change what a package set supplies to its consumers. `package.override` changes arguments accepted by that recipe's function; the inspected recipe determines valid arguments. `package.overrideAttrs` changes attributes supplied through the derivation helper and returns a new derivation. An **overlay** is a function `final: prev: { ... }` extending a package set. `prev` represents the prior set; `final` represents the final composition. Original-package references through `prev` avoid defining a package recursively in terms of itself. Dependencies of a customized package usually come from `final`.

Overlay order affects composition and downstream rebuilds. NixOS definitions instead merge by option types and priorities. The official [overrides chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overrides.chapter.md) and [overlays chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overlays.chapter.md) define the package interfaces.

For this optional **SOURCE EDIT**, use the complete `/etc/nixos/modules/package-customization.nix`:

```nix
# NixOS package-set customization retaining the original package recipe.
{ ... }:
{
    nixpkgs.overlays = [
        # Renamed Hello derivation with original recipe inputs retained.
        (final: prev: {
            hello = prev.hello.overrideAttrs (old: {
                pname = "${old.pname}-tutorial";
            });
        })
    ];
}
```

Optional inclusion in the workstation modules list applies the experiment to the system package set. The executable remains `hello`; only a derivation name changes, not the source version. A local alternative, `pkgs.hello.overrideAttrs (old: { pname = "${old.pname}-tutorial"; })`, customizes a single selection. Neither mechanism is an option-priority override such as `mkForce`.

The stage 11 shell uses a separately imported `pkgs` with explicit configuration and overlays. Sharing the customization requires passing the same reviewed overlay explicitly to that import. Each independently constructed package set owns its overlay selection.

### Sharing policy while retaining machine-specific hardware

Share software policy, but keep hardware and boot settings with the machine that owns them. `nixosModules.commonTools` exports a building block; `nixosConfigurations.workstation` exports a complete system. A third-party module has an effect only after import into a composition. A third-party complete system can encode unsuitable hardware assumptions. Native references can directly build, run, or add packages, whereas reusable OS modules require deliberate composition.

For an additional input illustratively named `desktop`, `inputs.desktop.inputs.nixpkgs.follows = "nixpkgs";` aligns that input with the existing Nixpkgs input. The real input name determines the path. This is optional dependency alignment, not mandatory boilerplate, and compatibility requires verification before imposition. The [flake concepts guide](https://nix.dev/concepts/flakes.html) and [output/reference contract](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) explain these interfaces.

For illustration, a future fictional `travel` host would add `nixosConfigurations.travel` through `nixpkgs.lib.nixosSystem`, leaving `workstation` unchanged. Its composition requires that host's verified platform and complete configuration, for example `./hosts/travel/configuration.nix`, with its hardware imports inside the source tree. Shared entries can include `nix-cli.nix`, `self.nixosModules.commonTools`, and `{ tutorial.commonTools.enable = true; }`. Hardware and boot settings remain owned by the travel machine's configuration.

This is an incomplete composition plan until the actual second host's hardware configuration and platform are available. The working one-machine spine remains the usable configuration meanwhile. Remote deployment, cross-compilation, package-language build helpers, custom kernels, image generation, secret-management integrations, and Home Manager are later specializations requiring a demonstrated need and their own prerequisites. Home Manager is a separate project, not a prerequisite for user profiles or NixOS.

### Practice: matching abstractions to responsibilities

You want to share SSH policy between machines, rename one Hello derivation for an experiment, and replace a library consistently across a package set. Which mechanism fits each task, and how far could each change reach when you rebuild?

A reusable NixOS module owns service policy. `overrideAttrs` customizes the single derivation. A deliberately scoped overlay supplies the package-set-wide replacement. Any use of `override` depends on the actual recipe's accepted arguments rather than assumed generic parameters.

</details>

## 13. Systematic diagnosis and next-step selection

<details>
<summary>Read this section</summary>

### Reading errors at the relevant layer

Classify the failure before changing anything else so you don't lose the first useful evidence. The final meaningful error and its file/line identify a starting point; preceding context explains how evaluation reached it. Syntax errors, missing attributes, unknown options, type mismatches, conflicting definitions, and recursion belong to evaluation. Fetching, compilation, and resource limits can fail after recipes exist. Activation/runtime failures require service logs, access verification, and possibly recovery rather than an arbitrary input refresh.

A trace can name Nixpkgs internals where a module's value was consumed, even when the actionable error belongs to the local module. `--show-trace` expands context without supplying an automatic diagnosis. The [`eval` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html) and [module semantics](https://nixos.org/manual/nixos/stable/#sec-writing-modules) explain the underlying boundaries.

To expand the trace while inspecting the selected hostname, run this from any directory (**READ-ONLY with evaluation/cache caveats**):

```bash
nix eval --show-trace --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

`enable = "true";` supplies a string where `enable = true;` supplies a Boolean. An “option does not exist” error can indicate a release-specific name, a missing declaring-module import, or a spelling error. The correction belongs at the owning declaration, import, or definition established by that evidence.

### Narrowing changes and bisecting candidates

Reduce the candidate to a small, coherent difference that explains the behavior. A known-good source/lock pair and a failure record separate configuration changes from input changes. New source with old pins and unchanged source with new pins test different hypotheses. The established backup/history workflow restores coherent test states. Separate reviewed changes to packages, services, networking, and release branches preserve attribution.

**Bisection** tests roughly half the candidate changes, then narrows to the half associated with failure. Required hardware/base configuration remains intact. Evaluation and build verification precede controlled activation candidates with recovery access. Runtime-only symptoms require state-aware testing in a controlled recovery environment. Failure can arise from an incompatible combination rather than one defective line.

Suppose evaluation fails after three optional modules are added to a previously buildable system. Omitting only the new optional imports retains the installed core; incremental reintroduction isolates the earliest failure. A failed-service symptom instead calls for its logs, because build success and runtime failure implicate different boundaries.

Record the smallest reproducible source/input difference and the observation that distinguishes passing from failing candidates.

### Symptom-based boundary inspection

Use the table to pick a first inspection for the symptom you see. The entries point to evidence, not automatic remedies:

| Symptom | Initial bounded evidence |
| --- | --- |
| File missing from a store source snapshot | Import path, source-root boundary, and Git-index membership for Git-backed references. |
| Dirty-source warning | Intended tracked edits; dirty tracked content is normally included. |
| Unexpected package version | Selected flake/pin and executable ownership by a profile or shell. |
| Channel update leaves the system unchanged | Whether the active system build consumes the flake lock instead of the channel. |
| Conflicting definitions | Both owners, the option type, and effective priority before any override decision. |
| Infinite recursion | Self-dependency or a whole-module conditional on constructed configuration; the documented `mkIf` pattern. |
| Slow fetch or build | Cache/network availability, actual logs, architecture, resources, and foundational overrides. |
| Build success with service failure | Activation output, `systemctl status`, and the service journal. |
| Source-write permission failure | Authorized editing access with existing ownership and modes retained. |
| Disk usage retained after package removal | Generations and store reachability before a deletion decision. |

The [next-step plan](#appendix-c-next-step-plan) resumes the learning sequence after diagnosis.

A concise change record contains the intended result, changed files, input revision, evaluation/build result, activation mode, runtime inspection, and recovery target. A shareable diagnostic excerpt includes versions, relevant configuration, the exact error, and prior working behavior, with secrets and private details redacted.

### Practice: diagnosing runtime failure before further changes

Your changed SSH configuration builds successfully, but remote login fails. What three runtime observations would help narrow the cause, and what recovery access would you keep available? Explain why refreshing every flake input would not establish the cause of this failure.

A working console or alternate login remains available. Activation output, `systemctl status sshd`, and the service journal provide three immediate observations. Binding, firewall, authentication, and network reachability then narrow the relevant boundary. Updating unrelated inputs adds uncertainty without establishing the login failure's cause.

</details>

## Appendix A. Command reference by task

<details>
<summary>Read this section</summary>

### Selecting operations by intended effect

Use the table to find the operation you intend, then read its owning stage for the full prerequisites and safety context. The commands below are individual lookups, not a script.

For ordinary-user examples, complete the [one-time user Nix setup](#evaluation-before-building); NixOS activation is not required. Administrative examples still require authorization. If the account running the first privileged flake rebuild lacks the features, see the [bootstrap note in stage 7](#choosing-an-activation-mode).

The examples assume placeholders have been verified and substituted and the `/etc/nixos` source tree has been checked for secrets. Operations that consume an existing lock assume the pins are already in place. Explicit source references work independently of the working directory.

| Task | Effect | Stage |
| --- | --- | --- |
| Installed-version inspection | READ-ONLY | [1](#1-scope-safety-and-the-mental-model) |
| Selected-hostname inspection | READ-ONLY with evaluation/fetch/cache caveats | [6](#6-wrapping-the-existing-system-in-one-flake), [13](#13-systematic-diagnosis-and-next-step-selection) |
| System realization without a local link | BUILD-ONLY | [7](#7-building-testing-and-activating-the-system) |
| Immediate candidate activation with prior boot default retained | SYSTEM CHANGE | [7](#7-building-testing-and-activating-the-system) |
| Next-boot candidate selection only | SYSTEM CHANGE | [7](#7-building-testing-and-activating-the-system) |
| Immediate activation and default-boot selection | SYSTEM CHANGE | [7](#7-building-testing-and-activating-the-system) |
| Missing-pin resolution | SOURCE EDIT plus fetching | [6](#6-wrapping-the-existing-system-in-one-flake) |
| Input refresh | SOURCE EDIT plus fetching | [9](#9-updating-inputs-and-planning-release-upgrades) |
| Profile inspection, addition, removal, or upgrade | READ-ONLY or USER-PROFILE CHANGE | [5](#5-choosing-package-scope) |
| Earlier OS-generation selection | SYSTEM CHANGE | [10](#10-recovery-and-garbage-collection) |
| Development-shell entry or program execution | BUILD-ONLY plus execution | [11](#11-extending-the-flake-with-development-tools) |
| GC preview or unreachable-path collection | READ-ONLY or SYSTEM CHANGE: store deletion | [10](#10-recovery-and-garbage-collection) |

**Inspect installed versions — READ-ONLY (stage 1)**

Check Nix on any supported host with Nix installed:

```bash
nix --version
```

On NixOS, check the OS release:

```bash
nixos-version
```

**Inspect the selected hostname — READ-ONLY (stages 6, 13)**

Evaluation can fetch inputs, write caches or store metadata, or trigger import-from-derivation builds. Inspection fails if the lock needs to change:

```bash
nix eval --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

**Inspect user selections — READ-ONLY (stage 5)**

Use the ordinary account whose profile you want to inspect. To list current selections:

```bash
nix profile list
```

To inspect that account's profile history, including before a rollback:

```bash
nix profile history
```

**Inspect system history or runtime — READ-ONLY (stages 7, 10)**

To check retained system generations on NixOS:

```bash
nixos-rebuild list-generations
```

After activation, to look for failed system units:

```bash
systemctl --failed
```

**Realize the system — BUILD-ONLY (stage 7)**

As a normal user, build or fetch the selected system and print its store path without a local result link or a change to OS activation:

```bash
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel
```

**Choose an activation mode — SYSTEM CHANGE (stage 7)**

Choose **one** with authorized administration, local console/recovery access, backups, and the reviewed source/lock pair unchanged. Immediate activation can restart services, drop connections, or cause persistent writes or migrations that booting the previous default does not undo. If activation fails partway through, inspect runtime state and follow the recovery plan; service changes may already have occurred.

Standard NixOS enables `sudo` by default, but it still requires authorization; this repository's desktop preset disables it. If a root password is available, use authorized `su -`, omit `sudo` only for administrative examples, then `exit` the root shell after the admin work (see stage 1). Do not run unprivileged commands as root.

To activate now without changing the boot default:

```bash
sudo nixos-rebuild test --flake path:/etc/nixos#workstation
```

To change the boot default without activating now:

```bash
sudo nixos-rebuild boot --flake path:/etc/nixos#workstation
```

To activate now and change the boot default:

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#workstation
```

**Maintain pins — SOURCE EDIT plus fetching (stages 6, 9)**

Use authorized source-write access. To fill missing or changed-request lock entries without deliberately refreshing every valid pin:

```bash
nix flake lock path:/etc/nixos
```

To refresh just the `nixpkgs` pin instead, run the following command. Review the resulting lock changes and build before deciding whether to activate.

```bash
nix flake update nixpkgs --flake path:/etc/nixos
```

**Change user selections — USER-PROFILE CHANGE (stage 5)**

Run as the ordinary user whose profile you intend to change. These operations do not change the OS generation. For removal and upgrade, replace `PROFILE_NAME` with the exact name from `profile list`.

To add Hello from the referenced source you trust:

```bash
nix profile add github:NixOS/nixpkgs/nixos-26.05#hello
```

To remove a selection:

```bash
nix profile remove PROFILE_NAME
```

To upgrade a selection following its reference (a locked commit does not move automatically):

```bash
nix profile upgrade PROFILE_NAME
```

To roll back only if profile history confirms the most recent older version is the intended target:

```bash
nix profile rollback
```

**Recover the previous OS selection — SYSTEM CHANGE (stage 10)**

Use authorized administration on a usable system if the previous system generation is the intended recovery target. Source and data restoration are separate:

```bash
sudo nixos-rebuild switch --rollback
```

**Enter a shell or run a program — BUILD-ONLY plus execution (stage 11)**

As a normal user, use trusted outputs. Programs and hooks have the invoking user's normal file and network access.

To enter the reviewed development shell:

```bash
nix develop --no-update-lock-file path:/etc/nixos
```

To execute the default app or suitable package executable instead:

```bash
nix run --no-update-lock-file path:/etc/nixos#default
```

**Preview or collect unreachable paths — stage 10**

**READ-ONLY:** Preview collection before making a deletion decision:

```bash
nix store gc --dry-run
```

**SYSTEM CHANGE: store deletion.** Only after reviewing reachability, retained generations, and recovery requirements, optionally collect unreachable paths with the authorization required by the installed setup:

```bash
nix store gc
```

</details>

## Appendix B. Glossary

<details>
<summary>Read this section</summary>

### Connecting terminology to the mental model

Use the glossary to connect each term to its role in source, storage, selection, or runtime.

| Term | Meaning |
| --- | --- |
| Activation | Application of a built system to running OS state, including possible service and mutable-data effects. |
| Attribute | A named field, such as `name` in `{ name = "Learner"; }`. |
| Attribute set | A collection of named values. |
| Closure | A store object and all store objects it references transitively. |
| Declarative | A desired result described in source rather than only a sequence of immediate changes. |
| Derivation | A structured build recipe; informally, its Nix-language representation. |
| Evaluation | Computation of values from expressions, distinct from ordinary package building and activation. |
| Flake | A source tree with a standardized inputs/outputs entrypoint. |
| Generation | A retained profile selection/version; an OS generation is not a data snapshot. |
| GC root | A reference that keeps store objects reachable and protected from collection. |
| Imperative | An immediate incremental change request, such as profile-package addition. |
| Input | A dependency supplied to a flake or build, according to context. |
| Lazy | Evaluation when values are needed, potentially delaying work and errors. |
| Lock file | Recorded resolved flake inputs rather than a backup of complete machine state. |
| Module | A composable declaration/definition unit evaluated by the NixOS module system. |
| Nixpkgs | Package definitions and libraries from a selected source tree. |
| Option | A typed declared configuration interface whose definitions supply values. |
| Output | A derivation result or a named flake result, two related but distinct meanings. |
| Overlay | A function extending or replacing entries in a package set. |
| `pkgs` | The conventional name for a selected package set. |
| Profile | A selected package environment with history, separate from configuration source. |
| Pure flake evaluation | Evaluation constrained to declared/captured inputs rather than arbitrary host context. |
| Realization | Acquisition of required store outputs by fetching or building. |
| Store | Nix-managed artifact storage, normally `/nix/store`, generally readable by local users and unsuitable for secrets. |
| Substitute | A prebuilt store result obtained from a configured cache. |
| `system` | Commonly a platform pair such as `aarch64-linux`, distinct from `system.stateVersion`. |

For example, evaluating a flake computes a description, realizing the system output obtains artifacts, and activation applies changes to the running system. Each term marks a different transition.

</details>

## Appendix C. Next-step plan

<details>
<summary>Read this section</summary>

### Progressing through one responsibility at a time

Work on one machine and one purpose at a time. Small changes you understand make it easier to tell what produced the result:

1. A small package-selection change combines source inspection and building before an activation decision.
2. A small service change combines available recovery access with observation of actual runtime behavior.
3. An input refresh receives source/lock review and a build, with activation scheduled separately.
4. Recovery rehearsal on a noncritical system distinguishes software selection from data restoration.
5. A reusable module follows a second current consumer of the same policy. Package customization follows recipe inspection, and additional tools follow an understood ownership need.

Before each change, record the intended result, source files and pins, what you'll observe to verify success, whether you'll activate, and what recovery target you can use. The owning stage gives the operation and its prerequisites.

</details>

## Appendix D. Sources and evidence limits

<details>
<summary>Read this section</summary>

### Selecting version-matched references

Start with the installed version: a stable documentation URL can advance, while the interfaces and release requirements you need depend on what is actually installed. Project-maintained manuals and official source-tree documentation specify the interfaces used in the examples. Project-hosted community wiki material supplies supplementary examples whose release and date require comparison with the primary manuals. The tutorial's `modules/` layout, explicit `path:` references, and small reviewed changes form a consistent learning workflow.

The links next to the examples identify the relevant interface contracts; consult the version that matches your installation.

For example, the configuration manual describes `test` as activation of candidate services while retaining the existing boot default. Stage 7 separates build review from that activation and its persistent-state risks.

### Official documentation by subject

Use these primary references when you need the full syntax, source-selection rules, command effects, or release requirements beyond this worked configuration. For upgrades, consult the release-note sections for your actual current and target versions. Where dated wiki examples differ, follow the applicable primary manual.

- Language: [nix.dev language basics](https://nix.dev/tutorials/nix-language.html); [best practices](https://nix.dev/guides/best-practices).
- Flakes: [concepts, tradeoffs, and alternatives](https://nix.dev/concepts/flakes.html); [Nix flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).
- Store recipes and selection: [derivations](https://nix.dev/manual/nix/stable/language/derivations.html); [profiles](https://nix.dev/manual/nix/stable/package-management/profiles.html).
- NixOS: [stable manual](https://nixos.org/manual/nixos/stable/); [release notes](https://nixos.org/manual/nixos/stable/release-notes.html). The actual release section specifies upgrade requirements.
- Nixpkgs: [stable manual, including `mkShell`](https://nixos.org/manual/nixpkgs/stable/); [26.05 overlays chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overlays.chapter.md); [26.05 overrides chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overrides.chapter.md).
- Profile CLI: [add](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-add.html), [list](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-list.html), [remove](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html), [upgrade](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-upgrade.html), [history](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-history.html), [rollback](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-rollback.html).
- Tool/build CLI: [shell page (`nix env shell`, with `nix shell` examples)](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-env-shell.html), [build](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-build.html), [develop](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-develop.html), [run](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html), [eval](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html).
- Lock CLI: [update](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html), [lock](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html).
- Cleanup: [GC explanation](https://nix.dev/manual/nix/stable/package-management/garbage-collection.html), [store GC](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-store-gc.html), [collect-garbage](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage.html).
- Secondary official community wiki: [Nixos-rebuild](https://wiki.nixos.org/wiki/Nixos-rebuild), [Flakes](https://wiki.nixos.org/wiki/Flakes). The applicable primary manual takes precedence over dated wiki notes.

</details>
