# NixOS, progressively: from first principles to reusable systems

## 1. Scope, safety, and the mental model

### The scope of “zero to hero”

**Rationale:** A useful learning path establishes its destination and operational boundaries before introducing system changes.

**Explanation:** This tutorial develops Nix language, functional-programming, and declarative-configuration concepts from first principles. “Hero” denotes practical competence with a modest NixOS configuration: explaining its structure, inspecting inputs, changing source, building results, activating changes, updating dependencies, recovering earlier selections, and sharing modules. Further specialization rests on those skills and release-matched references.

The system examples begin with an **already installed NixOS machine**. Installation, partitioning, bootloader selection, hardware drivers, and migration from another distribution require machine-specific decisions covered by the [official NixOS manual](https://nixos.org/manual/nixos/stable/). Package and language exercises also apply on other supported systems with Nix installed; NixOS activation requires a NixOS host.

The reference baseline is **NixOS 26.05 and Nix 2.34.9**, dated **2026-11-14**. Installed versions determine the applicable manuals and option names. Maintaining the installed release branch and planning a release upgrade are separate choices.

**Example:** **READ-ONLY**, from any directory. The commands report the installed Nix and NixOS versions; the second applies to NixOS:

```bash
nix --version
nixos-version
```

**Expectation:** The installed versions establish whether the system stages apply and which release documentation governs subsequent operations.

### Source, store, selection, and runtime

**Rationale:** Package existence, package availability, and a running service represent different states.

**Explanation:** **Source describes a desired result; Nix prepares artifacts in the store; profiles and activation determine availability and running-system effects.** A text edit changes source. Downloading or building obtains artifacts. Updating a pin changes a selected input revision. Declared service enablement reaches the running machine through system activation.

A recipe book, a pantry of prepared dishes, and a selected menu illustrate description, storage, and selection. The analogy has a boundary: computers also contain mutable files, processes, devices, and databases. Their persistence and recovery require separate arrangements. The [derivation reference](https://nix.dev/manual/nix/stable/language/derivations.html) explains build descriptions; the [NixOS configuration manual](https://nixos.org/manual/nixos/stable/#sec-changing-config) explains activation.

**Example:** A package list changes in a text editor while the existing terminal and services retain their state. Building prepares the new result. Activation applies the chosen system configuration separately.

**Expectation:** An operation can be classified as a source change, artifact preparation, profile selection, or operating-system activation without conflating those transitions.

### Progressive roadmap and operational prerequisites

**Rationale:** Dependencies, working locations, and effects determine whether an example is appropriate for a particular system.

**Explanation:** The learning sequence progresses through [the mental model](#1-scope-safety-and-the-mental-model), [evaluation](#2-components-and-first-expression-evaluation), [the language](#3-reading-the-nix-language), [installed modules](#4-inspecting-installed-configuration-and-modules), [package scope](#5-choosing-package-scope), [the flake spine](#6-wrapping-the-existing-system-in-one-flake), [activation](#7-building-testing-and-activating-the-system), [optional system services](#8-accounts-networking-services-and-an-optional-desktop), [updates](#9-updating-inputs-and-planning-release-upgrades), [recovery](#10-recovery-and-garbage-collection), [development tools](#11-extending-the-flake-with-development-tools), [reuse](#12-reusing-modules-and-customizing-package-sets), and [diagnosis](#13-systematic-diagnosis-and-next-step-selection). Advanced stages extend the same small configuration. The appendices provide a [task command reference](#appendix-a-command-reference-by-task), [glossary](#appendix-b-glossary), [next-step plan](#appendix-c-next-step-plan), and [official sources](#appendix-d-sources-and-evidence-limits).

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

**Example:** “From any directory” indicates that the current folder does not affect the reference. “From `/etc/nixos`” identifies a required working directory; explicit `path:/etc/nixos` references identify that source independently. `REPLACE_WITH_SYSTEM`, `COMMIT`, and `PROFILE_NAME` denote verified platform, revision, and profile-name values. `workstation` is a fictional flake output label, separate from the machine's actual hostname.

**Expectation:** The prerequisite account, source location, placeholder values, and possible effects are identifiable before an operation; missing machine details remain a prerequisite rather than a guessed value.

### Practice: classifying a proposed change

**Rationale:** Layer classification explains effects more reliably than command memorization.

**Explanation:** Source files, store artifacts, user environments, and running services have separate transitions.

**Example:** A package-list edit, a `flake.lock` update, and a system build have completed. A claim then states that a newly declared SSH service is running. The classification task concerns the missing transition and the evidence required for that claim.

**Expectation:** Success criterion: the classification identifies activation as missing and distinguishes activation results from a runtime service observation.

<details>
<summary>Worked solution</summary>

System activation applies the declared SSH configuration; a runtime service inspection establishes the resulting state. Editing, locking, and building prepare the transition. Activation output and service inspection remain necessary because a failure can leave a partially changed system.

</details>

## 2. Components and first-expression evaluation

### Nix, Nixpkgs, NixOS, the store, and flakes

**Rationale:** Similar names describe distinct responsibilities in the configuration process.

**Explanation:** **Nix** denotes both a language and package-management/build tooling. **Nixpkgs** supplies package definitions and supporting libraries, largely written in that language. **NixOS** is a Linux distribution assembled through Nix and Nixpkgs. The **Nix store**, normally `/nix/store`, contains source snapshots, build descriptions, packages, and generated files. A **flake** is a source tree whose standardized `flake.nix` entrypoint declares inputs and outputs; other NixOS entrypoints also exist.

Package management with Nix is independent of NixOS. NixOS additionally composes operating-system files and services. The official introductions cover [language basics](https://nix.dev/tutorials/nix-language.html), [profiles](https://nix.dev/manual/nix/stable/package-management/profiles.html), and [flake concepts](https://nix.dev/concepts/flakes.html).

**Example:** A shell containing Nixpkgs' Hello package is a package exercise on a supported Nix host. An SSH server declaration is NixOS module configuration. A locked Nixpkgs revision is an input-selection mechanism.

**Expectation:** Syntax, package recipes, artifact storage, operating-system integration, and dependency pinning have identifiable owners.

### Evaluation before building

**Rationale:** A literal calculation demonstrates language evaluation without changing system configuration.

**Explanation:** An **expression** produces a value; **evaluation** computes it. The modern Nix CLI and flakes remain experimental in the reference version. Explicit enablement permits those interfaces but does not imply stability. `--extra-experimental-features` adds to configured features for the invocation rather than replacing them. A later NixOS module supplies persistent settings after activation. The [flake concepts guide](https://nix.dev/concepts/flakes.html) covers enablement, and the [`nix eval` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html) specifies evaluation behavior.

**Example:** **READ-ONLY**, from any directory. This expression has only literal arithmetic inputs:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --expr '1 + 2'
```

**Expectation:** Evaluation prints `3`. A missing executable or unsupported flag instead indicates an installed-version or setup issue requiring diagnosis before later examples apply.

### Evaluation, realization, and running systems

**Rationale:** A rebuild can reuse store results or binary substitutes instead of compiling every dependency again.

**Explanation:** Evaluation can produce a **derivation**: a structured recipe identifying a builder and its inputs. Nix records store-level build descriptions and **realizes** required outputs by fetching substitutes from configured caches or running builds. Dependencies form a graph. A package's **closure** includes the store objects referenced transitively at runtime. NixOS composes a top-level system result; activation applies relevant changes to the running machine.

Different versions and variants can coexist at distinct store paths. Store results are treated as immutable; source changes followed by rebuilding replace direct edits to `/nix/store`. Documents and application databases remain mutable and require independent backups. The hash-like part of a store path is **not necessarily a checksum of its output contents**. Input-addressed derivations commonly identify outputs from build inputs; byte-for-byte reproducibility requires separate verification. The [NixOS manual](https://nixos.org/manual/nixos/stable/), [derivation reference](https://nix.dev/manual/nix/stable/language/derivations.html), and [profile explanation](https://nix.dev/manual/nix/stable/package-management/profiles.html) describe these mechanisms.

Explicit dependencies and retained generations improve inspectability and recovery choices. Their costs include disk use, evaluation complexity, cache/network dependence, and expensive downstream rebuilds after foundational changes. Non-Nix binary downloads may require compatibility work on NixOS.

**Example:** A text-configuration change can reuse most packages. A foundational-library change can require many downstream builds when substitutes are unavailable. Service-specific migration plans and data backups cover the mutable state outside those artifacts.

**Expectation:** Evaluation errors, fetch/build failures, and activation/runtime failures remain distinguishable, with separate evidence and recovery boundaries.

### Practice: tracing dependency reachability

**Rationale:** Dependency direction determines which store objects remain necessary.

**Explanation:** A selected program can require a library absent from the explicit package list.

**Example:** A selected editor references a runtime library in the store. The classification task concerns whether package-list absence establishes that the library is disposable.

**Expectation:** Success criterion: the explanation distinguishes explicit selection from transitive store reachability.

<details>
<summary>Worked solution</summary>

The editor's closure retains the referenced library. Nix's reachability and garbage-collection mechanisms identify unused store objects; manual deletion based on package-list membership would disregard runtime dependencies.

</details>

## 3. Reading the Nix language

### Values, lists, and attribute sets

**Rationale:** Configuration settings become easier to interpret when their data types are explicit.

**Explanation:** A **string** is double-quoted text. A **Boolean** is `true` or `false`; numbers are unquoted; `null` expresses absence where an interface accepts it. A **list** has square brackets and whitespace-separated elements. An **attribute set** maps names to values inside braces, with semicolons ending assignments. A dot selects a nested attribute; dotted assignments construct nested sets.

These constructs belong to the language. The module system supplies the NixOS meaning of paths such as `services.openssh.enable`. The [language tutorial](https://nix.dev/tutorials/nix-language.html) explains the underlying syntax.

**Example:** This complete standalone expression represents sample data:

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

**Expectation:** Strings, lists, nested attributes, semicolons, and whitespace-separated elements are recognizable without treating Nix as shell syntax.

### Local names, interpolation, and operators

**Rationale:** Local names express reuse without repeating configuration values.

**Explanation:** `let ... in ...` defines local bindings and returns the expression following `in`. `${expression}` interpolates a string-compatible value; `toString` converts a number for interpolation. `'' ... ''` delimits an indented multiline string. `./file.nix` resolves relative to the containing Nix file, whereas `"./file.nix"` is text rather than a path value.

`++` concatenates lists. `//` combines ordinary sets by replacing matching top-level keys from the right; this shallow operation differs from typed NixOS option merging. `==` tests equality, `&&` expresses Boolean conjunction, and `if condition then value else otherValue` selects a value. `inherit name;` abbreviates `name = name;`; `inherit (set) name;` abbreviates `name = set.name;`.

Explicit package references such as `[ pkgs.hello pkgs.git ]` expose their origin. The alternative `let inherit (pkgs) hello git; in [ hello git ]` binds only the locally needed attributes.

**Example:** **READ-ONLY**, from any directory, with literal local inputs:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --expr 'let count = 2; tools = [ "hello" ]; in { message = "${toString count} tools"; selected = tools ++ [ "git" ]; }'
```

**Expectation:** The resulting set contains `message = "2 tools"` and `selected = [ "hello" "git" ]`; printed attribute order can differ from source order.

### Functions, imports, and laziness

**Rationale:** Module argument lists are ordinary function syntax applied by the module system.

**Explanation:** A **function** accepts an input and returns a value. `x: x + 1` accepts one number; `(x: x + 1) 2` applies it using whitespace. `{ name, suffix ? "!" }: name + suffix` accepts named arguments with a default suffix. `...` in a parameter pattern accepts additional arguments; it is actual syntax, not an omission marker. Thus `{ pkgs, ... }:` accepts a set containing `pkgs` and possibly other fields.

`import ./file.nix` evaluates a file and returns its value. A returned function receives arguments separately: `(import ./function.nix) { name = "Learner"; }`. `builtins.import` is the underlying builtin; ordinary `import` is available by default. NixOS `imports` instead identifies modules for collection and merging. It is neither textual inclusion nor simply a language-level `import` call.

Nix is **functional**: bindings describe values instead of repeated mutation. It is **lazy**: values are computed when needed, which can defer errors and make traces indirect. Evaluation can still fetch inputs, write caches, or trigger import-from-derivation builds. These properties are covered in [language basics](https://nix.dev/tutorials/nix-language.html).

**Example:** A named argument and default suffix produce `"Hello, Learner!"`:

```nix
# Function application with a named argument and a default suffix.
let
    greet = { name, suffix ? "!" }: "Hello, ${name}${suffix}";
in
    greet { name = "Learner"; }
```

**Expectation:** The parameter pattern, colon, return expression, and whitespace application explain the function's result independently of shell-command conventions.

### Practice: representing typed values

**Rationale:** Small examples isolate syntax and type distinctions before system evaluation introduces longer traces.

**Explanation:** Booleans differ from quoted strings, and Nix list elements are separated by whitespace.

**Example:** A sample set requires Boolean `enabled`, a list of the strings `hello` and `git`, and numeric `count` equal to the list's length. The task is the representation of those three values.

**Expectation:** Success criterion: three attributes use Boolean `true`, two whitespace-separated string elements, and numeric `2`.

<details>
<summary>Worked solution</summary>

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

### Preserving the installed-machine foundation

**Rationale:** Working hardware, storage, boot, and access settings form the foundation for additional software policy.

**Explanation:** `/etc/nixos/configuration.nix` commonly imports `hardware-configuration.nix` and defines system options. Installations can have additional files or other entrypoints; the actual import graph establishes ownership. The existing hardware imports, file systems, boot settings, accounts, authentication, networking, and `system.stateVersion` remain part of the system composition.

An independently recoverable configuration/data backup, a known-good bootable generation, and recovery access are prerequisites for source changes. `system.stateVersion` selects compatibility defaults for stateful behavior; the input branch selects the release independently. The installed state version remains appropriate unless a deliberate state migration requires a documented change. The [NixOS manual](https://nixos.org/manual/nixos/stable/) covers installation and configuration responsibilities.

**Example:** **READ-ONLY**, from any directory. These commands inspect the conventional files:

```bash
less /etc/nixos/configuration.nix
less /etc/nixos/hardware-configuration.nix
```

An absent conventional file calls for inspection of the actual entrypoint and imports, rather than a guessed replacement. `q` exits `less`.

**Expectation:** The entrypoint and hardware imports are identified, with recoverable source/data and a boot/access fallback established before editing.

### Options and supplied module arguments

**Rationale:** A declared option provides a typed interface rather than an arbitrary attribute name.

**Explanation:** A module can be a set or a function returning definitions. The module system supplies arguments including `pkgs`, the package set; `lib`, helper functions; and `config`, the merged configuration. An **option declaration** establishes its name, type, documentation, and often a default. An **option definition** supplies a value. Unknown options and wrong types fail evaluation.

`environment.systemPackages` makes executables available system-wide. Required service registration, D-Bus integration, or other system behavior belongs to the relevant NixOS service/program interface rather than package selection alone. The manual covers [configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax) and [package management](https://nixos.org/manual/nixos/stable/#sec-package-management).

**Example:** **SOURCE EDIT**, through authorized editing access. `/etc/nixos/modules/cli-tools.nix` contains the following complete module. An ordinary `modules/` directory accommodates it where absent, while the installed `configuration.nix` remains intact:

```nix
# Additional command-line tools alongside existing hardware and service settings.
{ pkgs, ... }:
{
    environment.systemPackages = [ pkgs.hello pkgs.git ];
}
```

Stage 6 adds this file to the composition. This module is the single owner of these additional tool definitions.

**Expectation:** Source contains a separate tool-selection module; the running system remains unchanged until activation.

### Merging definitions by type and priority

**Rationale:** Module composition depends on option semantics, not a general last-file-wins rule.

**Explanation:** The module system collects definitions and merges them according to type and priority. Package lists generally concatenate. Conflicting scalar values at equal effective priority can fail. `lib.mkDefault` permits ordinary definitions to replace a default; `lib.mkForce` deliberately overrides ordinary definitions. A force override therefore requires an understood priority conflict and an intentional policy choice. Helpers such as `mkBefore` affect list ordering rather than winning priority.

Language-level `//` instead performs shallow set replacement. Module `imports` forms a graph, not a sequence of imperative updates. The manual's [modularity guidance](https://nixos.org/manual/nixos/stable/) and [priority rules](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities) describe the distinction.

**Example:** This standalone illustrative module offers a default; the progressive spine retains its existing hostname definitions:

```nix
# A hostname default replaceable by ordinary machine definitions.
{ lib, ... }:
{
    networking.hostName = lib.mkDefault "workstation";
}
```

An ordinary `networking.hostName = "another-name";` definition wins over this default. Two different ordinary hostname definitions require investigation of their owners and intended policy.

**Expectation:** List combination and scalar conflicts are predictable from option types and priorities rather than file order alone.

### Practice: preserving configuration ownership

**Rationale:** A useful rebuild retains installation-specific settings while adding shared software policy.

**Explanation:** Hardware identity and a small software-selection module have separate responsibilities.

**Example:** An online editor module is proposed as a replacement for an installed `configuration.nix` containing hardware imports and administrator definitions. The task concerns a composition that retains those existing settings.

**Expectation:** Success criterion: the composition includes the new software definition without discarding any installed-machine settings.

<details>
<summary>Worked solution</summary>

The existing `configuration.nix` and its imports remain included. A separate module supplies the new package definition alongside them. Storage identifiers, bootloader settings, users, and `stateVersion` remain specific to the installed machine.

</details>

## 5. Choosing package scope

### Running a package for a single use

**Rationale:** Temporary tool execution isolates a package experiment from persistent OS selection.

**Explanation:** `nix run` builds or fetches an app or suitable package and executes it. `--` separates application arguments. Direct GitHub flake references permit consumption without adding an input to a local flake. Explicit branch references avoid dependence on a machine's `nixpkgs` registry alias, but a branch remains a moving reference rather than an enduring pin.

The Nix 2.34 manual places `nix shell` on the `nix env shell` reference page; installed-version support determines the accepted spelling. These examples use `nix shell`. Legacy `nix-shell` has a separate interface and conventions. The [`run` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html) and [shell reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-env-shell.html) specify the relevant behavior.

**Example:** **BUILD-ONLY plus application execution**, from any directory, with trust in the referenced source as a prerequisite:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:NixOS/nixpkgs/nixos-26.05#hello -- --greeting 'Hello from Nix'
nix --extra-experimental-features 'nix-command flakes' shell github:NixOS/nixpkgs/nixos-26.05#hello --command hello
```

The first command prints the supplied greeting; the second prints Hello's default greeting. Both retain the system package list. A shell exposes tools on `PATH`, and executed programs retain ordinary user-level file and network access.

**Expectation:** A trusted tool runs without a persistent user-profile change or selection of another OS generation.

### User-profile selections and history

**Rationale:** Per-user package selections have a lifecycle separate from the declarative OS specification.

**Explanation:** **Imperative** package management requests an immediate selection change. **Declarative** management records a desired package set in source and rebuilds from it. Both can coexist; overlapping selections can make executable lookup less obvious.

Modern `nix profile` maintains selections and history for the invoking account. Normal-user execution targets that user's profile; `sudo` targets a different account. Modern profile format and legacy `nix-env` profile format are not interchangeable. A format error requires identification of the existing workflow rather than forced mixing of interfaces. User-profile rollback and NixOS rollback affect different selections. The official references cover [adding](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-add.html), [listing](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-list.html), and [rolling back](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-rollback.html).

**Example:** From any directory, the first and third commands are **READ-ONLY**. The others are **USER-PROFILE CHANGE** alternatives for a deliberate Hello-profile experiment:

```bash
nix --extra-experimental-features 'nix-command flakes' profile list
nix --extra-experimental-features 'nix-command flakes' profile add github:NixOS/nixpkgs/nixos-26.05#hello
nix --extra-experimental-features 'nix-command flakes' profile history
nix --extra-experimental-features 'nix-command flakes' profile rollback
```

Rollback selects the most recent older profile version. Intervening profile operations can make that version different from the intended recovery target, so inspected history determines its suitability.

**Expectation:** A per-user package selection remains distinguishable from a package declared for all system users, including its separate history and rollback target.

### Removing and upgrading at the owning layer

**Rationale:** Changing one selection layer leaves independent package exposure intact.

**Explanation:** Modern-profile removal and upgrade identify packages by names reported by `profile list`. System-package changes instead belong to the owning module and a subsequent rebuild. Removing a selection does not immediately delete store files: dependencies and older generations can retain them.

An upgrade from an unlocked reference follows that reference. A package installed from a locked commit reference does not automatically move to a newer commit. The [remove](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html) and [upgrade](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-upgrade.html) references describe these operations.

**Example:** **USER-PROFILE CHANGE**, from any directory. These are alternatives; `PROFILE_NAME` denotes the exact inspected profile name:

```bash
nix --extra-experimental-features 'nix-command flakes' profile remove PROFILE_NAME
nix --extra-experimental-features 'nix-command flakes' profile upgrade PROFILE_NAME
```

For the stage 4 module, omitting `pkgs.hello` from its list removes that system-wide selection after the stage 7 rebuild/activation. Other profiles or environments can still expose Hello.

**Expectation:** Package exposure is changed at its actual owner, while unused store artifacts remain subject to Nix-managed reachability and cleanup.

### Practice: explaining a persistent executable

**Rationale:** Multiple package-selection layers can legitimately expose the same command.

**Explanation:** `PATH` can contain tools from the system, a user profile, or a temporary development shell.

**Example:** Hello has been removed from a user profile but remains available after activation of `cli-tools.nix`. The task concerns an alternative owner and the corresponding declarative change.

**Expectation:** Success criterion: the explanation identifies the system-package definition and separates profile removal from that definition's lifecycle.

<details>
<summary>Worked solution</summary>

`environment.systemPackages` also selects Hello. Removing its entry from `modules/cli-tools.nix`, rebuilding, and deliberately activating changes the system selection. A fresh shell verifies the resulting lookup; an existing temporary shell can expose another copy independently.

</details>

## 6. Wrapping the existing system in one flake

### Inputs, outputs, and the lock file

**Rationale:** Explicit pins make dependency choices inspectable independently of a channel's current state.

**Explanation:** `flake.nix` declares requested inputs and computes outputs. `flake.lock` records resolved dependencies, typically including revisions and content hashes. `inputs.nixpkgs.url` requests a source, and the lock resolves a branch to a particular revision. The `outputs` function accepts inputs and returns named results. An input declaration by itself installs no package.

Common output families are `packages.<system>.<name>`, `apps.<system>.<name>`, `devShells.<system>.<name>`, complete `nixosConfigurations.<name>`, and reusable `nixosModules.<name>`. A platform pair such as `x86_64-linux` or `aarch64-linux` matters for packages and systems. A NixOS configuration's attribute name is a selected label, not its architecture.

Pins support repeatable evaluation by recording input choices. User-data backups, runtime requirements, source archives for long-term availability, and independent byte-for-byte build verification cover different guarantees. Flakes remain experimental, and non-flake NixOS workflows remain legitimate. The [NixOS 26.05 highlights](https://nixos.org/manual/nixos/stable/release-notes.html#sec-release-26.05-highlights) describe `system.nix` as another entrypoint alongside `configuration.nix` and `flake.nix`. This sequence develops the flake workflow specified by the [flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).

**Example:** A branch request in `flake.nix` describes an input policy; the resolved tree in `flake.lock` records the current exact choice. Neither source artifact activates the running machine.

**Expectation:** Source declarations, resolved pins, and runtime state have distinct inspection points and guarantees.

### Source layout and verified platform selection

**Rationale:** A thin wrapper preserves the installation without assuming a processor architecture or hostname.

**Explanation:** The source root is `/etc/nixos`. Explicit `path:/etc/nixos` references make local-source behavior independent of Git membership. This form requires a source tree containing only configuration safe for other local users to read: path snapshots can include untracked/private files that Git-backed filtering would omit. Source snapshots enter the normally world-readable store.

Passwords, private keys, tokens, and sensitive backups require storage outside that tree and the store. Other local users can normally read store paths regardless of whether those paths appear on their `PATH`. The layout extends existing files rather than replacing additional installed configuration.

**Example:** **SOURCE EDIT** applies to the new files in this layout:

```text
/etc/nixos/
    configuration.nix              existing; preserve
    hardware-configuration.nix     existing, if used; preserve
    flake.nix                      new thin wrapper
    flake.lock                     generated by Nix
    modules/
        cli-tools.nix                from stage 4
        nix-cli.nix                  new feature settings
```

The following **READ-ONLY** platform inspection works from any directory:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --impure --raw --expr builtins.currentSystem
```

Here `--impure` obtains the current installation's native platform; it is not a general flake workaround. A native configuration requires agreement with any existing `nixpkgs.hostPlatform` setting. Cross-compilation is outside this sequence. Every `REPLACE_WITH_SYSTEM` occurrence denotes that verified platform pair and requires substitution before use.

**Expectation:** The source layout retains installed files, excludes private material, and has a verified platform value for subsequent expressions.

### Creating the initial configuration spine

**Rationale:** A small complete flake exposes the composition while retaining machine-specific ownership.

**Explanation:** `nixpkgs.lib.nixosSystem` composes modules into a complete system. `workstation` is the output attribute selected after `#`; `networking.hostName` remains owned by the existing configuration. The module list includes the installed `configuration.nix`, its existing hardware imports, and two small additions.

The Nixpkgs branch must match the release intended for maintenance, with its documentation and option names checked. An installed release other than 26.05 requires its corresponding branch or a separately planned stage 9 upgrade. The verified platform substitution is equally necessary.

**Example:** **SOURCE EDIT**. `/etc/nixos/modules/nix-cli.nix` contains the persistent feature settings:

```nix
# Persistent CLI features taking effect after system activation.
{ ... }:
{
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

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

**Expectation:** One explicit composition retains the installed hardware, users, boot settings, hostname, and state compatibility settings, while adding tool and CLI-feature modules.

### Locking and inspecting before activation

**Rationale:** Resolved pins and an inspected output establish the candidate before building or activation.

**Explanation:** `nix flake lock` fills missing entries and preserves still-valid pins. A changed input URL can require a corresponding lock change. Nix generates the resolved revisions and hashes in the lock JSON. A known-good source/lock pair remains the recovery reference before edits.

Implicit local Git-backed references differ from the explicit `path:` form used here. New files need Git-index membership to enter a Git-backed snapshot. Dirty edits to tracked files are normally included with a warning and can be tested before a commit. Portable pure evaluation requires imports inside the captured source tree; private material remains outside. The official contracts cover [local flake sources](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) and [locking](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html).

**Example:** **SOURCE EDIT plus input fetching**, with authorized write access to `/etc/nixos`:

```bash
nix --extra-experimental-features 'nix-command flakes' flake lock path:/etc/nixos
```

Then **READ-ONLY with evaluation/fetch/cache caveats**, from any directory:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

The locking account requires source-write authorization through the established administrative workflow, preserving ownership and permissions. `--no-update-lock-file` causes inspection to fail when lock changes are required rather than silently accepting new pins.

**Expectation:** The lock contains resolved inputs and evaluation prints the preserved actual hostname. Runtime activation remains unchanged.

### Practice: distinguishing output names from hostnames

**Rationale:** Explicit output selection is independent of automatic hostname-based selection.

**Explanation:** `nixosConfigurations.workstation` names a flake result; `networking.hostName` configures an OS property.

**Example:** The actual machine has a hostname other than `workstation`. The classification task concerns the validity of the explicit selector `path:/etc/nixos#workstation` without a hostname change.

**Expectation:** Success criterion: the explanation identifies the selected attribute and the separate source of the actual hostname.

<details>
<summary>Worked solution</summary>

The selector directly chooses the `workstation` configuration attribute. Its composed modules retain the machine's actual hostname, so the two names can differ.

</details>

## 7. Building, testing, and activating the system

### Building the system artifacts

**Rationale:** Artifact preparation exposes evaluation and build failures before service changes.

**Explanation:** A complete configuration exposes `config.system.build.toplevel`. `nix build --no-link` realizes that result without creating a local `result` symlink; `--print-out-paths` reports its locations. Build success establishes realization with the selected inputs, not correct hardware behavior, remote access, or application operation. An unused result without an enduring garbage-collection root can later be collected. The [`build` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-build.html) specifies these flags.

**Example:** **BUILD-ONLY**, from any directory, after platform substitution and locking:

```bash
nix --extra-experimental-features 'nix-command flakes' build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel
```

Normal-user execution can download substantial data, run package builders, and consume disk and CPU. A failure requires diagnosis before activation becomes appropriate.

**Expectation:** Nix prints a realized `/nix/store/…-nixos-system-…` path. Running-system and default-boot selections remain unchanged, and the working directory contains no new result link.

### Choosing an activation mode

**Rationale:** Immediate service effects and next-boot selection are independent safety-relevant choices.

**Explanation:** The [configuration manual](https://nixos.org/manual/nixos/stable/#sec-changing-config) distinguishes four modes:

| Mode | Running-system effect | Future default-boot effect |
| --- | --- | --- |
| `build` | Artifact preparation only | Existing default retained |
| `test` | Candidate activated now | Existing default retained |
| `boot` | Current services retained | Candidate selected |
| `switch` | Candidate activated now | Candidate selected |

The previous direct `nix build --no-link` avoids the result link commonly produced by `nixos-rebuild build`. Administrative activation uses `nixos-rebuild` with the same explicit selector and reviewed source/lock pair.

`test` really activates services. Restarts, dropped connections, and stateful-service writes or migrations are possible. Those persistent effects survive a reboot into the previous default; their recovery requires independent data procedures. Activation can fail partway through, leaving service changes that require runtime inspection and the prepared recovery plan.

**Example:** **SYSTEM CHANGE**, from any directory, with local console/recovery access and backups established. These are alternative modes, not a sequence. Per-invocation feature settings remain necessary until activation of the feature module:

```bash
sudo nixos-rebuild test --flake path:/etc/nixos#workstation --option extra-experimental-features 'nix-command flakes'
sudo nixos-rebuild boot --flake path:/etc/nixos#workstation --option extra-experimental-features 'nix-command flakes'
sudo nixos-rebuild switch --flake path:/etc/nixos#workstation --option extra-experimental-features 'nix-command flakes'
```

The intended immediate/boot effect determines the selected mode. Installed `nixos-rebuild --help` establishes local flag support if it differs from the example. Stage 1 describes authorized administrative alternatives. A coherent, unchanged source/lock pair between build and activation preserves the reviewed candidate.

**Expectation:** The selected mode's immediate and next-boot effects are explicit, including service restarts and persistent data risks during `test`.

### Observing activation and runtime results

**Rationale:** Successful build and activation exit codes do not establish that every changed workflow functions.

**Explanation:** Runtime evidence includes the changed feature, existing access methods, and relevant logs. Kernel and boot-sensitive changes can require a reboot; userspace activation is different from a fresh boot. User services also have lifecycles that a system rebuild does not universally restart, as described by the [configuration warnings](https://nixos.org/manual/nixos/stable/#sec-changing-config).

Later modern CLI examples assume activation of `nix-cli.nix`. Until that activation, the same `--extra-experimental-features 'nix-command flakes'` prefix remains necessary for `nix` commands. Source declaration alone does not enable the persistent settings.

**Example:** **READ-ONLY**, from any directory, after successful activation of `cli-tools.nix`:

```bash
command -v hello
hello --version
nixos-version
systemctl --failed
```

`hello --version` runs the selected trusted executable for version inspection. A fresh terminal can clear stale shell-command lookup. The observed result and previously working access establish whether the intended transition succeeded.

**Expectation:** Functional observations support the result, or a specific mismatch becomes the subject of diagnosis before further activation attempts.

### Practice: classifying activation effects

**Rationale:** Operation selection follows intended runtime and boot effects.

**Explanation:** Preparing artifacts and activating a running service are different commitments.

**Example:** The first goal is package-build verification with existing services unchanged. The later goal is selection of the candidate for the next boot, also without immediate activation. The task concerns the two corresponding operations.

**Expectation:** Success criterion: build-only satisfies the first goal, and `boot` is distinguished from `test` for the second.

<details>
<summary>Worked solution</summary>

The direct top-level `nix build --no-link` prepares artifacts. Authorized `nixos-rebuild boot --flake path:/etc/nixos#workstation` selects the later boot candidate. `test` would activate immediately and therefore has a different effect from the second goal.

</details>

## 8. Accounts, networking, services, and an optional desktop

### Adding an account while preserving administrator access

**Rationale:** Account composition must retain the working administrator and authentication path.

**Explanation:** The additional practice account is optional. Existing administrator definitions and `users.mutableUsers` policy remain authoritative; changing that policy to `false` changes account-management semantics. With ordinary mutable user management, a newly declared user has no password by default. Password login requires an interactive password-setting operation after account creation.

Plaintext passwords and private keys belong outside Nix source and generated artifacts because those can enter the store. The [user-management manual](https://nixos.org/manual/nixos/stable/#sec-user-management) specifies account behavior and password options.

**Example:** Optional **SOURCE EDIT**, complete `/etc/nixos/modules/practice-user.nix`. `learner` denotes a fictional, non-conflicting new account name, replaced consistently where necessary. Existing accounts remain intact, and this practice account has ordinary non-administrative groups:

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

Each selected optional module in this stage enters the existing `flake.nix` modules list as `./modules/NAME.nix`, alongside all current entries. Stage 7's inspection, build, and deliberate activation precede account use. After the account exists, the following authorized **SYSTEM CHANGE** works from any directory:

```bash
sudo passwd learner
```

Interactive entry keeps the password outside source. An existing immutable-account policy instead requires its documented password-file options and established secret-management process; the mutable-account procedure does not establish compatibility with that policy.

**Expectation:** The account declaration adds an optional login while retaining administrator access and separating credentials from source/store artifacts.

### Separating networking policy from service experiments

**Rationale:** Network changes have machine-specific access consequences, especially during remote administration.

**Explanation:** The installed backend, interfaces, Wi-Fi credentials, firewall policy, and hostname remain the baseline. A deliberately selected networking backend and a coordinated migration avoid competing configuration owners. `networking.hostName` is separate from the flake selector; hostname changes can affect applications and remote access.

A service package and its OS integration have different roles. OpenSSH enablement starts an SSH server after activation, while authentication and firewall exposure require independent review. `openFirewall = false` prevents the SSH module's automatic allow rule; separately configured allow rules can still expose the service. The [NixOS networking and configuration manual](https://nixos.org/manual/nixos/stable/) supplies the system context.

**Example:** Optional **SOURCE EDIT**, complete `/etc/nixos/modules/ssh.nix`, for a machine with reviewed authentication and existing firewall rules:

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

Inclusion in the existing modules list is optional and requires reconciliation with any existing SSH settings. A verified alternate login is a prerequisite for password/key changes. Remote-only account, network, or SSH experiments require recovery access before proceeding.

**Expectation:** The proposed service integration and remaining authentication, firewall, and recovery conditions are explicit before activation.

### Inspecting services and selecting an optional desktop

**Rationale:** Runtime service evidence and desktop integration have different scopes and costs.

**Explanation:** After authorized SSH activation, service status and recent logs reveal actual behavior. Additional log privileges require corresponding authorization. Logs can expose hostnames, addresses, and other private details, so shared excerpts require redaction.

For a graphical host needing GNOME, NixOS 26.05 uses `services.desktopManager.gnome.enable` and `services.displayManager.gdm.enable`. The selected release determines option names. The existing display manager remains until a deliberate migration, while GPU and display-driver settings stay machine-specific. The manual documents [GNOME enablement](https://nixos.org/manual/nixos/stable/#sec-gnome-enable).

**Example:** **READ-ONLY**, from any directory, after SSH enablement:

```bash
systemctl status sshd
journalctl -u sshd -b --no-pager -n 50
```

Optional **SOURCE EDIT**, complete `/etc/nixos/modules/desktop.nix`, for a reviewed GNOME choice:

```nix
# GNOME and display-manager integration with machine-specific hardware settings.
{ ... }:
{
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;
}
```

Desktop inclusion, building, and activation form a separate change from networking/accounts. Large downloads and graphical-session disruption are possible; a recovery console is a prerequisite. A headless host retains its existing server/console configuration.

**Expectation:** Service status is independently observable, and a desktop remains an optional integrated module choice rather than merely a package-list entry.

### Practice: analyzing SSH exposure

**Rationale:** A security-related option controls a specific part of the access policy rather than every boundary.

**Explanation:** Reachability depends on service binding, local firewall rules, upstream networking, and authentication.

**Example:** A configuration contains `services.openssh.openFirewall = false;`. The task concerns the scope of that setting and whether it establishes universal remote unreachability.

**Expectation:** Success criterion: the explanation distinguishes prevention of an automatic allow rule from independently permitted traffic.

<details>
<summary>Worked solution</summary>

The SSH module adds no automatic firewall opening. Existing separate allow rules remain effective, and upstream isolation is a separate property. Reviewed firewall/network exposure and observed authentication/access establish the actual boundary.

</details>

## 9. Updating inputs and planning release upgrades

### Refreshing pins as a separate maintenance step

**Rationale:** An input update is a source change with its own review before rebuilding and activation.

**Explanation:** Modern `nix flake update` accepts **input names** as positional arguments. The current directory selects the flake unless `--flake` supplies another location. The command changes `flake.lock`, not the branch request in `flake.nix`, and leaves OS activation unchanged. Omitting input names refreshes all inputs. In contrast, `nix flake lock` fills missing or changed-request entries without intentionally refreshing every valid pin. The [update](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html) and [lock](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html) references specify these distinctions.

Channels, user profiles, and the OS flake lock have separate update workflows. The system flake's input revisions are refreshed through its own `nix flake update` operation.

**Example:** **SOURCE EDIT plus input fetching**, from any directory, with authorized source-write access. These are alternatives:

```bash
nix flake update nixpkgs --flake path:/etc/nixos
nix flake update --flake path:/etc/nixos
```

The first targets `nixpkgs`; the second targets every input. In the minimal one-input spine their scope currently coincides. `--flake path:/etc/nixos` names the location; positional arguments name inputs.

**Expectation:** The intended lock revisions change, with old/new revision review and a build preceding any activation decision.

### Pinning and restoring coherent source

**Rationale:** Exact revisions support temporary holds and diagnosis, while source/lock coherence preserves the intended configuration.

**Explanation:** A branch request already resolves to an exact lock revision. A known-good record therefore includes compatible source and lock files. Restoring only the lock leaves source changes, such as a newly enabled service, intact. Full behavior restoration requires the relevant source and lock data from known-good backup/history.

An explicit source pin uses `github:NixOS/nixpkgs/COMMIT`, where `COMMIT` is a verified full revision from the known-good lock or upstream repository. The changed request requires locking, inspection, and another build. A held pin can exclude security fixes, so its maintenance policy includes a review date or process. The [flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) covers source references and resolved locks.

**Example:** A release-branch policy accepts new `nixos-26.05` lock revisions after review. A regression-investigation policy holds a known-good commit temporarily. Both retain the installed `system.stateVersion`. After a deliberate source edit, this **SOURCE EDIT plus fetching** operation resolves the request from any directory:

```bash
nix flake lock path:/etc/nixos
```

**Expectation:** The intended dependency tree, reason for its pin, and reconsideration point are identifiable alongside the compatible configuration source.

### Planning release transitions separately

**Rationale:** A release-branch transition can affect options, packages, and persistent service data formats.

**Explanation:** Current/target release notes and service-specific upgrade instructions establish the transition requirements. Verified backups, free space, a known-good boot generation, and recovery access precede a branch change. The transition then consists of editing `inputs.nixpkgs.url`, refreshing the intended lock entry, inspecting warnings, building, and separately scheduling activation or reboot. Remote-only upgrades require verified recovery access in advance.

The installed `system.stateVersion` remains unchanged unless a separately documented state migration requires otherwise. It protects compatibility defaults rather than freezing packages. Stable branches receive maintenance changes; unstable can involve broader changes, and both can contain bugs. The [upgrade manual](https://nixos.org/manual/nixos/stable/#sec-upgrading) and [release notes](https://nixos.org/manual/nixos/stable/release-notes.html) provide the authoritative starting requirements.

**Example:** Adapting this tutorial to another installed release's maintained branch preserves that release. Moving the machine to 26.05 is a separate upgrade objective with its own prerequisites and reviewed branch edit.

**Expectation:** A release transition has an explicit plan rather than occurring incidentally through copied input configuration.

### Practice: identifying an update's changed artifact

**Rationale:** Artifact ownership makes update effects predictable.

**Explanation:** The input request and its resolved revision reside in different files.

**Example:** `nix flake update nixpkgs --flake path:/etc/nixos` completes while `flake.nix` still requests the same branch. The task concerns the changed file and the remaining steps before a new system runs.

**Expectation:** Success criterion: the answer identifies the lock update and separate build/activation requirements.

<details>
<summary>Worked solution</summary>

`flake.lock` records the updated resolution. The branch request in `flake.nix` and OS activation remain unchanged. Pin review and system building precede a deliberate activation-mode selection.

</details>

## 10. Recovery and garbage collection

### Generations and rollback boundaries

**Rationale:** Recovery depends on knowing which retained state a rollback selects.

**Explanation:** NixOS retains system generations, often selectable through the bootloader. Modern user profiles retain separate versions. Retained store results permit selection of an earlier environment without rebuilding every artifact; they are not snapshots of every disk or process.

OS rollback selects earlier software and generated system configuration. Configuration source, including `configuration.nix` and `flake.lock`, requires separate restoration from known-good history. Documents, databases, passwords, and other mutable state require independent backups and recovery procedures. An older service can be incompatible with a migrated database.

Atomic package-environment pointer selection is narrower than system activation, service restarts, and data migrations, which can have partial or persistent effects. The [profile explanation](https://nix.dev/manual/nix/stable/package-management/profiles.html) describes that narrower selection mechanism.

**Example:** **READ-ONLY**, from any directory on the documented NixOS interface:

```bash
nixos-rebuild list-generations
```

The inspected machine history identifies actual generation numbers. A recorded known-good target is a generation that has been tested, rather than simply an older number.

**Expectation:** A retained system fallback and the independent source/data recovery assets have distinct, documented roles.

### Recovering running and unbootable systems

**Rationale:** Runtime recovery must remain possible when the candidate source cannot evaluate.

**Explanation:** A usable system can select a suitable previous generation through rollback. A broken boot can instead use a retained older generation through the installed bootloader's documented menu and keys. Where no retained generation boots, suitable recovery media and official recovery/install guidance apply to the verified storage layout, preserving data and using actual disk identifiers.

After runtime recovery, source and lock repair precede the next ordinary rebuild; otherwise the failed candidate can recur. Errors and logs remain useful diagnostic evidence. Partial activation requires explicit service inspection because failure does not imply unchanged runtime state. The [rebuild recovery guidance](https://wiki.nixos.org/wiki/Nixos-rebuild) supplements the primary [NixOS manual](https://nixos.org/manual/nixos/stable/), which takes precedence over dated examples.

**Example:** **SYSTEM CHANGE**, from any directory, when the previous system generation is the intended recovery target:

```bash
sudo nixos-rebuild switch --rollback
```

A user-profile mistake has a different path: inspected `nix profile history` and normal-user `nix profile rollback`. That operation affects the user selection rather than OS boot, services, or networking.

**Expectation:** Usable-system rollback, boot-menu recovery, source repair, and data restoration have separate plans and applicability conditions.

### Garbage collection and history retention

**Rationale:** Space recovery can reduce the available recovery history.

**Explanation:** A **garbage-collection root** keeps a store object and its references reachable. Current and retained profile generations can provide roots. A removed package selection can remain reachable through an older generation or another dependency. Garbage collection removes unreachable store paths; generation deletion can make additional paths unreachable and eliminate rollback choices. A `--no-link` build avoids a local result link but may lack a persistent root.

Inspection of reachability and recovery requirements precedes cleanup. Known-good generations remain useful recovery assets, particularly during learning. `nix-collect-garbage -d` combines broad deletion of old profile generations with collection; that deliberate retention-policy decision can remove rollback targets. The official references cover [GC concepts](https://nix.dev/manual/nix/stable/package-management/garbage-collection.html), [`nix store gc`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-store-gc.html), and [`nix-collect-garbage`](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage.html).

**Example:** **READ-ONLY inspection**, from any directory:

```bash
nix store gc --dry-run
```

After review of reachability, retained generations, and recovery requirements, optional **SYSTEM CHANGE: store deletion**:

```bash
nix store gc
```

Cleanup privileges depend on authorization in the installed Nix setup. Collection removes unreachable paths while retained generations continue to provide roots.

**Expectation:** Remaining disk usage is explainable through reachability, and history deletion remains an intentional tradeoff rather than an accidental loss of rollback targets.

### Practice: matching recovery assets to state

**Rationale:** Different retained artifacts recover different kinds of failure.

**Explanation:** Lock files, bootable generations, and database backups have separate responsibilities.

**Example:** A service upgrade has migrated its database, and the older service cannot read the new format. The task concerns whether booting an older generation establishes data recovery and which additional asset is required.

**Expectation:** Success criterion: the explanation identifies service-specific database recovery and a suitable backup separately from software rollback.

<details>
<summary>Worked solution</summary>

The older generation restores selected software and generated configuration. Database recovery requires the service's documented migration/recovery procedure and a suitable data backup. Separate source/lock restoration ensures that the next rebuild describes the intended recovered system.

</details>

## 11. Extending the flake with development tools

### Adding a development shell

**Rationale:** A project tool environment can be declared independently of system-wide package availability.

**Explanation:** `pkgs.mkShell` describes a development environment; `packages` supplies executable tools. `nix develop` enters the selected environment. Shell programs retain normal user file/network permissions. A `shellHook` executes on entry with those same permissions and can write files or run arbitrary commands. Tool-input pins do not replace separate pins for language package-manager dependencies and the project checkout. The [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/) documents `pkgs.mkShell`, and the [`develop` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-develop.html) covers entry behavior.

**Example:** **SOURCE EDIT**, complete extended `/etc/nixos/flake.nix`. The verified platform, chosen branch/pin, and deliberately selected optional module entries remain required; the displayed list represents the minimal spine:

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

**Expectation:** The installed-machine wrapper now also exposes a platform-specific package and development shell without changing ownership of the NixOS package set.

### Entering and leaving the shell

**Rationale:** Temporary tool availability has a different lifetime from files created during development.

**Explanation:** `nix develop` selects `devShells.<system>.default` before falling back to a package's build environment. Tools and build-related environment variables become available inside the shell. The current directory and ordinary file permissions still apply. `exit` returns to the outer shell, while created or modified files persist. Repeatable tool selection and project-state cleanup are separate responsibilities.

**Example:** **BUILD-ONLY plus interactive shell execution**, from any directory, after review of the flake and its hooks:

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

**Expectation:** Tools are available without an OS rebuild, and leaving the environment restores the outer shell while preserving project work.

### Building and running named outputs

**Rationale:** Output types determine the applicable consumption interface.

**Explanation:** `nix build` realizes packages. `nix run` prefers an app when present and otherwise runs a suitable package executable. `nix develop` supplies a development/build environment. The [`run`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html) reference specifies its behavior.

**Example:** From any directory: **BUILD-ONLY**, then **BUILD-ONLY plus application execution**:

```bash
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#default
nix run --no-update-lock-file path:/etc/nixos#default -- --greeting 'One flake, several outputs'
```

The package fallback executes Hello. NixOS activation remains unchanged throughout these output-consumption operations.

**Expectation:** Output selection follows the requested artifact or execution purpose without equating application execution with operating-system activation.

### Practice: selecting a development interface

**Rationale:** Single execution, artifact preparation, and coordinated tool environments serve different needs.

**Explanation:** Running a program once differs from entering a shell containing several tools.

**Example:** Three tasks require Hello execution once, realization without a result link, and entry into the declared tool environment. The classification concerns the corresponding commands and their execution effects.

**Expectation:** Success criterion: the answer identifies `run`, `build --no-link`, and `develop`, including the command that executes a shell.

<details>
<summary>Worked solution</summary>

`nix run path:/etc/nixos#default` performs single execution. `nix build --no-link path:/etc/nixos#default` prepares the artifact. `nix develop path:/etc/nixos` enters the declared shell. All can fetch or build; run and develop additionally execute code with the invoking user's permissions.

</details>

## 12. Reusing modules and customizing package sets

### Declaring a reusable module interface

**Rationale:** A small documented option permits shared software policy without shared hardware identity.

**Explanation:** A reusable module declares an interface and conditionally supplies definitions. `lib.mkEnableOption` creates a documented Boolean switch. `lib.mkIf` delays conditional definitions in the form expected by the module system, avoiding common recursion from whole-configuration conditionals. `config` denotes merged configuration rather than a file-local mutable object. The manual explains [module construction](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

**Example:** **SOURCE EDIT**, complete `/etc/nixos/modules/common-tools.nix`:

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

**Expectation:** A documented public switch controls a reusable module consumed by the existing workstation without duplicate tool ownership.

### Package overrides and package-set overlays

**Rationale:** Customizing one result and replacing a package throughout a set have different reach.

**Explanation:** `package.override` changes arguments accepted by that recipe's function; the inspected recipe determines valid arguments. `package.overrideAttrs` changes attributes supplied through the derivation helper and returns a new derivation. An **overlay** is a function `final: prev: { ... }` extending a package set. `prev` represents the prior set; `final` represents the final composition. Original-package references through `prev` avoid defining a package recursively in terms of itself. Dependencies of a customized package usually come from `final`.

Overlay order affects composition and downstream rebuilds. NixOS definitions instead merge by option types and priorities. The official [overrides chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overrides.chapter.md) and [overlays chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overlays.chapter.md) define the package interfaces.

**Example:** Optional **SOURCE EDIT**, complete `/etc/nixos/modules/package-customization.nix`:

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

**Expectation:** A local override addresses one result, while a deliberately scoped overlay addresses package-set-wide policy with its associated rebuild reach.

### Sharing policy while retaining machine-specific hardware

**Rationale:** Reuse benefits software policy while hardware and boot identities remain machine-specific.

**Explanation:** `nixosModules.commonTools` exports a building block; `nixosConfigurations.workstation` exports a complete system. A third-party module has an effect only after import into a composition. A third-party complete system can encode unsuitable hardware assumptions. Native references can directly build, run, or add packages, whereas reusable OS modules require deliberate composition.

For an additional input illustratively named `desktop`, `inputs.desktop.inputs.nixpkgs.follows = "nixpkgs";` aligns that input with the existing Nixpkgs input. The real input name determines the path. This is optional dependency alignment, not mandatory boilerplate, and compatibility requires verification before imposition. The [flake concepts guide](https://nix.dev/concepts/flakes.html) and [output/reference contract](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) explain these interfaces.

**Example:** A future fictional `travel` host would add `nixosConfigurations.travel` through `nixpkgs.lib.nixosSystem`, leaving `workstation` unchanged. Its composition requires that host's verified platform and complete configuration, for example `./hosts/travel/configuration.nix`, with its hardware imports inside the source tree. Shared entries can include `nix-cli.nix`, `self.nixosModules.commonTools`, and `{ tutorial.commonTools.enable = true; }`. Hardware and boot settings remain owned by the travel machine's configuration.

This is an incomplete composition plan until the actual second host's hardware configuration and platform are available. The working one-machine spine remains the usable configuration meanwhile. Remote deployment, cross-compilation, package-language build helpers, custom kernels, image generation, secret-management integrations, and Home Manager are later specializations requiring a demonstrated need and their own prerequisites. Home Manager is a separate project, not a prerequisite for user profiles or NixOS.

**Expectation:** Shared policy and independent machine identity have clear composition boundaries without treating a hypothetical second host as deployable configuration.

### Practice: matching abstractions to responsibilities

**Rationale:** Advanced mechanisms are useful when their scope matches a demonstrated need.

**Explanation:** Modules define system options, local overrides customize package results, and overlays customize package sets.

**Example:** Three goals concern shared SSH policy between machines, a renamed Hello derivation for one experiment, and a consistently replaced library across a package set. The task is classification by mechanism and rebuild reach.

**Expectation:** Success criterion: the goals map respectively to a module, a local override, and an overlay, with scope-aware rebuild expectations.

<details>
<summary>Worked solution</summary>

A reusable NixOS module owns service policy. `overrideAttrs` customizes the single derivation. A deliberately scoped overlay supplies the package-set-wide replacement. Any use of `override` depends on the actual recipe's accepted arguments rather than assumed generic parameters.

</details>

## 13. Systematic diagnosis and next-step selection

### Reading errors at the relevant layer

**Rationale:** Failure classification preserves the first useful evidence instead of obscuring it through repeated unrelated changes.

**Explanation:** The final meaningful error and its file/line identify a starting point; preceding context explains how evaluation reached it. Syntax errors, missing attributes, unknown options, type mismatches, conflicting definitions, and recursion belong to evaluation. Fetching, compilation, and resource limits can fail after recipes exist. Activation/runtime failures require service logs, access verification, and possibly recovery rather than an arbitrary input refresh.

A trace can name Nixpkgs internals where a module's value was consumed, even when the actionable error belongs to the local module. `--show-trace` expands context without supplying an automatic diagnosis. The [`eval` reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html) and [module semantics](https://nixos.org/manual/nixos/stable/#sec-writing-modules) explain the underlying boundaries.

**Example:** **READ-ONLY with evaluation/cache caveats**, from any directory:

```bash
nix eval --show-trace --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

`enable = "true";` supplies a string where `enable = true;` supplies a Boolean. An “option does not exist” error can indicate a release-specific name, a missing declaring-module import, or a spelling error. The correction belongs at the owning declaration, import, or definition established by that evidence.

**Expectation:** The error has a layer classification and one evidence-based correction at its actual owner.

### Narrowing changes and bisecting candidates

**Rationale:** A small coherent difference is easier to explain than an entire unfamiliar configuration.

**Explanation:** A known-good source/lock pair and a failure record separate configuration changes from input changes. New source with old pins and unchanged source with new pins test different hypotheses. The established backup/history workflow restores coherent test states. Separate reviewed changes to packages, services, networking, and release branches preserve attribution.

**Bisection** tests roughly half the candidate changes, then narrows to the half associated with failure. Required hardware/base configuration remains intact. Evaluation and build verification precede controlled activation candidates with recovery access. Runtime-only symptoms require state-aware testing in a controlled recovery environment. Failure can arise from an incompatible combination rather than one defective line.

**Example:** Evaluation fails after three optional modules are added to a previously buildable system. Omitting only the new optional imports retains the installed core; incremental reintroduction isolates the earliest failure. A failed-service symptom instead calls for its logs, because build success and runtime failure implicate different boundaries.

**Expectation:** A minimal reproducible source/input difference has an explicit criterion distinguishing passing and failing candidates.

### Symptom-based boundary inspection

**Rationale:** A bounded checklist connects common symptoms to the ownership distinctions established earlier.

**Explanation:** Each row identifies an initial evidence source rather than an automatic remedy:

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

**Example:** A concise change record contains the intended result, changed files, input revision, evaluation/build result, activation mode, runtime inspection, and recovery target. A shareable diagnostic excerpt includes versions, relevant configuration, the exact error, and prior working behavior, with secrets and private details redacted.

**Expectation:** Diagnosis has a bounded next inspection and a minimal, privacy-preserving evidence record suitable for further assistance.

### Practice: diagnosing runtime failure before further changes

**Rationale:** Useful observations discriminate between plausible causes.

**Explanation:** Build success and runtime success require different evidence.

**Example:** A changed SSH configuration builds successfully, but remote login fails. The classification concerns three useful runtime observations and a recovery condition, contrasted with an unrelated update of every flake input.

**Expectation:** Success criterion: service/network evidence guides diagnosis while an existing working recovery path remains available.

<details>
<summary>Worked solution</summary>

A working console or alternate login remains available. Activation output, `systemctl status sshd`, and the service journal provide three immediate observations. Binding, firewall, authentication, and network reachability then narrow the relevant boundary. Updating unrelated inputs adds uncertainty without establishing the login failure's cause.

</details>

## Appendix A. Command reference by task

### Selecting operations by intended effect

**Rationale:** Intent and effect organize commands more usefully than isolated command names.

**Explanation:** This reference assumes an activated feature module, verified placeholder substitutions, a source tree reviewed for secrets, existing pins, and the `/etc/nixos` source root. The temporary stage 6/7 feature settings remain applicable before module activation. Explicit references make the operations independent of working directory. Each owning stage supplies the prerequisites and safety context; the alternatives represent distinct tasks rather than one combined sequence.

**Example:** The task table connects operation scope to its detailed stage:

| Task | Effect | Stage |
| --- | --- | --- |
| Installed-version inspection | READ-ONLY | 1 |
| Selected-hostname inspection | READ-ONLY with evaluation/fetch/cache caveats | 6, 13 |
| System realization without a local link | BUILD-ONLY | 7 |
| Immediate candidate activation with prior boot default retained | SYSTEM CHANGE | 7 |
| Next-boot candidate selection only | SYSTEM CHANGE | 7 |
| Immediate activation and default-boot selection | SYSTEM CHANGE | 7 |
| Missing-pin resolution | SOURCE EDIT plus fetching | 6 |
| Input refresh | SOURCE EDIT plus fetching | 9 |
| Profile inspection, addition, removal, or upgrade | READ-ONLY or USER-PROFILE CHANGE | 5 |
| Earlier OS-generation selection | SYSTEM CHANGE | 10 |
| Development-shell entry or program execution | BUILD-ONLY plus execution | 11 |
| GC preview or unreachable-path collection | READ-ONLY or SYSTEM CHANGE: store deletion | 10 |

**Inspection** — **READ-ONLY**, including Nix evaluation caveats:

```bash
nix --version
nixos-version
nix eval --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
nix profile list
nix profile history
nixos-rebuild list-generations
systemctl --failed
```

**Artifact preparation** — **BUILD-ONLY**, with OS activation unchanged:

```bash
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel
```

**Activation alternatives** — **SYSTEM CHANGE**, one intended mode with authorized administration:

```bash
sudo nixos-rebuild test --flake path:/etc/nixos#workstation
sudo nixos-rebuild boot --flake path:/etc/nixos#workstation
sudo nixos-rebuild switch --flake path:/etc/nixos#workstation
```

**Pin maintenance** — **SOURCE EDIT plus fetching**, requiring authorized source-write access:

```bash
nix flake lock path:/etc/nixos
nix flake update nixpkgs --flake path:/etc/nixos
```

**User-package selection** — **USER-PROFILE CHANGE**, under the ordinary user account; `PROFILE_NAME` denotes the inspected exact name:

```bash
nix profile add github:NixOS/nixpkgs/nixos-26.05#hello
nix profile remove PROFILE_NAME
nix profile upgrade PROFILE_NAME
nix profile rollback
```

**Previous OS-selection recovery** — **SYSTEM CHANGE**, with source/data restoration separate:

```bash
sudo nixos-rebuild switch --rollback
```

**Trusted development-output consumption** — **BUILD-ONLY plus execution**, with normal user file/network access:

```bash
nix develop --no-update-lock-file path:/etc/nixos
nix run --no-update-lock-file path:/etc/nixos#default
```

**GC inspection and optional collection** — **READ-ONLY** preview followed, only after review, by **SYSTEM CHANGE: store deletion**:

```bash
nix store gc --dry-run
nix store gc
```

**Expectation:** An operation is retrievable by purpose with its original prerequisites, source location, effect classification, and recovery boundaries intact.

## Appendix B. Glossary

### Connecting terminology to the mental model

**Rationale:** Terms clarify boundaries when their meaning remains connected to concrete responsibilities.

**Explanation:** The glossary summarizes the distinctions developed through the stages:

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

**Example:** Flake evaluation computes a description. System-output realization obtains artifacts. Activation applies running-system changes. The three terms identify three different transitions.

**Expectation:** The vocabulary maps back to source, store, selection, and runtime responsibilities without obscuring their separate effects.

## Appendix C. Next-step plan

### Progressing through one responsibility at a time

**Rationale:** Small understood changes provide more attributable evidence than adoption of a large unfamiliar configuration.

**Explanation:** A maintenance-learning sequence keeps one machine and one purpose per change:

1. A small package-selection change combines source inspection and building before an activation decision.
2. A small service change combines available recovery access with observation of actual runtime behavior.
3. An input refresh receives source/lock review and a build, with activation scheduled separately.
4. Recovery rehearsal on a noncritical system distinguishes software selection from data restoration.
5. A reusable module follows a second current consumer of the same policy. Package customization follows recipe inspection, and additional tools follow an understood ownership need.

**Example:** A session plan records the intended result, source files and pins, verification criterion, activation decision, and recovery target before the change. The owning stage provides the relevant operation and prerequisites.

**Expectation:** Incremental maintenance has observable success criteria and a defined recovery boundary for every change.

## Appendix D. Sources and evidence limits

### Selecting version-matched references

**Rationale:** Interface behavior and release requirements depend on the installed version rather than a stable URL alone.

**Explanation:** Project-maintained manuals and official source-tree documentation specify the interfaces used in the examples. Project-hosted community wiki material supplies supplementary examples whose release and date require comparison with the primary manuals. The tutorial's `modules/` layout, explicit `path:` references, and small reviewed changes form a consistent learning workflow.

Stable documentation URLs can advance to newer versions. The installed version determines the applicable manual, while links beside claims identify their supporting interface contracts.

**Example:** The configuration manual describes `test` as activation of candidate services while retaining the existing boot default. Stage 7 separates build review from that activation and its persistent-state risks.

**Expectation:** Release-matched interface contracts support deliberate adaptation of the workflow to the verified installation.

### Official documentation by subject

**Rationale:** Primary references supply the deeper contracts needed beyond a small worked configuration.

**Explanation:** Subject grouping separates language syntax, source selection, command effects, and release-specific requirements. The release-note section for the actual current/target versions governs upgrades. Where dated wiki examples differ, the current applicable primary manual supplies the contract.

**Example:** The following references cover the mechanisms developed in the stages:

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

**Expectation:** A bounded official source list supports verification of syntax, effects, release requirements, and adaptation to the machine's verified configuration.
