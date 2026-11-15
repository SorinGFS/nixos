# Nix identities, dependencies, and project boundaries

Nix gives each prepared package variant a distinct place in the store. That location connects a build description to particular dependencies and lets old and new variants coexist. Files and modules organize the description; store identities organize the results. Those are different kinds of boundary.

This chapter explains that relationship from source text to running processes, then applies it to this project's desktop and Firefox composition. A package is prepared software; a dependency is something needed to prepare or run it. The remaining terms are introduced as they become useful. The optional progressive tutorial supplies [language foundations](readme.md#3-reading-the-nix-language), [module composition](readme.md#4-inspecting-installed-configuration-and-modules), and the [operational build and activation sequence](readme.md#7-building-testing-and-activating-the-system).

All examples below are explanatory and unexecuted. Diagrams use fictional labels such as `APP_A` and `LIB_B`; these labels are not valid store digests or executable paths. Nix fragments illustrate an expression in an existing context rather than complete runnable configurations. Standard store paths describe Nix's mechanisms, not files to edit.

## Reading map

- [The overall journey](#1-the-journey-from-description-to-execution): source, recipes, stored results, and execution.
- [Build identities](#2-the-recipe-and-its-result-have-different-identities) and [the different hashes](#3-several-hashes-with-different-jobs): what the fingerprints describe.
- [Build dependencies](#4-dependency-edges-during-evaluation-and-building) and [runtime closures](#5-runtime-references-and-closures): what gets built, shared, and retained.
- [The four meanings of linking](#6-four-different-meanings-of-linking): source imports, executable linking, launcher environments, and filesystem links.
- [Caches and reproducibility](#7-substitution-reproducibility-and-trust) and [running state](#8-coexistence-running-state-and-retention): what reuse and rollback actually guarantee.
- [The current project](#9-the-current-projects-composition), [architecture choices](#10-architecture-choices-implied-by-the-mechanics), [manual updates](#11-manual-updates-across-four-kinds-of-state), and [a worked recap](#12-a-compact-worked-interpretation).

## 1. The journey from description to execution

A **package recipe** describes how to prepare software. A **derivation** is the lower-level build specification produced from that description. A **store object** is a registered object at a store path: it can contain source, a derivation, an executable package, or generated configuration.[11] **Realization** means obtaining the requested store objects, by building or by copying already-built results.[1]

```text
Source files + selected external sources + configuration values
                            |
                            | evaluation: compute requested values
                            v
                  Derivation graph (.drv recipes)
                            |
                            | realization
                  +---------+----------+
                  |                    |
             local/remote         trusted binary
                builds             substitutes
                  |                    |
                  +---------+----------+
                            v
                     Store objects
                            |
                            | profile selection / NixOS activation
                            v
              Available commands and system configuration
                            |
                            | process start, restart, or reboot
                            v
                      Running software
```

A **graph** is a collection of nodes connected by edges. Here a node represents a recipe or store object; an edge records a dependency or reference. A build needs its prerequisite results before the dependent step can run. Obtaining one result does not imply rebuilding every prerequisite: a suitable result may already exist locally or be available from a cache.[1], [6]

Evaluation, realization, selection, and execution have separate effects. Editing a module changes source. Updating a lock changes selected external inputs. Building obtains artifacts. Activation applies system configuration. A process can continue using an earlier executable after the selected profile changes.

The diagram is a conceptual separation, not a guarantee that evaluation has no effects. Source fetching and import-from-derivation can perform work during evaluation. Nix's lazy evaluation computes values as demanded rather than evaluating every expression immediately. An unused value can remain unevaluated.[12]

### Source changes and result changes

A comment edit ordinarily changes no package recipe. Moving an equivalent expression between files can preserve its result. Editing an unused package definition need not affect the requested output. Conversely, a small change to an input used throughout a package set can alter a large build graph.

Source filtering matters too. If a recipe receives an entire source snapshot, even a seemingly unrelated included file can change that source input's identity. Laziness does not make included source bytes invisible to a builder. The relevant question is which values and source objects reach the requested derivations, rather than how many lines changed.

```text
Source edit
    |
    +-- changes no demanded value or included source object --> reuse possible
    |
    +-- changes a demanded recipe/input ---------------------> new identity likely
```

This distinction explains why file boundaries are useful for readability without acting as package isolation boundaries.

## 2. The recipe and its result have different identities

A **hash** is a fixed-length fingerprint calculated from specified data. The calculation is deterministic: the same bytes passed through the same algorithm produce the same digest. A small input change usually produces a very different digest. The digest summarizes its input rather than storing a reversible copy of it.

```text
Schematic fingerprints, not actual SHA values

specified bytes A --> hash algorithm --> fixed-length fingerprint A
specified bytes A --> hash algorithm --> fixed-length fingerprint A
specified bytes B --> hash algorithm --> usually a different fingerprint
```

A hash is not a randomly assigned UUID, an encrypted package name, or a value from which the original package can be recovered. Different inputs can theoretically collide because the output has finite length; cryptographic algorithms make such collisions exceptionally unlikely in ordinary use. The choice of exactly which data to hash is therefore as important as the algorithm itself. Nix uses different specified inputs for different kinds of identity.[2]

A Nix attribute set is a collection of named values. Package helpers accept attribute sets and produce derivations. The resulting store-level derivation records the process to run, rather than preserving every high-level Nix expression exactly as written.[1]

Its relevant parts include:

- A name and output specifications.
- A `system`, describing the platform on which the builder runs.
- A `builder`, the executable that performs the step.
- Arguments and environment variables for that executable.
- Explicit inputs, including source store objects and outputs of other derivations.

For cross-compilation, the builder's platform and the platform of the produced executable can differ. The `system` field alone is not a complete description of that distinction.

```text
Illustrative recipe inventory

name:        image-viewer-1.0
system:      x86_64-linux
builder:     selected shell/build tool
arguments:   selected build script
environment: source path, compiler flags, output locations, ...
inputs:      source snapshot, compiler output, image-library output, ...
outputs:     out, possibly dev/debug/other outputs
```

Nix serializes a derivation into a store object normally named with a `.drv` suffix. **Serialization** means converting structured data into a defined byte representation. The derivation object is content-addressed from that representation. Its output objects have their own identities and addressing rules.[1], [3]

```text
/nix/store/RECIPE_A-image-viewer-1.0.drv  : build description
/nix/store/APP_A-image-viewer-1.0         : prepared package output
```

`RECIPE_A` and `APP_A` are illustrative labels, not interchangeable digests. The first object describes a process; the second holds the process's result. A derivation's hash is not a checksum of its future executable bytes.

### Input-addressed outputs

The normal model for compiled Nixpkgs packages is **input addressing**: an output's identity is derived from the build specification and its inputs. Its output path can be determined before the build runs. That permits a downstream recipe to refer to an upstream result before either result exists.[2], [3]

A useful conceptual formula is:

```text
output identity ~= identity of (
    normalized build specification,
    dependency identities,
    output name
)
```

The `~=` symbol means “conceptually represented by,” not an exact implementation algorithm. This is not a hash of every Nix attribute or every source file in a repository. The exact store-path construction has additional encoding and addressing rules.

For ordinary input-addressed outputs, changes to the compiler, selected dependency output, build flags, enabled feature, patch, or builder environment can change the recipe and therefore the output identity. The visible application version can remain `1.0` throughout.

```text
image-viewer 1.0 + compiler A + JPEG support --> APP_A
image-viewer 1.0 + compiler A + no JPEG      --> APP_B
image-viewer 1.0 + compiler B + JPEG support --> APP_C
```

There is no contradiction in three variants of the same upstream version existing together. A version label summarizes upstream history; a Nix identity describes a more specific build choice. The hash does not decide which version is newest or which library is compatible: the evaluated package recipes select the dependencies first. Cryptographic digests make accidental collisions exceptionally unlikely, not mathematically impossible.

### The actual outer store-path formula

A usual store path has this shape:[2]

```text
/nix/store/<32-character Nix32 digest>-<name>
```

**SHA-256** is a cryptographic hash algorithm producing 256 bits. **Nix32** is Nix's particular base-32 text encoding. A normal store-path digest encodes 160 bits, or 20 bytes, as 32 characters. It is not the usual full SHA-256 text printed by a generic checksum utility.

The official outer construction can be written as follows. Quoted punctuation is literal; `+` means string concatenation.[2]

```text
storePath   = storeDir + "/" + digest + "-" + name
fingerprint = type + ":sha256:" + innerDigest + ":" + storeDir + ":" + name
digest      = Nix32(compress160(SHA256(fingerprint)))
```

`compress160` is Nix's specified compression of the hash to 160 bits, not simply taking the first 160 bits. `innerDigest` is lower-case hexadecimal text from the inner calculation. The name and store directory participate in the outer fingerprint, so the suffix is not merely decoration outside the calculation.

The inner calculation depends on the kind of object. For ordinary input-addressed outputs it uses the derivation's specified ATerm representation with special treatment of fixed-output derivations. ATerm is a structured serialization format. For other addressing methods, content serialization and declared content hashes enter differently. The complete specification owns those details; the outer formula alone cannot calculate every path.[2]

Thus “Nix hashes the inputs” is a useful first approximation, while “the directory name is the SHA-256 checksum of the installed directory” is generally incorrect.

## 3. Several hashes with different jobs

A **content hash** identifies bytes under a specified representation. A **content-addressed** output uses its content in determining its identity. This differs from naming a normal output from the inputs intended to produce it.[3]

| Value | What it identifies or checks | Important distinction |
| --- | --- | --- |
| Ordinary input-addressed output digest | A result identified through its build specification | Does not assert that two executions produced identical bytes |
| `.drv` store identity | Serialized derivation object | Describes the recipe, not its output's bytes |
| Fixed-output fetcher hash | Expected fetched content under the fetcher's hash mode | Raw download bytes and unpacked source trees can require different hashes |
| `narHash` | Content serialized as a Nix Archive | Covers a filesystem object representation, not a Git revision identifier |
| Lock-file `rev` | A revision identifier for a source system such as Git | Selects history; it is not a package output digest |
| Cache archive/content hashes | Integrity of transferred and restored content | Integrity checking is distinct from trusting the producer |

A **Nix Archive**, or **NAR**, serializes a filesystem object such as a directory tree in a defined format. That representation includes file contents and structural information, including symbolic links. A **symbolic link**, or **symlink**, is a filesystem entry containing a target path: following the link reaches that target rather than an independently copied file. A NAR records the link's target text, rather than copying the target's entire contents into the archive. A NAR hash therefore has a different input from a hash of a compressed download file.[2], [4]

### Fixed-output fetching

A **fixed-output derivation** declares its expected output content hash in advance. Fetching a source archive is a common use. Nix checks the produced content against that expectation. Changing a mirror URL while retaining the expected content and other identity-relevant properties need not change the fetched object's output identity.[2], [3]

```text
mirror A ----+
             +--> expected source content --> one source object
mirror B ----+
```

This exception prevents a mere retrieval-method change from necessarily cascading through every dependent package. It also explains why the conceptual input-addressing formula is not universal.

The expected hash must match the fetcher's representation. A raw-file fetch hashes the file; an unpacking fetcher can hash the resulting tree. A `sha256-...` string does not by itself state whether the input was a tarball, its unpacked directory, or another serialization. Fetcher semantics supply that meaning.[2], [5]

### Floating content-addressed builds

A **floating content-addressed** output obtains its content identity after building rather than receiving an expected content hash beforehand. Recipes can refer to such future outputs through derivation/output references and placeholders instead of an already-known final store path. Nix 2.34 documents content-addressed derivation facilities with experimental qualifications; this is not the default model to assume for ordinary Nixpkgs packages.[1], [3]

Content addressing strengthens the connection between identity and bytes. It does not establish that the bytes are safe, compatible, or produced from the intended source. Input addressing, content addressing, and producer trust solve related but different problems.

## 4. Dependency edges during evaluation and building

A build dependency is a store object required to carry out a build step. A compiler can be a build dependency even when the completed program never runs the compiler.[1]

Nix expressions commonly establish these relationships by referring to package values. Interpolation such as `${pkgs.someLibrary}` produces text containing a store path and carries dependency information along with that text. This attached information is called **string context**.[7]

The following is an illustrative expression fragment with `pkgs` supplied by the surrounding configuration:

```nix
# Describe a library location while retaining its dependency context.
{
    libraryDirectory = "${pkgs.zlib}/lib";
}
```

The fragment alone does not create a derivation. When such a context-bearing value reaches derivation construction, the evaluator can collect the relevant input relationship. Arbitrarily typing an apparent store path as plain text is not equivalent to referring to a package value with its context.[1], [7]

```text
viewer recipe --needs to build--> compiler output
viewer recipe --needs to build--> source object
viewer recipe --needs to build--> image-library output
```

The arrows here mean **requires during building**. The compiler and image library themselves have prerequisites, giving a graph rather than a flat list. Nix realizes the necessary inputs before running the dependent builder.[6]

### Shared nodes and changed nodes

Identical store identities permit sharing. Two applications using the same library output do not require two independently installed copies of that output merely because their recipes appear in different files.

```text
Before customization

viewer-A recipe ---+
                   +--> library-L recipe --> compiler/toolchain inputs
editor-A recipe ---+
```

A change can introduce new nodes without overwriting the existing nodes:

```text
After a viewer-local library customization

viewer-B recipe ------> library-M recipe --> selected toolchain inputs
editor-A recipe ------> library-L recipe --> selected toolchain inputs
```

`library-L` and `library-M` can have the same upstream version while differing in a feature flag or patch. The viewer's recipe now names the customized library identity. The editor continues to name the original one.

If the customized library instead replaces the shared library throughout the relevant package set, both application recipes can change:

```text
After a shared package-set replacement

viewer-B recipe ---+
                   +--> library-M recipe
editor-B recipe ---+
```

These are dependency illustrations, not promises about a particular package's override interface. A recipe must actually use the replaced attribute for the change to propagate. Already-created values or independently imported package sets need not follow that replacement.

An altered foundational compiler or library can affect many downstream identities, even if some resulting bytes would be unchanged. Conversely, an unchanged node can be reused. The rebuild boundary follows the derivation graph, not the folder containing the edit.

## 5. Runtime references and closures

A runtime dependency is needed by the completed software when it runs. Nix records output **references** by scanning the resulting objects for relevant store-path hash parts. This is a byte-level mechanism, not an attempt to understand the application's source language or prove every possible execution path.[6]

```text
Build-time picture                         Resulting runtime picture

viewer recipe --> compiler                 viewer output --> image library
              --> source                                 --> C library
              --> image library
```

The compiler can disappear from the runtime picture when no reference to its output survives. Parts of a compiler toolchain, such as runtime support libraries, can legitimately remain necessary. An accidental compiler path in debugging information or a search path can also retain an otherwise unnecessary dependency.[4]

### Reference scanning and its limits

References can survive in executable bytes, generated configuration, scripts, wrappers, or symbolic-link targets. The NAR explanation makes clear why the mechanism is not limited to visible text files. A symlink to another store object creates a meaningful reference even though it contains no copied library bytes.[4], [6]

Two consequences follow:

- An unused-looking string can keep a dependency reachable. Stored reference does not prove that a process will use it.
- A program can need something that static scanning cannot infer. A plugin name obtained from user configuration, a dynamically constructed path, or a host service connection may require explicit packaging or runtime setup.

A recorded reference graph is therefore a practical retention and deployment model, not a semantic completeness proof. Packaging hooks, runtime dependencies, wrapper environment variables, and integration tests address requirements that bytes alone do not explain.[5]

### The transitive set

A **closure** contains an object and everything reachable by following its references repeatedly. **Transitive** means continuing through dependencies of dependencies, rather than stopping at the first edge.

For a runtime object `A`, the idea is:

```text
closure(A) = {A} union closure(R1) union closure(R2) union ...
```

`R1`, `R2`, and the remaining `R` values are direct references of `A`; `union` combines sets without counting the same object twice. This formula describes the reachable set, not an instruction to recursively revisit a self-reference forever.

```text
viewer --> image library --> C library
       --> C library

closure(viewer) = { viewer, image library, C library }
```

The C library appears once in the set despite two routes reaching it. A build closure and a runtime closure answer different questions: preparing a result can need many more tools and sources than using it.[4]

### Multiple outputs

One derivation can produce several outputs, such as `out`, `lib`, `dev`, and `debug`. The exact split is package-specific. Development headers or debugging symbols can be separated from the output needed for ordinary execution.[3], [5]

```text
library recipe
    |
    +--> lib output:   shared libraries
    +--> dev output:   headers and development metadata
    +--> debug output: separate debugging information
```

Outputs have individual store identities and reference relationships. Selecting an application need not retain every output of every build input. A retained output can still refer to another output, bringing that output into its closure. Splitting outputs is useful only when the resulting references preserve the intended separation.

## 6. Four different meanings of linking

“Linking” can refer to source composition, executable construction, runtime lookup, or filesystem selection. These mechanisms cooperate without becoming the same operation.

### Source imports and module composition

Language-level `import` evaluates a Nix file and returns its value. If that value is a function, function application supplies arguments. NixOS `imports` instead declares module composition: the module system collects definitions and merges options according to their types and priorities.[12]

```text
Nix source files
    |
    +--> imported values / functions
    |
    +--> NixOS modules --> merged option configuration
                              |
                              v
                         derivations
```

This is not ELF linking and does not create an independent library namespace. Language-level `//` is a shallow attribute-set merge with right-hand replacement of duplicate attributes; NixOS option merging has different rules. Package lists can combine, defaults can yield to ordinary definitions, and conflicting scalar definitions can fail.[12]

### Compilers, linkers, and ELF loaders

A compiler translates source code into machine-level objects. A **linker** combines object code and resolves references to library symbols. With static linking, selected library code becomes part of the executable. With dynamic linking, the executable retains information needed to load shared libraries later.

On Linux, **ELF** is the executable and shared-library format. An ELF executable can record an interpreter path identifying the dynamic loader. Dynamic dependencies commonly appear in `DT_NEEDED` entries as library names such as `libexample.so.1`, rather than always as absolute paths. `RPATH` or `RUNPATH` entries can provide library search directories, including paths to particular Nix store outputs.[4], [5]

```text
Illustrative dynamically linked executable

interpreter: /nix/store/LOADER_A-runtime/lib/ld-linux-....so...
DT_NEEDED:   libexample.so.1
RUNPATH:     /nix/store/LIB_A-example/lib

loader search --> selected libexample.so.1 --> loaded machine code
```

Actual lookup rules distinguish `RPATH` and `RUNPATH`, and environment variables can affect lookup. Nixpkgs build hooks and tools such as `patchelf` arrange or adjust these fields. Downloaded prebuilt executables can need patching because conventional loader and library paths do not match the Nix layout.[5]

The operating-system loader follows recorded paths and its search rules. It does not recompute Nix's hash algorithm every time an application starts. The digest has already selected a filesystem location.

The following concrete route connects system command selection to that runtime lookup. All uppercase store labels remain illustrative placeholders; the exact number of filesystem-link hops varies by generated system.

```text
Selected command: /run/current-system/sw/bin/viewer
    |
    | filesystem-link resolution through the selected system environment
    v
/nix/store/APP_A-viewer/bin/viewer
    |
    | runtime file lookup: kernel reads ELF interpreter path
    v
/nix/store/LOADER_A-runtime/lib/ld-linux-....so...
    |
    | runtime file lookup: loader uses DT_NEEDED + library search directories
    v
/nix/store/LIB_A-example/lib/libexample.so.1
```

The first arrow follows filesystem links. The remaining arrows describe opening files according to executable metadata and loader rules, not symlinks inferred from dependency arrows. None of these startup steps calculates a Nix store digest.

An **ABI**, or application binary interface, is the machine-level agreement between executable components: symbol names, calling conventions, data layout, and related expectations. Distinct store paths avoid overwriting one variant with another. They do not prove ABI compatibility. Packagers remain responsible for coherent combinations, particularly when plugins or multiple library versions enter one process.

### Script interpreters and launcher environments

A script's **shebang** identifies its interpreter. A wrapper is a launcher that prepares an environment and then invokes another program. Such launchers can select command-search paths, library locations, plugin directories, or application-specific settings.[5]

```text
selected command
    |
    v
wrapper: sets application environment
    |
    v
script / executable --> interpreter / libraries / plugins
```

`PATH` controls command lookup, not all kinds of dependency lookup. A Python module path, GUI plugin path, and ELF library search path have different consumers. A wrapper can configure several of them, but setting `PATH` alone does not solve every runtime dependency.

Package-local launch settings have a narrower reach than session-wide environment variables. That distinction matters when one application needs a special display backend while the rest of the desktop retains its own settings.

### Profiles and symbolic-link trees

A profile selects an environment assembled from package outputs. Nix can construct a **symlink farm**: a directory tree whose entries point to files in the selected store objects. A generation records a particular selection, and a profile pointer chooses the current generation.[8]

```text
profile pointer
    |
    v
selected generation --> environment tree
                            |
                            +--> bin/viewer --> /nix/store/APP_A-viewer/bin/viewer
                            +--> bin/editor --> /nix/store/EDIT_A-editor/bin/editor
```

These filesystem links expose convenient command names without copying every package into one mutable installation directory. The underlying objects retain their specific identities. Two selected packages can still compete for the same exposed command name; store coexistence and profile-name collision are separate issues.

A profile-pointer replacement can be atomic: observers see the old or new pointer. NixOS activation additionally applies configuration and manages services. It is not one transaction that atomically reverses every service action, network change, or database migration.[8], [12]

## 7. Substitution, reproducibility, and trust

A **substitute** is an already-built store object obtained from another store, commonly a binary cache. For ordinary input-addressed packages, Nix can request the expected output path rather than compiling it again. A missing or unusable substitute can lead to a build when the required inputs and builder are available.[1], [9]

```text
Requested output path
    |
    +--> valid local object ----------------------------> reuse
    |
    +--> acceptable cached object ----------------------> download and register
    |
    +--> build from the derivation and inputs ----------> register result
```

The paths in this diagram are alternatives, not a guarantee that every request succeeds. A dependency may be unavailable, a cache may lack an artifact, or a build may fail.

### Integrity and producer authentication

Content hashes detect content mismatches under the applicable hashing scheme. Signatures establish that accepted metadata was signed by a trusted key. Under the normal `require-sigs` policy, copied non-content-addressed objects require an accepted trust basis; trusted keys and explicitly trusted stores affect acceptance. Content-addressed objects have a different integrity basis.[9]

Accepting a signed binary substitute does not mean the machine rebuilt the package from source and compared the bytes. The signature expresses trust in the signer. A valid content hash does not make malicious software harmless, and a signed build is not automatically compatible with every host.

Source selection, build execution, artifact integrity, and runtime security are separate trust questions:

| Question | Relevant mechanism |
| --- | --- |
| Which external source was selected? | Input declaration and lock resolution |
| Which build was requested? | Derivation and its inputs |
| Did transferred content match its recorded identity? | Content/archive integrity checks |
| Which producer is accepted? | Cache trust and signatures |
| Is the application safe and correct? | Source review, tests, vulnerability maintenance, runtime controls |

### Repeatable specifications and repeatable bytes

A function is a useful analogy: the same complete inputs should produce the same result. Nix makes many inputs explicit and can isolate builders from undeclared host dependencies. That improves reproducibility, but a recipe's intended purity is not proof that its build is deterministic.[6], [9]

**Byte-for-byte reproducibility** means independent builds produce identical output bytes under the chosen comparison. Nondeterministic timestamps embedded by tools, random values, parallel execution order, or observations of the build platform can still affect output. A normal input-addressed path can be identical even when two builds would produce different bytes.

A **build sandbox** restricts what a builder can see. Its behavior depends on platform and configuration; fixed-output fetching has special network requirements. Sandboxing reduces undeclared dependencies but is not a universal proof of hermetic execution. It is also not an application sandbox automatically applied to every installed program.[9]

A program launched from the store normally runs with the invoking account's permissions. Its immutable executable location does not prevent it from reading personal files, accessing the network, or modifying its own mutable data where authorized by the operating system.

## 8. Coexistence, running state, and retention

Store coexistence means old and new outputs can remain present simultaneously:

```text
Store:       APP_A, LIB_A, APP_B, LIB_B
Selection:   current profile --> APP_B --> LIB_B
Process:     previously started APP_A --> already mapped LIB_A
```

### Immutable results and writable application data

**Immutable** means that a registered store result is treated as fixed. An upgrade prepares another result at its own path instead of editing the existing result in place. Ordinary users cannot rewrite system-store package files. Administrative access can bypass operating-system protections, but manually modifying registered results breaks the identity and integrity assumptions on which reuse depends.[6], [11]

Immutability does not mean every application file belongs in the store. Browser bookmarks, documents, extension stores, and databases can remain writable outside it. The program's prepared files and its changing user data have different owners and lifecycles. A stored recipe is a description; its builder prepares outputs in a controlled build context before those outputs become registered results.

### Selection and already-running processes

Changing the selected profile does not rewrite an existing process's executable image or replace libraries already mapped into it. New command lookup can reach the new selection while an old process keeps running. Service restarts, application restarts, or reboot are separate transitions as appropriate.

Long-running programs can open further resources later, so mixed old/new behavior is possible when they consult mutable configuration or a changed lookup path. A clean restart is often part of an update plan, not a consequence guaranteed by changing a profile pointer.

Multiple kernel outputs can also coexist in the store and boot generations. A conventional running NixOS host uses the kernel booted for that host; retaining several kernel packages does not mean they all become the active kernel at once.

### Generations and mutable data

A system generation selects software and generated system configuration. It is not a backup of application databases, documents, secrets, or all files on disk. A rollback to older software may encounter data already migrated by newer software.[12]

```text
Generation history                 Separate mutable state

system A --> package/config A       database after migration
system B --> package/config B       browser profile and documents
```

Selecting system A again changes the software/configuration selection; it does not automatically restore the database or browser profile to the earlier contents. Reliable recovery combines retained generations with suitable source history and independent data backups.

### Garbage-collection roots

A **garbage-collection root** retains a store object. Objects reachable from roots through recorded references remain live for collection purposes. Retained profile generations are a common reason old package closures remain reachable.[8], [12]

```text
retained generation --> application --> library
                         all reachable objects retained
```

A library can remain necessary even when absent from an explicit package list, because a retained application references it. Conversely, store presence alone does not mean a package is selected or running. Garbage collection concerns reachability and retention, not an assurance that every cached application is executing or that an untrusted application is safe.

## 9. The current project's composition

The current root [flake](../flake.nix) declares Nixpkgs on `nixos-26.05` and the Firefox Nightly input. The Nightly input's Nixpkgs input follows the root Nixpkgs input. The flake's output function delegates to [system/configuration.nix](../system/configuration.nix).

```text
flake.nix
    |
    +--> inputs.nixpkgs
    +--> inputs.firefox-nightly
    |       +--> nixpkgs follows root nixpkgs
    |
    +--> outputs function --> system/configuration.nix
                                  |
                                  +--> nixosModules.desktop
                                  +--> nixosModules.default
                                  +--> optional policy modules
                                  +--> checks.x86_64-linux
```

`desktop` passes the input set under `_module.args.desktopInputs` and imports [system/desktop.nix](../system/desktop.nix). That module composes core desktop policy, Firefox, desktop features, and settings. The `default` export combines the desktop with the separately exported root-administration, power, virtualisation, and KeePass policies. The [checks](../system/checks.nix) construct consumer configurations to inspect the exported composition; they are not installed host declarations.

This is module organization. The `desktopInputs` name identifies an argument contract: the Firefox module expects that argument to contain the Nightly input. The exported desktop composition supplies it through `_module.args`. A consumer importing the Firefox file directly needs to supply the same argument contract; an import alone does not invent its external dependencies. Modules using the supplied package set and inputs participate in the surrounding composition.

### The Firefox package choice

[system/firefox.nix](../system/firefox.nix) selects the Nightly binary package for `pkgs.stdenv.hostPlatform.system` and applies `overrideAttrs`. Its wrapper arguments extend the original arguments with application-local environment settings:

- `WAYLAND_DISPLAY` is unset.
- `GDK_BACKEND` is set to `x11`.
- `MOZ_ENABLE_WAYLAND` is set to `0`.

The module supplies this package through `lib.mkDefault`, so an ordinary consumer package definition can replace the default. This option-priority behavior differs from the package-level `overrideAttrs` customization.

```text
external Nightly revision
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

A wrapper change can produce a new package derivation/output while reusing the same upstream browser download when its fixed-output source is unchanged. “Rebuild” therefore need not mean recompiling the browser. Exact work depends on the package recipe and available substitutes.

The wrapper's environment applies to the launched browser process and its children, rather than imposing those settings on the whole desktop session. This narrower responsibility matches an application-specific display-backend choice. It remains distinct from browser preferences, enterprise policies, profile data, and input revision ownership.

### Input sharing and its limits

`follows` makes a flake input refer to an existing node in the input graph. Sharing the Nixpkgs source node reduces independently selected source revisions. It does not prove ABI compatibility, force every flake to use one package-set instance, or make different platforms equivalent.[12]

Two modules receiving the same `pkgs` argument normally reuse that package set rather than cloning it per module. Separate imports of Nixpkgs, different overlays, different configuration, or a different platform can still yield different package sets and derivations from the same source revision.

```text
one locked Nixpkgs source
    |
    +--> package set for platform A, configuration X
    +--> package set for platform A, configuration Y
    +--> package set for platform B
```

Source sharing is an input-graph relationship. Package identity follows the evaluated recipes produced from that source and the chosen parameters.

## 10. Architecture choices implied by the mechanics

The following design inferences connect the mechanisms above to responsibility boundaries in the current composition.

### Responsibility rather than hash anxiety

A logical file boundary groups related source. A module boundary defines configuration composition. A package boundary defines build outputs and dependencies. An input boundary defines externally selected source and revision ownership. These boundaries can align when useful, but none automatically creates the others.

| Responsibility | Natural owning boundary | Resulting benefit |
| --- | --- | --- |
| Reusable system policy and options | NixOS module | Typed composition and consumer overrides |
| Executable contents, dependencies, and launch environment | Package recipe/output | Explicit build and runtime relationships |
| External source revision and refresh policy | Flake input and consuming lock | Reviewable source selection |
| Reusable data such as application settings | Supported data source and its adapter | Data remains independently understandable |
| Accounts, disks, boot configuration, and installation identity | Host-local composition | Shared desktop policy stays portable |
| Application databases and documents | Mutable-state ownership and backup | Recovery covers data as well as software |

Moving a package expression to another file can improve readability without changing a single store identity. Keeping two unrelated responsibilities in one file does not make their results share a package identity either. Useful decomposition follows change cadence, reuse, and clear ownership.

### Local overrides and overlays

A local package override customizes a selected value. An **overlay** changes attributes in a package set and can affect dependents that obtain those attributes through that set.[5], [12]

```text
application-local selection        shared package-set policy

one browser wrapper                replacement library in pkgs
    |                                  |
    v                                  +--> application A
one selected package                   +--> application B
                                       +--> further dependents
```

The current Firefox wrapper is an example of narrow application customization. A package-set-wide replacement has a larger potential rebuild and compatibility radius. Neither mechanism changes the basic rule that actual dependency edges determine propagation.

A shared replacement is appropriate when consistency across consumers is the intended policy. A local override is appropriate when a special variant belongs to one selection. The choice concerns intended reach, not an attempt to avoid Nix's hashes.

### External revision ownership

A NixOS module cannot automatically add literal root-flake `inputs` declarations simply by being imported. Root input resolution happens at the flake interface; module evaluation consumes supplied values later. Packaging a feature behind a separate flake can give that flake its own external inputs, but introduces a separate source/version boundary and consumer lock relationship.

For Firefox, revision selection belongs to the root input declaration and consumer lock, dependency delivery belongs to the composition's `desktopInputs` argument, and package/wrapper selection belongs to the browser module. These responsibilities have distinct owners in the current source.

A meaningful ownership decision distinguishes:

- Browser options and application policies.
- Package contents and launcher behavior.
- External Nightly source revision and update cadence.
- Consumer acceptance, activation, and restart timing.

A file layout follows that decision. Hashes neither require every feature to become its own flake nor require every package recipe to be declared at the root.

### Data, desktop presets, and host composition

JSON settings can remain authored data when an existing adapter supports that format. Nix can read and transform such data into generated configuration. Conversion to Nix syntax is not a prerequisite for store identity, dependency tracking, or reproducible generation. The important boundary is the authored source versus generated output.

A complete reusable desktop preset can compose independently selectable policy modules. Host composition can then select the complete preset or individual exported modules while retaining its own accounts, hardware, disks, bootloader, and persistent-state decisions.

An illustrative responsibility map, not a proposed filesystem change, is:

```text
shared desktop policy
    +--> desktop features
    +--> browser integration
    +--> settings adapters --> authored JSON settings
    +--> optional operational policies

host composition
    +--> selected shared exports
    +--> machine-specific configuration
    +--> selected external revisions and acceptance policy
```

This preserves the distinction between a reusable module collection and an installed-machine configuration. Module reuse does not supply missing hardware facts or a data migration plan.

## 11. Manual updates across four kinds of state

The current [core module](../system/core.nix) sets `system.autoUpgrade.enable = false`. Its update policy remains manual. Nix's identity mechanism does not independently schedule upgrades or turn Nightly into an automatically refreshed running application.

Four states matter:

| State | Contents | What changes it |
| --- | --- | --- |
| Source checkout | Module code, package choices, input requests, settings | Reviewed source edits or source revision changes |
| Consumer lock | Resolved external source graph | Deliberate lock refresh/resolution |
| Nix store and selected generations | Realized artifacts and environment/system selections | Realization, profile selection, activation, retention policy |
| Mutable runtime/user state | Processes, sessions, browser profiles, databases | Execution, restart, service actions, user activity, migrations |

A reusable project's checkout and a machine-local consuming flake are not the same ownership layer. The consumer's lock determines the external graph resolved for that consumption. Editing or refreshing an unrelated checkout does not by itself update the running machine.

```text
manual input refresh
    |
    v
review changed locked revisions
    |
    v
realize candidate system: substitutes and/or builds
    |
    v
activation decision
    |
    v
application/service restart or reboot where required
```

Refreshing all inputs of the machine-local consuming flake requests a refresh of both Nixpkgs and Nightly in its reachable input graph, subject to explicit pins and input relationships. An unchanged upstream revision can leave a node unchanged. Selecting only Nixpkgs for refresh is a narrower operation and is not equivalent to refreshing Nightly.[12]

The lock refresh changes source selection, not activation. Realization prepares the selected results, not necessarily new running processes. Restart is a runtime transition, not a lock-file operation. These distinctions also permit review and recovery between stages; the [progressive update chapter](readme.md#9-updating-inputs-and-planning-release-upgrades) supplies the operational workflow.

`system.stateVersion` controls compatibility defaults for persistent state. It is not a package version pin, a Nightly update switch, or a substitute for input locking. Package updates and a deliberate state migration have separate ownership.[12]

## 12. A compact worked interpretation

Consider a desktop generation with a viewer and an editor sharing a library. A later source change adjusts only the viewer's wrapper environment.

```text
Earlier generation                    Candidate generation

viewer-A --> library-L                viewer-B --> library-L
editor-A --> library-L                editor-A --> library-L
```

The wrapper change can alter the viewer recipe without changing the library or editor. Existing outputs can be reused. After realization, both viewer variants can coexist in the store. Selecting the candidate generation changes the selected launcher; an already-running viewer-A can remain alive until restarted.

A different change selects a new shared library throughout the relevant package set:

```text
Earlier generation                    Candidate generation

viewer-A --> library-L                viewer-C --> library-M
editor-A --> library-L                editor-B --> library-M
```

Now both application recipes can change because both reference the changed library identity. Cached substitutes can avoid local compilation. Compatibility still depends on the recipes and tests, and a retained old generation still references library-L.

Finally, the same source can be reorganized into clearer modules without changing the resulting requested values or source inputs reaching the builds:

```text
source organization changes
    |
    v
same relevant derivations --> same selected store objects
```

These cases separate three decisions: source organization, package customization, and shared dependency policy. Nix identities make their effects explicit; they do not choose the architecture on behalf of the project's maintainers.

## Sources and reading guide

The numbered references identify the owning documentation for the mechanisms discussed. The Nix references use the 2.34 manual; the stable Nixpkgs and NixOS manuals track their current stable release. Exact package hooks and system options remain release-sensitive. Local source links describe this project's current composition, while architecture recommendations are inferences rather than upstream requirements.

1. [Store derivations and deriving paths](https://nix.dev/manual/nix/2.34/store/derivation/): recipe fields, explicit inputs, serialized `.drv` objects, output references, and placeholders.
2. [Complete store-path calculation](https://nix.dev/manual/nix/2.34/protocols/store-path.html): outer fingerprint, SHA-256 compression, Nix32, type-dependent inner calculation, and fixed-output treatment.
3. [Derivation outputs and addressing types](https://nix.dev/manual/nix/2.34/store/derivation/outputs/): output names, input addressing, fixed content addressing, and floating output distinctions.
4. [Automatic runtime dependencies, Nix Pills](https://nixos.org/guides/nix-pills/09-automatic-runtime-dependencies.html): pedagogical build/runtime distinction, NARs, accidental compiler references, and ELF paths. Its package versions and commands are historical examples rather than current operational instructions.
5. [Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/): fetchers, multiple outputs, build/fixup hooks, wrappers, overrides, and overlays. The [fixup phase](https://nixos.org/manual/nixpkgs/stable/#ssec-stdenv-fixup-phase) connects package construction to final runtime references.
6. [Building and processing outputs](https://nix.dev/manual/nix/2.34/store/building.html): input realization, builder execution, and reference scanning.
7. [String context](https://nix.dev/manual/nix/2.34/language/string-context.html): dependency information carried with interpolated strings.
8. [Profiles](https://nix.dev/manual/nix/2.34/package-management/profiles.html): environment symlink trees, generations, and atomic profile-pointer selection. The complete store-path specification in reference 2 governs the precise hash calculation rather than the profile page's simplified introductory wording.
9. [Nix configuration reference](https://nix.dev/manual/nix/2.34/command-ref/conf-file.html): `sandbox`, `require-sigs`, trusted public keys, substituters, and their configuration-dependent limits.
10. [Store paths](https://nix.dev/manual/nix/2.34/store/store-path.html): path identity and store-directory terminology.
11. [Store objects](https://nix.dev/manual/nix/2.34/store/store-object.html): the object and reference model underlying dependency closures.
12. [Progressive tutorial and its official-source guide](readme.md#appendix-d-sources-and-evidence-limits): language evaluation, flake inputs and locks, NixOS modules, update workflows, activation, recovery, and state compatibility. Relevant local explanations include [input/output ownership](readme.md#inputs-outputs-and-the-lock-file), [option merging](readme.md#merging-definitions-by-type-and-priority), and [package customization](readme.md#package-overrides-and-package-set-overlays).

[1]: https://nix.dev/manual/nix/2.34/store/derivation/
[2]: https://nix.dev/manual/nix/2.34/protocols/store-path.html
[3]: https://nix.dev/manual/nix/2.34/store/derivation/outputs/
[4]: https://nixos.org/guides/nix-pills/09-automatic-runtime-dependencies.html
[5]: https://nixos.org/manual/nixpkgs/stable/
[6]: https://nix.dev/manual/nix/2.34/store/building.html
[7]: https://nix.dev/manual/nix/2.34/language/string-context.html
[8]: https://nix.dev/manual/nix/2.34/package-management/profiles.html
[9]: https://nix.dev/manual/nix/2.34/command-ref/conf-file.html
[10]: https://nix.dev/manual/nix/2.34/store/store-path.html
[11]: https://nix.dev/manual/nix/2.34/store/store-object.html
[12]: readme.md#appendix-d-sources-and-evidence-limits
