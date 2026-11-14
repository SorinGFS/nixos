# NixOS, progressively: from first principles to reusable systems

## 1. Scope, safety, and the mental model

### What “zero to hero” means here

**Rationale:** You should know what you are learning before changing a computer you depend on.

**Explanation:** This tutorial assumes no Nix, functional-programming, or declarative-configuration knowledge. “Hero” means being able to explain, inspect, change, build, activate, update, recover, and reuse a modest NixOS configuration—not memorizing every option or becoming a distribution maintainer. It starts with an **already installed NixOS machine**. Installation, partitioning, bootloader selection, hardware drivers, and migration from another distribution are outside its scope; use the [official NixOS manual](https://nixos.org/manual/nixos/stable/) for those machine-specific decisions. Nix package and language exercises also make sense on another supported system with Nix installed, but NixOS activation commands do not.

The documentation baseline is **NixOS 26.05 and the Nix 2.34.9 reference manual**, from sources retrieved **2026-11-14 UTC**. This is not a claim about your installed release. The stable NixOS manual names the `nixos-26.05` branch; the retrieved Nix reference identifies itself as 2.34.9. Interfaces and options can differ on your machine. Do not turn this exercise into an accidental release upgrade.

**Example:** **READ-ONLY**, from any directory, record your actual versions before proceeding:

```bash
nix --version
nixos-version
```

On a non-NixOS host, the second command may not exist; stop before the system-configuration stages. No installation commands are provided here.

**Expected outcome:** You know whether the NixOS stages apply and can compare your actual versions with this tutorial’s documentation baseline.

### The most important mental model

**Rationale:** Much confusion comes from treating “a package exists,” “a package is available,” and “a system is running” as the same event.

**Explanation:** **Source describes a desired result; Nix prepares results in the store; a profile or activation step chooses what becomes available or runs.** Editing a file is not activation. Downloading a package is not enabling its service. Updating pins is not updating a running machine.

Think of a recipe book, a pantry of prepared results, and a selected menu. This analogy helps separate description, storage, and selection. Its limit: a real computer also has mutable files, processes, devices, and databases; Nix does not freeze or restore all of those.

[Video insight, approximately 00:03:00–00:15:00](https://www.youtube.com/watch?v=zdZvKWpNzU8&t=180s): the recipe and dependency discussion is a useful introduction. The more precise implementation model comes from the [derivation reference](https://nix.dev/manual/nix/stable/language/derivations.html) and [NixOS configuration manual](https://nixos.org/manual/nixos/stable/#sec-changing-config).

**Example:** No command is needed. Imagine changing a package list in a text editor: the source has changed, but your current terminal and services have not. Building the result prepares it; activation is a separate decision.

**Expected outcome:** Before any operation, you can ask: “Am I changing source, preparing artifacts, changing my profile, or activating the operating system?”

### Reading path and command conventions

**Rationale:** Safe examples need explicit prerequisites, locations, and effects.

**Explanation:** Follow the dependencies in order: [mental model](#1-scope-safety-and-the-mental-model) → [pieces and evaluation](#2-meet-the-pieces-and-evaluate-a-first-expression) → [language](#3-read-the-nix-language-without-prior-programming-knowledge) → [modules](#4-understand-the-installed-configuration-and-modules) → [package scope](#5-choose-package-scope-temporary-use-user-profile-or-system) → [flake](#6-wrap-the-existing-system-in-one-flake) → [activation](#7-build-test-and-activate-deliberately) → [services](#8-add-users-networking-services-and-an-optional-desktop) → [updates](#9-update-inputs-pin-revisions-and-plan-release-upgrades) → [recovery](#10-recover-safely-and-understand-garbage-collection) → [development](#11-extend-the-same-flake-with-development-tools) → [reuse](#12-reuse-modules-customize-packages-and-compose-more-machines) → [diagnosis](#13-troubleshoot-systematically-and-choose-the-next-step). Advanced material depends on the same small configuration. References: [commands by task](#appendix-a-command-reference-by-task), [glossary](#appendix-b-glossary), [next steps](#appendix-c-next-step-plan), and [sources](#appendix-d-sources-and-evidence-limits).

A terminal is a window for entering commands. A shell interprets them; Bash is the shell syntax used here. Run one command at a time and read its output before continuing. A command's working directory is its current folder. `PATH` is the list of folders the shell searches for executables, so the same command name can select different installed copies. Nix code belongs in Nix files or the explicitly quoted expression argument—not pasted directly into the shell.

Every shell block uses Bash syntax, omits prompt characters, and uses one physical line per command. Commands are instructions for you to consider, **not commands executed while authoring this document**. Nix examples were cross-checked against retrieved documentation, not evaluated or built.

Effect labels mean:

| Label | Meaning |
| --- | --- |
| **READ-ONLY** | Intended inspection; Nix evaluation of external sources may still fetch, write caches/store metadata, or build through import-from-derivation. It is not universally effect-free. |
| **BUILD-ONLY** | May download, write the store/cache, and execute builders; does not activate the OS. |
| **SOURCE EDIT** | Changes configuration or lock files; may also fetch inputs when locking. |
| **USER-PROFILE CHANGE** | Changes packages selected for the invoking user, not the OS generation. |
| **SYSTEM CHANGE** | Activates services, accounts, networking, boot choices, passwords, or performs store cleanup. Read its specific warning. |

Running an application or entering a development shell adds execution effects beyond BUILD-ONLY: applications and `shellHook` code run with your permissions. A Nix shell is **not** a security sandbox.

`root` is the system administrator account. Use `sudo` only if installed, configured, and authorized for you. Otherwise, if authorized and you have the root password, use `su -` to enter a root shell and omit `sudo` from the indicated administrative commands; `exit` leaves that shell. Do not use root to run ordinary package experiments. Protect source edits under `/etc/nixos` using your existing authorized editing workflow; no particular editor is assumed.

**Example:** No command is needed. In “from any directory,” the working directory is irrelevant. In “from `/etc/nixos`,” enter that directory first or use the exact absolute `path:` reference shown. Text such as `REPLACE_WITH_SYSTEM`, `COMMIT`, and `PROFILE_NAME` must be replaced, not typed literally. `workstation` is a deliberately fictional flake output name used consistently below—not your detected hostname.

**Expected outcome:** You can identify prerequisites and side effects before copying an example, and know when to stop rather than invent missing machine details.

### Practice: classify a proposed change

**Rationale:** Correct classification is more valuable than memorizing a command.

**Explanation:** Source, store, user environment, and running system are separate layers.

**Example:** No command is needed. A friend edits a package list, updates `flake.lock`, builds the system, and then claims the new SSH service must already be running. Which claim is unsupported?

**Expected outcome:** Success criterion: name the missing transition without assuming a successful build proves runtime behavior.

<details>
<summary>Worked solution</summary>

Neither editing, locking, nor building activates SSH. The missing transition is system activation, followed by a runtime service check. Even activation can fail or leave partially changed services; inspect the result.

</details>

## 2. Meet the pieces and evaluate a first expression

### Nix, Nixpkgs, NixOS, the store, and flakes

**Rationale:** Similar names hide different responsibilities.

**Explanation:** **Nix** names both the configuration language and the package-management/build tooling. **Nixpkgs** is a collection of package definitions and supporting libraries written largely in that language. **NixOS** is a Linux distribution whose system configuration is assembled using Nix and Nixpkgs. The **Nix store**, normally `/nix/store`, holds source snapshots, build descriptions, packages, and generated files. A **flake** is a source tree with a standardized `flake.nix` entrypoint describing inputs and outputs; it is not another package manager or a requirement for using NixOS.

Nix can manage packages without managing the host OS. NixOS goes further by composing operating-system files and services. See [language basics](https://nix.dev/tutorials/nix-language.html), [profiles](https://nix.dev/manual/nix/stable/package-management/profiles.html), and [flake concepts](https://nix.dev/concepts/flakes.html).

**Example:** No command is needed. “Use Nixpkgs’ Hello package in a shell” needs Nix but not NixOS. “Declare the machine’s SSH service” uses NixOS modules. “Pin the Nixpkgs revision” is one job a flake lock can perform.

**Expected outcome:** You can say which component supplies syntax, recipes, storage, OS integration, and input pinning.

### Evaluation before building

**Rationale:** A tiny calculation gives immediate feedback without changing the system configuration.

**Explanation:** An **expression** is code that produces a value. **Evaluation** computes that value. Nix’s modern CLI and flakes remain experimental in this reference version; enabling them is an explicit choice, not proof that all interfaces are stable. The following command enables the needed features for that invocation only. Later we add a small NixOS module to enable them persistently. The global `--extra-experimental-features` flag adds features rather than replacing other configured ones. See [flake feature enablement](https://nix.dev/concepts/flakes.html) and [`nix eval`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html).

**Example:** **READ-ONLY**, from any directory; this self-contained arithmetic expression has no external inputs:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --expr '1 + 2'
```

**Expected outcome:** Nix prints `3`. A missing executable or unsupported flag is a version/setup issue, not a reason to reinstall your system blindly.

### From evaluation to a running system

**Rationale:** The word “rebuild” can suggest recompiling everything on every edit. Usually that is not what happens.

**Explanation:** Evaluation can produce a **derivation**, a build recipe identifying a builder and inputs. Nix records store-level build descriptions, then realizes needed outputs by fetching substitutes from configured binary caches or executing builds. Dependencies form a graph. A package’s **closure** includes its referenced runtime dependencies. NixOS assembles a top-level system result; activation then makes relevant changes to the running machine.

Different versions and build variants can coexist at different store paths. Treat store results as immutable: change source and rebuild rather than editing files inside `/nix/store` ([NixOS store management](https://nixos.org/manual/nixos/stable/)). This does not make your documents or application databases immutable. The hash-like part of a store path is **not necessarily a checksum of the output contents**; input-addressed derivations commonly identify outputs from build inputs. Do not infer bit-for-bit reproducibility from a path name. See [derivations](https://nix.dev/manual/nix/stable/language/derivations.html) and [profiles](https://nix.dev/manual/nix/stable/package-management/profiles.html).

Benefits include explicit dependencies and retained generations. Costs include disk use, evaluation complexity, cache/network dependence, and potentially expensive rebuilds when foundational inputs change. Not every downloaded non-Nix binary works unmodified on NixOS.

**Example:** No command is needed. Changing only a text configuration may reuse most packages. Changing a foundational library can require many downstream builds if substitutes are unavailable. Neither case automatically changes your documents or database schema safely.

**Expected outcome:** You can distinguish evaluation failure, build/fetch failure, and activation/runtime failure.

### Practice: follow the graph

**Rationale:** Understanding dependency direction prevents mistaken cleanup decisions.

**Explanation:** A program may still need a library even if you never selected that library explicitly.

**Example:** No command is needed. A selected editor references a runtime library in the store. Should you manually delete that library because it is absent from your package list?

**Expected outcome:** Success criterion: explain why package-list membership is not the same as store reachability.

<details>
<summary>Worked solution</summary>

No. The selected editor’s closure needs the library. Let Nix manage store reachability and garbage collection; never manually delete store files to “uninstall” dependencies.

</details>

## 3. Read the Nix language without prior programming knowledge

### Values, lists, and attribute sets

**Rationale:** Most configuration is structured data, not a sequence of imperative instructions.

**Explanation:** A **string** is text in double quotes; a **Boolean** is `true` or `false`; numbers are unquoted; `null` means absence where accepted. A **list** uses square brackets and whitespace, not commas. An **attribute set** maps names to values inside braces; assignments end with semicolons. A dot selects a nested attribute, and dotted assignments construct nested sets. This is language structure; only the module system gives paths such as `services.openssh.enable` their NixOS meaning. See [official language basics](https://nix.dev/tutorials/nix-language.html).

**Example:** No shell command is needed. This is a complete standalone Nix expression for reading, not a NixOS module:

```nix
# Represent sample data; these names are not NixOS options.
{
    title = "Learning Nix";
    enabled = true;
    attempts = 2;
    optionalValue = null;
    tools = [ "hello" "git" ];
    machine.role = "practice";
}
```

`machine.role` is equivalent to `machine = { role = "practice"; };`. Unlike many languages, repeated assignment does not mean “change the variable later”; duplicate attributes in one ordinary set are errors.

**Expected outcome:** You can distinguish text, a list, and a nested set, and spot missing semicolons or inappropriate commas.

### Names, interpolation, and operators

**Rationale:** Naming a value lets you reuse it without copying configuration.

**Explanation:** `let ... in ...` introduces local names, then returns the expression after `in`. It is not a loop or a sequence of mutations. `${expression}` inserts a string-compatible value into a string; use `toString` for a number. `'' ... ''` is an indented multiline string. `./file.nix` is a path relative to the Nix file containing it, not the caller’s shell directory; `"./file.nix"` is just text.

`++` joins lists. `//` combines ordinary attribute sets with right-hand replacement for matching top-level keys; it is **not** the NixOS option-merging algorithm. `==` compares values, `&&` means Boolean “and,” and `if condition then value else otherValue` chooses a value. `inherit name;` abbreviates `name = name;`; `inherit (set) name;` abbreviates `name = set.name;`. `with pkgs; [ hello git ]` opens names for that expression, but explicit `pkgs.hello` is clearer while learning.

**Example:** **READ-ONLY**, from any directory, using only local literal values:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --expr 'let count = 2; tools = [ "hello" ]; in { message = "${toString count} tools"; selected = tools ++ [ "git" ]; }'
```

**Expected outcome:** The result has `message = "2 tools"` and `selected = [ "hello" "git" ]`. Attribute order in printed output need not follow source order.

### Functions, imports, and laziness

**Rationale:** The first line of a typical module is easier once you recognize a function.

**Explanation:** A **function** takes an input and produces a value. `x: x + 1` takes one number. Calling it uses whitespace: `(x: x + 1) 2`. `{ name, suffix ? "!" }: name + suffix` takes a set of named arguments; `?` supplies a default. In a function parameter pattern, `...` accepts additional arguments—it is real syntax, not omitted example code. `{ pkgs, ... }:` therefore means “accept an argument set containing `pkgs` and possibly other fields.”

`import ./file.nix` evaluates that file and returns its value. If the file returns a function, apply arguments separately, as in `(import ./function.nix) { name = "Learner"; }`. `builtins.import` is the underlying builtin; ordinary `import` is available by default. NixOS `imports` instead tells the module system which modules to collect and merge; it is not merely textual inclusion or identical to calling `import` yourself.

Nix is **lazy**: values are computed when needed. It is **functional**: bindings describe values rather than repeatedly mutating variables. Laziness can delay errors and make traces indirect; it does not mean arbitrary evaluated code is harmless. See [language basics](https://nix.dev/tutorials/nix-language.html).

**Example:** No command is needed. This complete expression returns `"Hello, Learner!"`:

```nix
# Apply a small function using a named argument and a default suffix.
let
    greet = { name, suffix ? "!" }: "Hello, ${name}${suffix}";
in
    greet { name = "Learner"; }
```

**Expected outcome:** You can read the argument set, colon, returned value, and function application without mistaking them for shell syntax.

### Practice: repair a value

**Rationale:** Small syntax errors should be understandable before they appear in a large build trace.

**Explanation:** Strings and Booleans are distinct values; list elements are whitespace-separated.

**Example:** No command is needed. Write a complete set with Boolean `enabled`, a list containing the strings `hello` and `git`, and a numeric `count` equal to their number.

**Expected outcome:** Success criterion: three attributes, no commas between list elements, and no quotes around `true` or the number.

<details>
<summary>Worked solution</summary>

```nix
# Keep sample values typed correctly.
{
    enabled = true;
    tools = [ "hello" "git" ];
    count = 2;
}
```

</details>

## 4. Understand the installed configuration and modules

### Preserve the machine you already have

**Rationale:** A minimal internet example is not a replacement for a working machine’s boot, storage, users, or hardware configuration.

**Explanation:** `/etc/nixos/configuration.nix` is typically a NixOS module importing `hardware-configuration.nix` and defining options. Your installation may use more files or another entrypoint. Read its actual imports before proceeding. **Keep existing hardware imports, file systems, boot settings, accounts, access methods, networking, and `system.stateVersion`.** Make an independently recoverable backup of configuration and important data using your existing backup method. Keep a known-good bootable generation and recovery access.

`system.stateVersion` selects compatibility defaults for stateful behavior. It is not the NixOS release selector and should not be bumped to match an input branch. Change it only as part of a deliberate state migration. See [installation/configuration guidance](https://nixos.org/manual/nixos/stable/).

**Example:** **READ-ONLY**, from any directory; these read the two conventional files without changing them:

```bash
less /etc/nixos/configuration.nix
less /etc/nixos/hardware-configuration.nix
```

If either is absent, follow the imports in your actual configuration rather than creating a guessed replacement. `q` exits `less`.

**Expected outcome:** You can identify the configuration’s entrypoint and hardware import, and have a recovery plan before editing.

### Options and the supplied module arguments

**Rationale:** A NixOS option is a declared interface, not an arbitrary key that magically becomes an OS setting.

**Explanation:** A module may be a set or a function returning module definitions. The module system supplies `pkgs` (the selected package set), `lib` (helper functions), and `config` (the merged configuration), among other arguments. An **option declaration** defines a name, type, documentation, and often a default. An **option definition** supplies a value. Unknown options and wrong types cause evaluation errors.

A package installed through `environment.systemPackages` exposes executables system-wide; it does not necessarily register services, D-Bus integration, or other needed system behavior. Prefer the relevant NixOS service/program option when that integration is required. See [configuration syntax](https://nixos.org/manual/nixos/stable/#sec-configuration-syntax) and [package management](https://nixos.org/manual/nixos/stable/#sec-package-management).

**Example:** **SOURCE EDIT**, using an authorized editor, create `/etc/nixos/modules/cli-tools.nix` with this complete content. Create the ordinary `modules/` directory if needed through your editing workflow. Do not replace `configuration.nix`.

```nix
# Add small command-line tools without changing hardware or services.
{ pkgs, ... }:
{
    environment.systemPackages = [ pkgs.hello pkgs.git ];
}
```

This file has no effect until included in the module graph; stage 6 will include it through the flake. Do not also add a second independent copy of these definitions elsewhere.

**Expected outcome:** A separate, readable module exists in source, while the running system is unchanged.

### Definitions merge; file order is not a universal override

**Rationale:** “The last file wins” leads to surprising conflicts and accidentally removed packages.

**Explanation:** The module system collects definitions and merges them according to option type and priority. Package lists generally concatenate. Conflicting scalar values at the same effective priority can fail rather than silently replace each other. `lib.mkDefault` makes a definition easier for an ordinary definition to replace; `lib.mkForce` deliberately overrides ordinary definitions. Force is not a general fix for every conflict. Ordering helpers such as `mkBefore` affect list order, not which priority wins.

Contrast this with ordinary language `//`: it performs set replacement, not module-aware typed merging. Module `imports` describes a graph, not an imperative series of files. See [the manual’s Modularity section](https://nixos.org/manual/nixos/stable/) and [setting priorities](https://nixos.org/manual/nixos/stable/#sec-option-definitions-setting-priorities).

**Example:** No command is needed. This is a complete illustrative module, **not** a file to add to the tutorial spine:

```nix
# Offer a replaceable hostname default, not an enforced machine identity.
{ lib, ... }:
{
    networking.hostName = lib.mkDefault "workstation";
}
```

If another module defines `networking.hostName = "another-name";`, that ordinary definition wins over this default. Two ordinary conflicting names require investigation.

**Expected outcome:** You can predict why two package lists can combine while two conflicting hostnames can cause an error.

### Practice: choose what to keep

**Rationale:** Preserving installation-specific information is a prerequisite for a useful rebuild.

**Explanation:** Shared software settings and machine hardware have different owners.

**Example:** No command is needed. You find a short online module enabling an editor. Should it replace your current `configuration.nix`, including its hardware import and existing administrator?

**Expected outcome:** Success criterion: explain a composition method that preserves all installed-machine settings.

<details>
<summary>Worked solution</summary>

Keep `configuration.nix` and its imports. Put the new package definition in a separate module and include both in the system composition. Do not copy another machine’s storage IDs, bootloader, user, or `stateVersion`.

</details>

## 5. Choose package scope: temporary use, user profile, or system

### Try a package without adding it to the OS

**Rationale:** A small package experiment is easier to undo than a system configuration change.

**Explanation:** `nix run` builds/fetches an app or suitable package and runs it; `--` separates application arguments. Direct GitHub flake references work without adding an input to your own flake. These examples explicitly select a branch rather than relying on a machine-dependent `nixpkgs` registry alias. A branch reference is not an enduring pin.

The retrieved manual labels its shell command page `nix env shell` while its description and usage examples document the familiar `nix shell` spelling. Here we use the documented `nix shell` form; consult your installed help if names differ. Do not confuse it with legacy `nix-shell`, which has different conventions. See [`nix run`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html) and [the shell reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-env-shell.html).

**Example:** **BUILD-ONLY plus application execution**, from any directory; trust the referenced source before running it:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:NixOS/nixpkgs/nixos-26.05#hello -- --greeting 'Hello from Nix'
nix --extra-experimental-features 'nix-command flakes' shell github:NixOS/nixpkgs/nixos-26.05#hello --command hello
```

The first prints your greeting; the second prints Hello’s default greeting. Neither adds a package to the system package list. A shell provides tools on `PATH`; it does not isolate access to your files or network.

**Expected outcome:** You can use a trusted tool once without changing the selected OS generation or persistent user profile.

### A user profile is its own history

**Rationale:** Imperative package management is useful, but it should not be mistaken for the declarative OS specification.

**Explanation:** **Imperative** means asking for a change now, such as adding one package to your profile. **Declarative** means recording the desired package set in source and rebuilding from that description. Both can coexist, but overlapping selections can confuse which executable your shell finds first.

Modern `nix profile` maintains the invoking user’s package selections and history. Do not use `sudo` here: it would target a different user. Its format is not interchangeable with legacy `nix-env` profiles; if you encounter a format error, inspect the existing workflow rather than mixing commands to force a conversion. Profile rollback is not NixOS rollback. See [profile add](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-add.html), [list](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-list.html), and [rollback](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-rollback.html).

**Example:** From any directory, the first and third commands are **READ-ONLY**; the others are **USER-PROFILE CHANGE**. Try the add only if you want Hello in your modern profile:

```bash
nix --extra-experimental-features 'nix-command flakes' profile list
nix --extra-experimental-features 'nix-command flakes' profile add github:NixOS/nixpkgs/nixos-26.05#hello
nix --extra-experimental-features 'nix-command flakes' profile history
nix --extra-experimental-features 'nix-command flakes' profile rollback
```

If other profile operations happened in between, rollback returns to the most recent older profile version, not necessarily your intended state. Inspect history first.

**Expected outcome:** You can distinguish a package being selected for you from it being declared for all system users.

### Remove and upgrade at the correct layer

**Rationale:** Removing a package from the wrong layer can appear to do nothing.

**Explanation:** For a modern profile, use the package name reported by `profile list`. For system packages, edit the relevant module and rebuild. Removing selection does not immediately erase store files; old generations and dependencies may retain them. Upgrading a profile package from an unlocked reference follows that reference; a package installed using a locked commit reference does not acquire a newer commit automatically. See [profile remove](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html) and [profile upgrade](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-upgrade.html).

**Example:** **USER-PROFILE CHANGE**, from any directory, alternatives rather than a required sequence. Replace `PROFILE_NAME` with the exact name from your list:

```bash
nix --extra-experimental-features 'nix-command flakes' profile remove PROFILE_NAME
nix --extra-experimental-features 'nix-command flakes' profile upgrade PROFILE_NAME
```

For the declarative module from stage 4, remove `pkgs.hello` from its list if you no longer want it system-wide; stage 7 teaches the rebuild. A package may still be visible through another profile or environment.

**Expected outcome:** You know which source of package exposure to change and do not manually delete store files.

### Practice: explain a stubborn executable

**Rationale:** Multiple selection layers are intentional, but can surprise you.

**Explanation:** A command can appear on `PATH` through your system, user profile, or current development shell.

**Example:** No command is needed. You remove Hello from your user profile, but it remains available after activating `cli-tools.nix`. Is removal necessarily broken?

**Expected outcome:** Success criterion: identify another valid owner and the appropriate declarative change.

<details>
<summary>Worked solution</summary>

No. `environment.systemPackages` also selects Hello. Remove it from `modules/cli-tools.nix`, rebuild and activate deliberately, then test in a fresh shell. A temporary shell can introduce yet another copy.

</details>

## 6. Wrap the existing system in one flake

### Inputs, outputs, and the lock file

**Rationale:** Pinning makes dependency choices visible rather than relying on whichever channel happens to be current.

**Explanation:** `flake.nix` names desired inputs and computes outputs. `flake.lock` records resolved dependencies, typically including revisions and content hashes. `inputs.nixpkgs.url` chooses a source; the lock resolves a branch to a particular revision. The `outputs` function receives inputs and returns named results. Merely adding an input installs nothing.

Common output families include `packages.<system>.<name>`, `apps.<system>.<name>`, `devShells.<system>.<name>`, complete `nixosConfigurations.<name>`, and reusable `nixosModules.<name>`. The architecture/OS pair, such as `x86_64-linux` or `aarch64-linux`, matters for packages and systems. A NixOS configuration attribute is a label chosen by the author, not an architecture.

Pins improve repeatability but do not back up user data, capture all runtime state, guarantee source availability forever, or prove every build is byte-identical. Flakes remain experimental in the reference implementation. Non-flake NixOS workflows remain legitimate. The [NixOS 26.05 release highlights](https://nixos.org/manual/nixos/stable/release-notes.html#sec-release-26.05-highlights) document `system.nix` as an alternative entrypoint to `configuration.nix` and `flake.nix`. This tutorial follows one flake workflow rather than mixing entrypoints. See the [flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).

**Example:** No command is needed. Think of `flake.nix` as “use this branch and expose this system,” and the lock as “use this exact resolved input tree.” Changing either does not activate the machine.

**Expected outcome:** You can explain why source, pins, and running system need separate inspection.

### Establish the layout and replace the architecture placeholder

**Rationale:** A thin wrapper preserves the installed configuration and avoids silently assuming your CPU or hostname.

**Explanation:** Use `/etc/nixos` as the source root for this tutorial. The examples consistently use explicit `path:/etc/nixos` references, so their local-source behavior does not depend on whether this directory is in Git. **Before doing so, ensure the tree contains only configuration source safe for other local users to read.** A path source can include untracked/private files that Git-backed filtering would omit; source snapshots go into the normally world-readable store. Never put passwords, private keys, tokens, or sensitive backups there. Store paths and package absence from another user’s `PATH` are not confidentiality boundaries.

The following tree is the intended source layout, not a command or a replacement for existing additional files:

**Example:** **SOURCE EDIT** for the new files only:

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

To identify the native Nix platform, **READ-ONLY**, from any directory:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --impure --raw --expr builtins.currentSystem
```

`--impure` is narrowly used here to inspect the current installation’s platform, not as a workaround in your flake. Compare the result with any existing `nixpkgs.hostPlatform` setting. For native configuration they should agree; cross-compilation is deferred. Replace **every** `REPLACE_WITH_SYSTEM` below with the verified pair before use.

**Expected outcome:** You have a source layout and a verified platform string, with private material kept outside the source snapshot.

### Create the initial spine

**Rationale:** A complete small flake is easier to inspect than a giant borrowed configuration.

**Explanation:** `nixpkgs.lib.nixosSystem` composes modules into a complete NixOS configuration. Here `workstation` is only the output attribute selected after `#`; it does **not** set `networking.hostName`. Keep your actual hostname unchanged. The modules list includes your existing `configuration.nix`, which retains its own hardware imports, and two small additional modules.

If your installed release is not 26.05, **do not proceed with this branch unchanged**. Either use the branch matching the release you intend to maintain, after checking its documentation and option names, or plan a release upgrade separately in stage 9. The architecture placeholder is likewise mandatory.

**Example:** **SOURCE EDIT**, create `/etc/nixos/modules/nix-cli.nix`:

```nix
# Enable the CLI features used by this tutorial after system activation.
{ ... }:
{
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

Create `/etc/nixos/flake.nix` with this complete content, replacing the platform string:

```nix
# Wrap the installed machine without replacing its hardware or account setup.
{
    description = "Progressive NixOS configuration";
    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Compose one complete system from existing and additional modules.
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

`self` denotes this flake; it need not be used just because it is accepted as an argument. `lib` here comes from the selected Nixpkgs input, not a separately required utility flake. No third-party framework is needed.

**Expected outcome:** A single explicit system composition exists while installed hardware, users, boot configuration, hostname, and state compatibility settings remain owned by the existing module.

### Lock and inspect before activation

**Rationale:** Establish pins deliberately, then inspect the exact output you intend to build.

**Explanation:** `nix flake lock` creates missing entries and preserves still-valid existing pins rather than blindly refreshing them. Changing a requested input URL may require its corresponding lock entry to change. Preserve a known-good source/lock pair before edits. Nix-generated JSON is not a file to fill with invented hashes.

If you later choose implicit local Git-backed references instead of this tutorial’s explicit `path:` form, new files must be added to Git’s index to enter the flake snapshot. Dirty changes to already tracked files are normally included with a warning. A commit is not required just to test tracked changes. We do not perform or require Git operations here. Imports must stay within the source tree captured by the flake; an absolute import of a private outside file is not a portable pure-flake design. See [local flake sources](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html) and [locking](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html).

**Example:** First, **SOURCE EDIT plus input fetching**, using authorized write access to `/etc/nixos`:

```bash
nix --extra-experimental-features 'nix-command flakes' flake lock path:/etc/nixos
```

Then **READ-ONLY with evaluation/fetch/cache caveats**, from any directory:

```bash
nix --extra-experimental-features 'nix-command flakes' eval --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

The lock command must be run by an account allowed to write that source; do not casually change its ownership or permissions. Use your existing administrative workflow if needed. `--no-update-lock-file` makes inspection fail if lock changes would be needed instead of silently accepting new pins.

**Expected outcome:** `flake.lock` contains real resolved inputs, and evaluation prints your preserved hostname—not necessarily `workstation`. No system has been activated.

### Practice: output name versus hostname

**Rationale:** Explicit naming avoids relying on automatic hostname selection.

**Explanation:** `nixosConfigurations.workstation` identifies an output, while `networking.hostName` configures an OS property.

**Example:** No command is needed. Your real machine reports a different hostname. Must you rename it before selecting `path:/etc/nixos#workstation`?

**Expected outcome:** Success criterion: explain why that selector is still valid.

<details>
<summary>Worked solution</summary>

No. The explicit selector chooses the `workstation` configuration attribute. Its composed modules retain the machine’s actual hostname. Automatic hostname matching is unnecessary when the attribute is supplied explicitly.

</details>

## 7. Build, test, and activate deliberately

### Build without selecting a new system

**Rationale:** Find evaluation and build failures before changing services.

**Explanation:** A complete NixOS configuration exposes `config.system.build.toplevel`, the system result to build. `nix build --no-link` avoids creating a `result` symlink in your working directory; `--print-out-paths` prints output locations instead. A successful build proves artifacts can be realized with the chosen inputs, not that your hardware, remote access, or application behavior is correct. Without an enduring GC root, an otherwise unused build result can later be collected. See [`nix build`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-build.html).

**Example:** **BUILD-ONLY**, from any directory, after placeholder replacement and locking:

```bash
nix --extra-experimental-features 'nix-command flakes' build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel
```

Do not run as root merely to build. It can download substantial data or execute package builders and consume disk/CPU. Read errors before proceeding.

**Expected outcome:** Nix prints a realized `/nix/store/…-nixos-system-…` path, without selecting it as the running or default boot system and without leaving a local result link.

### Choose the activation mode

**Rationale:** The differences between `build`, `test`, `boot`, and `switch` are safety-relevant, not stylistic.

**Explanation:** The [NixOS configuration manual](https://nixos.org/manual/nixos/stable/#sec-changing-config) distinguishes:

| Mode | Running system | Default for future boot |
| --- | --- | --- |
| `build` | Unchanged; prepare output only | Unchanged |
| `test` | **Activates** the candidate now | Not changed to the candidate |
| `boot` | Does not activate candidate services now | Sets candidate as default |
| `switch` | **Activates** now | Sets candidate as default |

Our build uses the direct `nix build --no-link` form above rather than `nixos-rebuild build`, which commonly leaves a result link. Administrative activation uses `nixos-rebuild` with the same explicit flake selector. `test` is not a dry run: services may restart, connections may drop, and stateful services may write or migrate data. Rebooting to the previous default does not reverse those persistent effects. Activation failure is not guaranteed automatic rollback; partial activation is possible.

**Example:** **SYSTEM CHANGE**, from any directory, alternatives—not a block to run indiscriminately. Have local console/recovery access and backups first. These retain a per-invocation feature flag until the feature module has actually been activated:

```bash
sudo nixos-rebuild test --flake path:/etc/nixos#workstation --option extra-experimental-features 'nix-command flakes'
sudo nixos-rebuild boot --flake path:/etc/nixos#workstation --option extra-experimental-features 'nix-command flakes'
sudo nixos-rebuild switch --flake path:/etc/nixos#workstation --option extra-experimental-features 'nix-command flakes'
```

Use only the mode you intend, and review your installed `nixos-rebuild --help` if its flags differ. Administrative alternatives are explained in stage 1. Preserve the source/lock pair between build and activation so you activate what you reviewed.

**Expected outcome:** You can predict both immediate and next-boot effects, and do not describe `test` as harmless inspection.

### Verify the result instead of trusting the exit code alone

**Rationale:** A build and an activation can succeed while a service or workflow still fails.

**Explanation:** Check the changed feature, existing access methods, and relevant logs. Kernel/boot-sensitive changes may require a reboot; a running userspace transition is not identical to a fresh boot. User services also have lifecycle details that a system rebuild does not universally restart for you. The [manual’s warnings](https://nixos.org/manual/nixos/stable/#sec-changing-config) explain this limitation.

After activating `nix-cli.nix`, later modern CLI examples omit the temporary feature flag. If you have not activated it, keep using the same `--extra-experimental-features 'nix-command flakes'` prefix for `nix` commands. Do not assume editing that module changed CLI settings.

**Example:** **READ-ONLY**, from any directory, after a successful activation of `cli-tools.nix`:

```bash
command -v hello
hello --version
nixos-version
systemctl --failed
```

Here `hello --version` executes the selected trusted program solely to inspect its version. A fresh terminal may be needed to avoid stale shell command lookup. Compare the actual result with your intended change and check that previously working access still works.

**Expected outcome:** You have observed functional evidence, or you stop and diagnose the mismatch rather than repeatedly activating an unexplained failure.

### Practice: choose a mode

**Rationale:** Mode choice should follow a goal, not a memorized habit.

**Explanation:** Preparing artifacts and changing a running service are separate commitments.

**Example:** No command is needed. You want to discover whether a package builds without changing services. Later, you want the candidate selected for the next boot but not activated now. Which two operations fit?

**Expected outcome:** Success criterion: select build-only first and distinguish `boot` from `test`.

<details>
<summary>Worked solution</summary>

First use the direct top-level `nix build --no-link` command. Later use `nixos-rebuild boot --flake path:/etc/nixos#workstation` with authorized administrative privileges. `test` would activate now, which is not the second goal.

</details>

## 8. Add users, networking, services, and an optional desktop

### Understand accounts without replacing your administrator

**Rationale:** Account examples can lock you out if copied over an installed account setup.

**Explanation:** Keep your existing administrator and authentication method. An additional normal account is optional, not needed to learn modules. Do not set `users.mutableUsers = false` as a tutorial shortcut; it changes account ownership semantics. With ordinary mutable user management, a newly declared user has no password by default. Set one interactively after activation if password login is intended. Never embed a plaintext password or private key in a Nix string; source and generated artifacts can enter the store. See [user management](https://nixos.org/manual/nixos/stable/#sec-user-management).

**Example:** **SOURCE EDIT**, optional complete `/etc/nixos/modules/practice-user.nix`. `learner` is a fictional new account; choose a non-conflicting name and replace it consistently. Do not copy this into an existing user definition or grant administrative groups just to follow the tutorial:

```nix
# Declare an optional non-administrative account; credentials stay out of source.
{ ... }:
{
    users.users.learner = {
        isNormalUser = true;
        description = "Practice account";
    };
}
```

To include any optional module in this stage, add its `./modules/NAME.nix` path to the **existing** `modules` list in `flake.nix`, preserving all current entries. Then inspect, build, and deliberately activate as in stage 7. Only after the account exists, **SYSTEM CHANGE**, from any directory, if authorized:

```bash
sudo passwd learner
```

Enter the password at the prompt, never in configuration source. If you already use immutable account management, consult its password-file options and your established secret-management process instead of assuming this procedure applies.

**Expected outcome:** You understand how a module declares an account without replacing the working administrator or exposing credentials.

### Keep networking changes separate from service experiments

**Rationale:** Networking is not a safe place for a blind “reasonable default,” especially over SSH.

**Explanation:** Retain the installed networking backend, interface configuration, Wi-Fi credentials, firewall, and hostname. Do not enable NetworkManager on top of another backend merely because a tutorial mentions it. `networking.hostName` is a NixOS option, not the flake configuration selector. Replacing a hostname can affect applications and remote access, so it remains an explicit machine decision.

A service’s package and its operating-system integration are different. Enabling OpenSSH starts an SSH server after activation; firewall exposure and authentication must be reviewed independently. `openFirewall = false` prevents this module from automatically adding an allow rule; it does **not** prove the service is unreachable if another rule already allows it. See [NixOS configuration and networking](https://nixos.org/manual/nixos/stable/).

**Example:** **SOURCE EDIT**, optional `/etc/nixos/modules/ssh.nix`, for a machine where you have reviewed authentication and existing rules:

```nix
# Enable SSH integration without requesting an automatic firewall opening.
{ ... }:
{
    services.openssh = {
        enable = true;
        openFirewall = false;
    };
}
```

Include it using the existing modules list only if wanted. If this machine already has SSH settings, reconcile them rather than override them blindly. Do not disable password login or change keys until an alternate verified login works. A remote-only reader should postpone account/network/SSH changes until recovery access is available.

**Expected outcome:** You can explain the intended service change and its remaining network/access risks before activation.

### Inspect a service; optionally choose a desktop

**Rationale:** Runtime inspection turns a configuration claim into observed behavior; a desktop is a larger optional integration choice.

**Explanation:** After an authorized SSH activation, inspect its service and recent logs. Log access can require additional privileges; request only those you are authorized to use. Keep logs private when asking for help: they can contain hostnames, addresses, and other sensitive details.

For a graphical machine that needs GNOME, the retrieved stable manual uses `services.desktopManager.gnome.enable` and `services.displayManager.gdm.enable`. Do not substitute older `services.xserver.desktopManager` keys from unrelated tutorials. Do not add another display manager over the existing one without a deliberate migration, and do not assume GPU or display-driver settings. See [GNOME configuration](https://nixos.org/manual/nixos/stable/#sec-gnome-enable).

**Example:** **READ-ONLY**, from any directory, after enabling SSH:

```bash
systemctl status sshd
journalctl -u sshd -b --no-pager -n 50
```

Optional **SOURCE EDIT**, complete `/etc/nixos/modules/desktop.nix`, only after deciding GNOME fits your machine:

```nix
# Select GNOME and its display manager; hardware remains machine-specific.
{ ... }:
{
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;
}
```

Include, build, and activate separately from networking/account experiments. Desktop changes can download many packages and disrupt a graphical session; arrange a recovery console first. A headless system needs no desktop module.

**Expected outcome:** You can inspect a service independently and understand that optional desktops are integrated module choices, not just a package in a list.

### Practice: reason about SSH exposure

**Rationale:** An option name should not be overinterpreted as a complete security guarantee.

**Explanation:** Reachability depends on service binding, local firewall rules, upstream networking, and authentication policy.

**Example:** No command is needed. Does `services.openssh.openFirewall = false;` guarantee that no remote host can reach SSH?

**Expected outcome:** Success criterion: explain both what the option prevents and what it does not establish.

<details>
<summary>Worked solution</summary>

It prevents the SSH module from automatically opening the firewall. It does not close separately allowed rules or prove upstream isolation. Review existing firewall and network exposure, then verify authentication and access deliberately.

</details>

## 9. Update inputs, pin revisions, and plan release upgrades

### Refresh pins without confusing them with activation

**Rationale:** Input updates should be reviewable changes, not hidden side effects of a rebuild.

**Explanation:** Modern `nix flake update` takes **input names** as positional arguments. It operates in the current flake directory unless `--flake` selects another. It changes `flake.lock`, not the requested branch in `flake.nix`, and does not activate a system. With no input names it refreshes all inputs. `nix flake lock` instead fills missing or changed-request entries without intentionally refreshing every existing pin. See [update](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html) and [lock](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html).

Updating the root user’s Nix channel does not update a flake lock. Profile upgrades likewise do not update your OS flake’s lock. Keep these workflows distinct.

**Example:** **SOURCE EDIT plus input fetching**, from any directory, using authorized source write access; alternatives:

```bash
nix flake update nixpkgs --flake path:/etc/nixos
nix flake update --flake path:/etc/nixos
```

The first targets `nixpkgs`; the second refreshes all inputs, currently the same single input in the minimal spine. Do not write `nix flake update path:/etc/nixos`: that positional value would be treated as an input name.

**Expected outcome:** Only intended pins change. You review the old and new resolved revisions, then build before choosing any activation.

### Pin or restore deliberately

**Rationale:** A branch is convenient for maintenance, but an exact revision can be useful for diagnosis or a temporary hold.

**Explanation:** The lock already pins a resolved revision even when `flake.nix` names a branch. Preserve both files as a compatible pair when recording known-good source. To restore behavior, restore the relevant source edits **and** lock data from your own known-good backup/history; reverting only the lock does not undo a newly enabled service.

For an explicit long-lived source pin, replace the input URL with `github:NixOS/nixpkgs/COMMIT`, where `COMMIT` is a real full revision you obtained from your known-good lock or the upstream repository and verified. This is a replacement instruction, not a fabricated working hash. Resolve the changed input with `flake lock`, inspect, and build again. A pin can also withhold security fixes, so give it a review date/process. See [flake references and lock files](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).

**Example:** No command is needed for the decision. Compare two policies: “track `nixos-26.05` but accept new lock revisions only after review” versus “hold one known-good commit while investigating a regression.” Neither requires changing `system.stateVersion`.

After a deliberate source edit, **SOURCE EDIT plus fetching**, from any directory:

```bash
nix flake lock path:/etc/nixos
```

**Expected outcome:** You can identify exactly which dependency tree is intended, why it is pinned, and when the pin should be reconsidered.

### Release upgrades are a separate change

**Rationale:** Moving between release branches can change options, packages, and service data formats.

**Explanation:** Read the release notes for your actual current and target releases and relevant service upgrade instructions. Confirm backups, free space, a known-good boot generation, and recovery access. Then deliberately edit the `inputs.nixpkgs.url` branch, refresh the intended lock entry, inspect warnings, build, and schedule activation/reboot. Do not upgrade a remote-only machine without a way back.

**Keep `system.stateVersion` at its installed value** unless you separately plan a documented state migration. This protects compatibility defaults; it does not freeze package versions. A stable branch receives maintenance changes, while unstable may involve broader change; neither eliminates bugs. The [NixOS upgrade manual](https://nixos.org/manual/nixos/stable/#sec-upgrading) and [release notes](https://nixos.org/manual/nixos/stable/release-notes.html) are authoritative starting points.

**Example:** No command is needed. On a machine running another release, adapting this tutorial to its maintained branch is not the same decision as upgrading it to 26.05. First decide which result you actually want; only then edit the branch.

**Expected outcome:** You have an explicit release transition plan rather than an accidental upgrade hidden inside a tutorial copy-paste.

### Practice: identify the changed artifact

**Rationale:** File ownership is the easiest way to keep update operations understandable.

**Explanation:** The requested input source and its resolved pin live in different files.

**Example:** No command is needed. You run `nix flake update nixpkgs --flake path:/etc/nixos` while `flake.nix` still names the same branch. Which source file changes, and is the new OS running?

**Expected outcome:** Success criterion: name the lock and the missing build/activation steps.

<details>
<summary>Worked solution</summary>

The command updates the resolved input in `flake.lock`; it does not rewrite the branch in `flake.nix` or activate the OS. Review the pin change, build the system, then choose an activation mode when ready.

</details>

## 10. Recover safely and understand garbage collection

### Generations and the limits of rollback

**Rationale:** Rollback is valuable precisely when you know what it restores—and what it cannot.

**Explanation:** NixOS retains system generations, often selectable from the bootloader. A modern user profile retains its own versions separately. Retained store results allow returning to an earlier selected environment without rebuilding everything. This is not a snapshot of every disk or process.

OS rollback does **not** restore `configuration.nix`, `flake.lock`, documents, service databases, passwords, or arbitrary mutable state. A service migration may not support running the older service against the newer database. Keep independent data backups. Package environment pointer changes can be atomic, but system activation, service restarts, and data migrations are not one universal database transaction. The [profile explanation](https://nix.dev/manual/nix/stable/package-management/profiles.html) describes the narrower atomic-selection mechanism.

[Video insight, approximately 00:42:00–00:56:00](https://www.youtube.com/watch?v=zdZvKWpNzU8&t=2520s): the rollback and atomic-package discussion motivates this distinction; do not generalize it into an all-state recovery promise.

**Example:** **READ-ONLY**, from any directory on the documented NixOS interface:

```bash
nixos-rebuild list-generations
```

Record which retained generation was actually tested as known-good. Generation numbers are machine-specific; never copy a number from this tutorial.

**Expected outcome:** You know which system fallback exists and which separate backups would be needed for mutable state.

### Recover a running or unbootable system

**Rationale:** Recovery must work even when the new configuration cannot evaluate.

**Explanation:** If the system remains usable and the previous generation is appropriate, a rollback command can select it. If boot is broken, use the bootloader’s retained older generation. The menu and keys depend on the actual bootloader; no GRUB/systemd-boot assumption is made here. If no retained generation boots, use suitable recovery media and the official recovery/install documentation for your real storage layout—do not invent disk IDs or run generic formatting instructions.

After recovering runtime functionality, repair or restore the **source and lock** before the next ordinary rebuild; otherwise you can recreate the failure. Preserve useful errors and logs. If activation was partial, check services explicitly rather than assuming a failed command left everything unchanged. See [rebuild recovery guidance](https://wiki.nixos.org/wiki/Nixos-rebuild), with the primary [NixOS manual](https://nixos.org/manual/nixos/stable/) taking precedence over dated wiki examples.

**Example:** **SYSTEM CHANGE**, from any directory, only when the previous system generation is the intended recovery target:

```bash
sudo nixos-rebuild switch --rollback
```

For a user-profile mistake instead, inspect `nix profile history` and use `nix profile rollback` as your normal user. That will not recover OS boot, services, or networking.

**Expected outcome:** You have separate plans for usable-system rollback, boot-menu recovery, and source/data repair.

### Garbage collection trades history for space

**Rationale:** Store cleanup is not a routine prerequisite for every rebuild, and can remove the recovery targets you need.

**Explanation:** A **garbage-collection root** keeps a store object and its references reachable. Current and retained profile generations can be roots. Removing a package selection may leave the package retained by an older generation or another dependency. GC removes unreachable store paths. Deleting generations first can make more paths unreachable and eliminate rollback choices. `--no-link` builds avoid a local result link but may consequently lack a persistent root.

Inspect before cleanup, keep known-good recovery choices, and avoid aggressive automatic deletion while learning. `nix-collect-garbage -d` combines broad old-profile deletion with collection; it is **not** a harmless “clear download cache” command. We intentionally do not make it a practice step. See [GC concepts](https://nix.dev/manual/nix/stable/package-management/garbage-collection.html), [`nix store gc`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-store-gc.html), and [`nix-collect-garbage`](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage.html).

**Example:** **READ-ONLY inspection**, from any directory:

```bash
nix store gc --dry-run
```

Only after reviewing reachability, retained generations, and your recovery needs, optional **SYSTEM CHANGE: store deletion**:

```bash
nix store gc
```

Use the permissions permitted by your Nix installation; do not escalate merely to make a cleanup command succeed. This command collects unreachable paths; it does not itself request deletion of all retained old generations.

**Expected outcome:** You can predict why space may remain occupied and avoid sacrificing rollback history unintentionally.

### Practice: choose the right recovery asset

**Rationale:** Recovery confidence depends on having the correct kind of retained state.

**Explanation:** A lock file, bootable generation, and database backup serve different purposes.

**Example:** No command is needed. A service upgrade migrated its database and the old service cannot read it. Is booting an older NixOS generation sufficient evidence that the service’s data will recover?

**Expected outcome:** Success criterion: identify the missing recovery requirement.

<details>
<summary>Worked solution</summary>

No. The old generation restores selected software/configuration artifacts, not the database. You need the service’s documented migration/recovery procedure and a suitable data backup. Restore source/lock separately to prevent accidentally reapplying the upgrade.

</details>

## 11. Extend the same flake with development tools

### Add a development shell

**Rationale:** Project tools can be declared together without adding every tool to the whole OS.

**Explanation:** `pkgs.mkShell` describes a development environment; `packages` supplies executable tools. `nix develop` enters the selected shell environment. It is not a container, VM, or restricted execution environment. A `shellHook` runs shell code on entry and can write files or run arbitrary commands; the example deliberately needs no hook. Pinning tool inputs does not automatically pin a language package manager’s dependencies or your source checkout. See [the Nixpkgs manual’s `pkgs.mkShell` section](https://nixos.org/manual/nixpkgs/stable/) and [`nix develop`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-develop.html).

**Example:** **SOURCE EDIT**, extend `/etc/nixos/flake.nix` to this complete version. Preserve your verified `system` string, chosen branch/pin, and any optional module entries you intentionally added in stage 8; the list below shows the minimal required spine. This is the same system composition with additional outputs, not a new independent configuration:

```nix
# Share one pinned package set between the installed system and development tools.
{
    description = "Progressive NixOS configuration";
    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Expose system, package, and shell results from one selected platform.
    outputs = { self, nixpkgs, ... }:
        let
            system = "REPLACE_WITH_SYSTEM";
            pkgs = import nixpkgs { inherit system; };
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

`import nixpkgs { inherit system; }` evaluates the selected Nixpkgs package-set function for this platform. These shell packages are not automatically subject to future OS-only overlays; stage 12 discusses that boundary.

**Expected outcome:** The flake still wraps your installed machine and now also exposes an explicitly platform-specific package and shell.

### Use and leave the shell

**Rationale:** Temporary tool availability should have an understandable boundary.

**Explanation:** `nix develop` looks for `devShells.<system>.default` before falling back to a package’s build environment. Inside it, tools and build-related environment variables are available. Your current directory and ordinary file permissions still matter. `exit` returns to the outer shell; it does not undo files you created while inside. An environment is repeatable tool selection, not automatic cleanup of project state.

**Example:** **BUILD-ONLY plus interactive shell execution**, from any directory, after reviewing the flake and its hooks:

```bash
nix develop --no-update-lock-file path:/etc/nixos
```

Inside that shell, inspect trusted tools (**READ-ONLY program inspection**), then leave it:

```bash
hello --version
git --version
exit
```

For a real application project, keep its own flake and lock in that project rather than making `/etc/nixos` own all application dependencies. The system-source location here merely keeps the learning spine continuous.

**Expected outcome:** Tools are available inside the environment, no OS rebuild was needed, and leaving does not erase project work.

### Build, run, and check named outputs

**Rationale:** One flake can offer different result types; choose a command that matches the type.

**Explanation:** `nix build` realizes packages. `nix run` runs apps or suitable package executables, preferring an app when present. `nix develop` supplies a build/development environment. `nix flake check --no-build` checks output evaluation/schema but does not prove runtime correctness or execute every possible test. Without `--no-build`, checks outputs can be built; evaluation can still have fetching/cache or import-from-derivation effects even in no-build mode. See [run](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html) and [check](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html).

**Example:** From any directory, first **READ-ONLY with evaluation caveats**, then **BUILD-ONLY**, then **BUILD-ONLY plus application execution**:

```bash
nix flake check --no-build --no-update-lock-file path:/etc/nixos
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#default
nix run --no-update-lock-file path:/etc/nixos#default -- --greeting 'One flake, several outputs'
```

Here the package fallback runs Hello; it does not activate the NixOS configuration.

**Expected outcome:** You can select outputs by purpose without confusing package execution with system activation.

### Practice: choose a development interface

**Rationale:** Different commands solve different tool-use problems.

**Explanation:** A single executable is not the same as a shell with several coordinated tools.

**Example:** No command is needed. Choose a command for each: run Hello once; build its output without a result link; enter the declared tool environment.

**Expected outcome:** Success criterion: name the three commands and explain which one executes a shell.

<details>
<summary>Worked solution</summary>

Use `nix run path:/etc/nixos#default` for one execution; `nix build --no-link path:/etc/nixos#default` for artifact preparation; `nix develop path:/etc/nixos` for the declared shell. All can fetch/build; run and develop additionally execute code with your permissions.

</details>

## 12. Reuse modules, customize packages, and compose more machines

### Give a reusable module a small public option

**Rationale:** A small documented module interface lets machines share software policy without copying their hardware configuration.

**Explanation:** A reusable module can declare an option and conditionally supply definitions. `lib.mkEnableOption` creates a documented Boolean enable switch. `lib.mkIf` delays conditional definitions in the way the module system expects, avoiding common whole-configuration recursion mistakes. `config` is the merged configuration, not a file-local mutable object. See [writing modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

**Example:** **SOURCE EDIT**, create `/etc/nixos/modules/common-tools.nix`:

```nix
# Provide a reusable opt-in selection of command-line tools.
{ config, lib, pkgs, ... }:
{
    options.tutorial.commonTools.enable = lib.mkEnableOption "the shared tutorial tools";

    # Add tools only when this module's public option is enabled.
    config = lib.mkIf config.tutorial.commonTools.enable {
        environment.systemPackages = [ pkgs.hello pkgs.git ];
    };
}
```

In the existing flake’s output set, add `nixosModules.commonTools = import ./modules/common-tools.nix;`. In the `workstation` modules list, **replace** `./modules/cli-tools.nix` with `self.nixosModules.commonTools`, then add the inline module `{ tutorial.commonTools.enable = true; }` as another list item. Keep `./configuration.nix`, `./modules/nix-cli.nix`, and any chosen optional modules. This is a deliberate replacement of the same package responsibility; do not retain both copies. The old unreferenced file can remain harmlessly in source until you decide to remove it.

**Expected outcome:** A reusable module has a documented public switch, and the existing workstation consumes it without duplicating its tool definitions.

### Distinguish overrides from overlays

**Rationale:** Customizing one package and replacing that package throughout a package set have different reach.

**Explanation:** `package.override` changes arguments accepted by that package’s recipe function; inspect the recipe’s actual arguments first. There is no universal `enableFeature` argument. `package.overrideAttrs` changes attributes passed through the package’s derivation helper and returns a new derivation. An **overlay** is a function `final: prev: { ... }` extending a package set: `prev` is the prior set and `final` is the final composed set. Refer to the original package through `prev` to avoid recursively defining a package in terms of itself. Dependencies of a customized package usually come from `final`.

Overlays can cause downstream rebuilds and are ordered, unlike a simplistic “all module files override in order” story. See the official [overrides chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overrides.chapter.md) and [overlays chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overlays.chapter.md).

**Example:** Optional **SOURCE EDIT**, complete `/etc/nixos/modules/package-customization.nix`:

```nix
# Customize the NixOS package set while retaining the original package recipe.
{ ... }:
{
    nixpkgs.overlays = [
        # Derive a renamed Hello package while preserving its original recipe inputs.
        (final: prev: {
            hello = prev.hello.overrideAttrs (old: {
                pname = "${old.pname}-tutorial";
            });
        })
    ];
}
```

Include it in the existing workstation modules list only if you want this experiment. The executable remains `hello`; this example changes a derivation name, not its source version. A narrower one-use alternative is `pkgs.hello.overrideAttrs (old: { pname = "${old.pname}-tutorial"; })` directly where a package is selected. Neither expression should be confused with a NixOS option-priority override such as `mkForce`.

The OS module’s overlay affects its system package set, not automatically the separately imported `pkgs` used by the dev shell in stage 11. To share customization there, explicitly pass the same reviewed overlay to that import. Do not claim an overlay is global to every Nix command or profile.

**Expected outcome:** You can choose a local override when only one result needs customization and an overlay when a package-set-wide policy is actually intended.

### Compose fictional machines without copying their hardware

**Rationale:** Sharing software policy should not share disk identities or boot assumptions.

**Explanation:** `nixosModules.commonTools` exports a reusable building block; `nixosConfigurations.workstation` exports a complete system. A third-party module must be imported into a system composition before it has an effect. A third-party complete configuration is not automatically appropriate for your hardware. There is no universal command that safely “applies any flake.” Native references can build, run, or add a package directly, but a reusable OS module still needs deliberate composition.

For an additional flake input already declared with the illustrative name `desktop`, `inputs.desktop.inputs.nixpkgs.follows = "nixpkgs";` can make that input reuse your Nixpkgs input. Substitute your actual input name for `desktop`. It is optional dependency alignment, not required flake boilerplate; verify compatibility before imposing it. See [flake concepts](https://nix.dev/concepts/flakes.html) and the [flake output/reference contract](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).

**Example:** No shell command is needed. For a future second fictional machine, `travel`, retain `workstation` unchanged and add `nixosConfigurations.travel` using `nixpkgs.lib.nixosSystem` with **that machine’s verified platform**. Its modules should include its own complete configuration, for example `./hosts/travel/configuration.nix`, the shared `nix-cli.nix`, `self.nixosModules.commonTools`, and `{ tutorial.commonTools.enable = true; }`. First obtain the actual machine-specific configuration and keep its hardware imports inside the flake tree. Do not point the second system at the workstation’s root `configuration.nix` merely to make evaluation succeed.

This is a composition plan, not a ready-to-build second host: no second machine’s hardware/platform has been supplied. Keep the working one-machine spine until that input exists. Defer remote deployment, cross-compilation, package-language build helpers, custom kernels, image generation, secret-management integrations, and Home Manager until their prerequisites solve a real need. Home Manager is a separate project, not a built-in prerequisite for user profiles or NixOS.

**Expected outcome:** You can design shared policy and separate machine identity without pretending that a copied configuration makes arbitrary hardware bootable.

### Practice: choose the abstraction

**Rationale:** Advanced features should reduce a demonstrated problem, not introduce speculative structure.

**Explanation:** A module changes system options; an override changes one package result; an overlay changes a package set.

**Example:** No command is needed. Which mechanism fits each goal: share an SSH policy between machines; rename one Hello derivation for an experiment; replace a library consistently across a package set?

**Expected outcome:** Success criterion: choose a module, local override, and overlay respectively, with awareness of rebuild reach.

<details>
<summary>Worked solution</summary>

Use a reusable NixOS module for system service policy, `overrideAttrs` for one package result, and a deliberately scoped overlay for a package-set-wide replacement. Inspect real recipe arguments before using `override`; never invent a package argument to match an imagined feature.

</details>

## 13. Troubleshoot systematically and choose the next step

### Read the error from the relevant layer

**Rationale:** Repeatedly rebuilding without understanding the failure can obscure the first useful evidence.

**Explanation:** Start with the final meaningful error and its file/line, then use the context above it. Evaluation errors include syntax mistakes, missing attributes, unknown options, type mismatches, conflicts, and recursion. Build failures occur after recipes exist: source fetches, compilation, checks, or resource limits may fail. Activation/runtime failures require service logs, access checks, and possibly recovery—not another random input update.

An error trace can mention Nixpkgs internals because that is where your value was consumed; the actionable mistake may still be your module. `--show-trace` expands evaluation context but is not an automatic diagnosis. See [`nix eval`](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html) and [module semantics](https://nixos.org/manual/nixos/stable/#sec-writing-modules).

**Example:** **READ-ONLY with evaluation/cache caveats**, from any directory:

```bash
nix eval --show-trace --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
```

For a type error, compare `enable = "true";` with the required Boolean `enable = true;`. For “option does not exist,” check the selected release’s option name, whether the declaring module was imported, and spelling. Do not “fix” it by assigning an unrelated attribute elsewhere.

**Expected outcome:** You can classify the error and make one evidence-based correction at the correct layer.

### Narrow the change and bisect when needed

**Rationale:** A small known difference is easier to explain than an entire new personal configuration.

**Explanation:** Keep a known-good source/lock pair and record what failed. First separate source changes from input changes: did it fail with new source and old pins, or unchanged source and new pins? Restore a coherent test state using your existing backup/history workflow. Avoid changing packages, services, networking, and release branch at the same time.

For many candidate edits, **bisection** means testing roughly half the changes, then narrowing to the half associated with failure, while keeping the required hardware/base configuration intact. Start with evaluation or build checks; do not repeatedly activate arbitrary halves on an important machine. Runtime-only failures need a controlled test/recovery environment and state-aware testing. A “bad” result can come from an incompatible combination rather than one defective line.

**Example:** No command is needed. A system builds before adding three optional modules, then fails evaluation. Keep the installed configuration and core modules. Temporarily omit only the new optional imports in source, re-add them incrementally, and inspect the earliest failure. If the symptom is a failed service, collect its logs instead of assuming package compilation was the cause.

**Expected outcome:** You can produce a minimal reproducible source/input difference and state exactly which check distinguishes good from bad.

### Use a symptom checklist

**Rationale:** A concise checklist catches common boundary mistakes without hiding how the system works.

**Explanation:** Use this table after understanding the earlier stages:

| Symptom | First bounded check |
| --- | --- |
| Missing file inside a store source snapshot | Check import path and source-root boundaries; for Git-backed refs, check whether the new file is tracked. |
| Dirty source warning | Inspect intended edits; tracked dirty changes are normally included, not automatically ignored. |
| Unexpected package version | Check the selected flake/pin and which profile or shell owns the executable. |
| Updating a channel changed nothing | Verify that this system is actually built from the flake lock, not that channel. |
| Conflicting definitions | Read both definitions and option type/priority; do not immediately add `mkForce`. |
| Infinite recursion | Look for a value depending on itself, or a whole-module conditional on the configuration it constructs; consider the documented `mkIf` pattern. |
| Fetch/build takes a long time | Check cache/network availability, actual build logs, architecture, resources, and foundational overrides. |
| Build succeeded but service failed | Inspect activation output, `systemctl status`, and service journal. |
| Permission denied writing source | Use authorized source-edit access; do not change ownership/modes just to silence it. |
| Disk remains full after package removal | Check retained generations and reachability before any deletion. |

For a learning sequence after diagnosis, follow [the next-step plan](#appendix-c-next-step-plan).

[Video insight, approximately 01:07:00–01:19:00](https://www.youtube.com/watch?v=zdZvKWpNzU8&t=4020s): the stories about needing a working network support the practical recommendation to learn before depending on an unfamiliar setup. They are anecdotes, not evidence that a particular distribution always fails or succeeds.

**Example:** No command is needed. Write a short change record: intended result, source files changed, input revision, evaluation/build result, activation mode, runtime check, and recovery target. Redact private details before sharing it.

**Expected outcome:** You have a manageable next-step plan and can ask for help with versions, relevant configuration, exact error, and what already worked—without publishing secrets or an entire private machine tree.

### Practice: diagnose before changing more

**Rationale:** A successful diagnosis often consists of choosing the next observation, not immediately editing another option.

**Explanation:** Build success and runtime success have different evidence.

**Example:** No command is needed. After changing SSH configuration, the system builds but remote login fails. Should your next action be “update all flake inputs,” or should you inspect a narrower boundary? Name three useful observations and one safety condition.

**Expected outcome:** Success criterion: choose runtime/service/network evidence and keep an existing recovery path.

<details>
<summary>Worked solution</summary>

Keep the current working console or alternate login. Inspect activation output, `systemctl status sshd`, and its journal; then review binding/firewall/authentication and network reachability as relevant. Updating unrelated dependencies adds uncertainty rather than establishing the cause.

</details>

## Appendix A. Command reference by task

### Select the task before the command

**Rationale:** Commands are easier to remember when organized around intent and effect.

**Explanation:** This reference assumes the feature module is active, placeholders were replaced, the source tree was reviewed for secrets, pins exist, and the source remains `/etc/nixos`. Otherwise use stage 6/7’s temporary feature flags. All commands below work from any directory because references are explicit. Read the owning stage before using a command; this is not a script to run top-to-bottom.

**Example:** The table is a compact command reference; only run the task you intend. Commands are also shown in Bash fences below to keep their shell syntax unambiguous.

| Task | Effect | Relevant stage |
| --- | --- | --- |
| Record installed versions | READ-ONLY | 1 |
| Inspect selected hostname | READ-ONLY with evaluation/fetch/cache caveats | 6, 13 |
| Build system without a local link | BUILD-ONLY | 7 |
| Activate candidate, retain prior boot default | SYSTEM CHANGE | 7 |
| Select candidate for next boot only | SYSTEM CHANGE | 7 |
| Activate and select boot default | SYSTEM CHANGE | 7 |
| Resolve missing pins | SOURCE EDIT plus fetching | 6 |
| Refresh one input | SOURCE EDIT plus fetching | 9 |
| Inspect/profile add/remove/upgrade | READ-ONLY or USER-PROFILE CHANGE | 5 |
| Recover previous OS generation | SYSTEM CHANGE | 10 |
| Develop or run | BUILD-ONLY plus shell/application execution | 11 |
| Preview GC / collect unreachable paths | READ-ONLY preview / SYSTEM CHANGE store deletion | 10 |

**Inspect** (**READ-ONLY**, Nix evaluation caveats apply):

```bash
nix --version
nixos-version
nix eval --no-update-lock-file --raw path:/etc/nixos#nixosConfigurations.workstation.config.networking.hostName
nix profile list
nix profile history
nixos-rebuild list-generations
systemctl --failed
```

**Prepare** (**BUILD-ONLY**, no activation):

```bash
nix build --no-link --print-out-paths --no-update-lock-file path:/etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel
```

**Activate** (**SYSTEM CHANGE**, choose one mode, authorized administration only):

```bash
sudo nixos-rebuild test --flake path:/etc/nixos#workstation
sudo nixos-rebuild boot --flake path:/etc/nixos#workstation
sudo nixos-rebuild switch --flake path:/etc/nixos#workstation
```

**Maintain pins** (**SOURCE EDIT plus fetching**, authorized write access required):

```bash
nix flake lock path:/etc/nixos
nix flake update nixpkgs --flake path:/etc/nixos
```

**Select user packages** (**USER-PROFILE CHANGE**, as your ordinary user; replace `PROFILE_NAME`):

```bash
nix profile add github:NixOS/nixpkgs/nixos-26.05#hello
nix profile remove PROFILE_NAME
nix profile upgrade PROFILE_NAME
nix profile rollback
```

**Recover the previous OS selection** (**SYSTEM CHANGE**, source/data restoration remains separate):

```bash
sudo nixos-rebuild switch --rollback
```

**Use trusted development outputs** (**BUILD-ONLY plus execution**, not sandboxed):

```bash
nix develop --no-update-lock-file path:/etc/nixos
nix run --no-update-lock-file path:/etc/nixos#default
```

**Inspect then optionally collect** (**READ-ONLY** first; second is **SYSTEM CHANGE: store deletion**):

```bash
nix store gc --dry-run
nix store gc
```

**Expected outcome:** You can retrieve an operation by purpose while preserving the safety distinctions, run location, and prerequisites from the tutorial.

## Appendix B. Glossary

### Connect words to the mental model

**Rationale:** Terminology is useful when it names a distinction rather than replacing an explanation.

**Explanation:** These definitions summarize the earlier stages rather than adding another framework.

| Term | Plain-language meaning |
| --- | --- |
| Activation | Applying a built system to running OS state; can affect services and mutable data. |
| Attribute | A named field in a set, such as `name` in `{ name = "Learner"; }`. |
| Attribute set | A collection of named values. |
| Closure | A store object together with the store objects it references transitively. |
| Declarative | Describing the desired result in source rather than only issuing incremental change commands. |
| Derivation | A structured build recipe; also used informally for its Nix-language representation. |
| Evaluation | Computing values from Nix expressions; not the same as ordinary package building or activation. |
| Flake | A source tree with a standardized inputs/outputs entrypoint. |
| Generation | A retained selection/version in a profile’s history; an OS generation is not a data snapshot. |
| GC root | A reference keeping store objects reachable and protected from collection. |
| Imperative | Requesting an immediate incremental change, such as adding a profile package. |
| Input | A dependency supplied to a flake or build; meaning depends on context. |
| Lazy | Computing values when needed, which can delay both work and errors. |
| Lock file | Recorded resolved flake input choices, not a backup of all machine state. |
| Module | A composable declaration/definition unit evaluated by the NixOS module system. |
| Nixpkgs | Package definitions and libraries from a selected Nixpkgs source tree. |
| Option | A typed declared configuration interface; definitions supply its values. |
| Output | A result of a derivation or a named flake result; these are related but distinct uses. |
| Overlay | A function extending/replacing entries in a package set. |
| `pkgs` | A conventional name for the selected package set. |
| Profile | A selected package environment with history, distinct from your configuration source. |
| Pure flake evaluation | Evaluation constrained to declared/captured inputs rather than arbitrary host context. |
| Realization | Obtaining required store outputs through fetching or building. |
| Store | Nix-managed artifact storage, normally `/nix/store`; not a secret vault. |
| Substitute | A prebuilt store result obtained from a configured cache. |
| `system` | Often a platform pair such as `aarch64-linux`; not the same as `system.stateVersion`. |

**Example:** No command is needed. In “evaluate the flake, realize the system output, then activate,” the first step computes a description, the second obtains artifacts, and the third affects running OS state.

**Expected outcome:** You can translate the vocabulary back into source, store, selection, and runtime responsibilities.

## Appendix C. Next-step plan

### Progress through one responsibility at a time

**Rationale:** Repeated small, understood changes build more useful confidence than adopting a large configuration you cannot explain.

**Explanation:** **Recommendation/convention:** Maintain one machine and one purpose per change for the next few sessions:

1. Change a small package selection, inspect the source, and build before choosing activation.
2. Make a small service change with recovery access available, then verify its actual behavior.
3. Review an input update as a source/lock change, build it, and schedule activation separately.
4. Rehearse recovery on a noncritical system, including the distinction between software rollback and restoring data.
5. Introduce a reusable module only when another current consumer needs the same policy. Read a package recipe before customizing it, and defer additional tools until you can explain what they own.

**Example:** No command is needed. Pick one session above and write its intended result, files and pins, check, activation decision, and recovery target before starting. Use the owning stage’s commands rather than improvising a new workflow.

**Expected outcome:** You have an incremental maintenance plan with an observable success check and a recovery boundary for each change.

## Appendix D. Sources and evidence limits

### How to read the source classifications

**Rationale:** A reference manual, a conversational analogy, and an author’s workflow preference should not carry the same evidential weight.

**Explanation:** **Official** means retrieved project-maintained manuals or official source-tree documentation. These govern the technical contracts used here. **Official community wiki** means project-hosted community guidance; it can contain dated examples and is secondary to the primary manuals. **Video insight/example** means a paraphrased idea or anecdote from the supplied transcript, not independent verification of current behavior. **Recommendation/convention** means this tutorial’s chosen workflow, such as `modules/`, explicit `path:` references, and one change at a time; those are not mandatory NixOS laws.

Sources were retrieved on **2026-11-14 UTC**. Stable documentation URLs can move to newer versions later; compare your installed version with the relevant manual. Near-claim links identify the source supporting that claim. No claim is made that these examples were executed on your hardware or that a Markdown/static review proves their runtime success.

**Example:** No command is needed. “`test` activates without choosing the boot default” is an official command behavior. “Build before activating” is a safety recommendation. “The terminology initially felt difficult” is a conversational experience, not a measured learning-time requirement.

**Expected outcome:** You can distinguish a supported interface contract from an analogy, anecdote, or suggested convention.

### Official documentation used

**Rationale:** The original sources provide deeper contracts and version-specific details when examples stop being sufficient.

**Explanation:** The following retrieved URLs support this tutorial. They are grouped by subject rather than presented as evidence that every possible configuration has been verified.

**Example:** No command is needed; choose the source matching the question:

- Language: [nix.dev language basics](https://nix.dev/tutorials/nix-language.html).
- Flakes: [concepts, tradeoffs, and alternatives](https://nix.dev/concepts/flakes.html); [Nix flake reference](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake.html).
- Store recipes and selection: [derivations](https://nix.dev/manual/nix/stable/language/derivations.html); [profiles](https://nix.dev/manual/nix/stable/package-management/profiles.html).
- NixOS: [stable manual](https://nixos.org/manual/nixos/stable/); [release notes](https://nixos.org/manual/nixos/stable/release-notes.html). Consult the actual release section; old snippets are not an upgrade plan.
- Nixpkgs: [stable manual, including `mkShell`](https://nixos.org/manual/nixpkgs/stable/); [26.05 overlays chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overlays.chapter.md); [26.05 overrides chapter](https://raw.githubusercontent.com/NixOS/nixpkgs/nixos-26.05/doc/using/overrides.chapter.md).
- Profile CLI: [add](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-add.html), [list](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-list.html), [remove](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html), [upgrade](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-upgrade.html), [history](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-history.html), [rollback](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-rollback.html).
- Tool/build CLI: [shell page (`nix env shell`, with `nix shell` examples)](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-env-shell.html), [build](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-build.html), [develop](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-develop.html), [run](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-run.html), [eval](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-eval.html).
- Lock/check CLI: [update](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-update.html), [lock](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-lock.html), [check](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-flake-check.html).
- Cleanup: [GC explanation](https://nix.dev/manual/nix/stable/package-management/garbage-collection.html), [store GC](https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-store-gc.html), [collect-garbage](https://nix.dev/manual/nix/stable/command-ref/nix-collect-garbage.html).
- Secondary official community wiki: [Nixos-rebuild](https://wiki.nixos.org/wiki/Nixos-rebuild), [Flakes](https://wiki.nixos.org/wiki/Flakes). Dated wiki implementation notes are not used to override current manual behavior.

**Expected outcome:** You have a bounded source list for checking syntax, effects, and release-specific behavior without treating random configuration repositories as universal templates.

### Video and transcript provenance

**Rationale:** A conversational source can improve explanations without becoming the authority for current commands.

**Explanation:** The video is [#268 Long Awaited NixOS Episode | Tristan Ross](https://www.youtube.com/watch?v=zdZvKWpNzU8). This tutorial used the **user-provided English ASR transcript**, read in full through a normalization that removes tags and immediately overlapping rolling captions. It is not a verbatim transcript; technical terms and names may be misrecognized. The supplied coverage is approximately **00:00:01–01:52:57.5**. The transcript was accessed as task material; no audio/video watching is claimed.

Only a few timestamped conceptual insights are cited in the body. Claims about current interfaces were cross-checked against official documentation. Historical package counts, predictions, distribution comparisons, Git-performance claims, and personal hardware anecdotes were not promoted into current technical facts.

**Example:** No command is needed. Use the recipe analogy to understand the distinction between a description and a result, then use the official derivation and command references to decide what a real operation does.

**Expected outcome:** You know what the video contributed, what it did not verify, and where the tutorial’s factual and runtime limits remain.
