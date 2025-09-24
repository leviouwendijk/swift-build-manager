# Swift Build Manager (`sbm`)

`sbm` is a thin, friendly CLI over the **Executable** library for building Swift packages, deploying selected executables to a dedicated `$HOME/sbm-bin` folder, exporting libraries (module interfaces & artifacts), listing/removing deployed binaries, and (optionally) constructing `.app` bundles à la `sapp`.

* Keeps your own binaries in `~/sbm-bin` (or a path you choose).
* Auto-overwrites on redeploy.
* Writes a small sidecar metadata file per deployed binary.

## Install & PATH

Make sure you have a recent Swift toolchain installed.

Add the binary path to your shell if needed:

```bash
export PATH="$HOME/sbm-bin:$PATH"
```

(You can pick a different destination via flags; `~/sbm-bin` is the default.)

---

## Commands

`sbm` is subcommand-based. The default subcommand is **build**.

```text
sbm [build] [options]             Build (and optionally deploy) executables
sbm clean [-p DIR]                swift package clean
sbm remove -t <name> [-o DIR]     Remove a deployed binary + metadata
sbm bin [-o DIR] [-d]             List deployed binaries (optionally detailed)
sbm lib [options]                 Build library & export module artifacts
sbm app [options]                 Create/refresh a .app bundle (sapp niceties)
```

---

## `build` (default)

Builds your package, then deploys selected executables to `~/sbm-bin` (or `--destination`).

```bash
sbm -r                        # release build + deploy all executables
sbm --debug --local           # debug build, no deploy
sbm -r -p /path/to/pkg        # choose project dir
sbm -r --targets diskmap  # deploy only this target
sbm -r --skip-targets DiskMapper   # deploy everything except this
sbm -r --cli-only --keep-apps     # deploy CLIs, skip “app-like” targets
sbm -r --map diskmap=$HOME/bin    # per-target custom destination
```

**Flags**

* `-r, --release` / `-d, --debug` – build configuration (default: release)
* `-l, --local` – build only (skip deploy)
* `-p, --project <DIR>` – project directory (default: CWD)
* `-o, --destination <DIR>` – deploy destination (default: `~/sbm-bin`)

**Selection**

* `--targets name[,name...]` – only deploy these
* `--skip-targets name[,name...]` – exclude these
* `--cli-only` – deploy targets whose name/path looks like a CLI (`cli`, `tool`, `cmd`)
* `--keep-apps` – keep “app-like” targets (name/path contains `app`, `application`) out of deploy
* `--map name=/path` (repeatable) – per-target destination overrides

**Metadata**

Each deployed binary gets `<name>.metadata` in the same folder:

```
ProjectRootPath=/path/to/pkg
BuildType=release|debug
DeployedAt=2025-09-24T10:03:27Z
DestinationRoot=/Users/you/sbm-bin
```

---

## `clean`

```bash
sbm clean -p /path/to/pkg
```

Runs `swift package clean` for the project.

---

## `remove`

```bash
sbm remove -t diskmap                      # from default ~/sbm-bin
sbm remove -t diskmap -o /custom/bin       # from custom destination
```

Deletes the deployed binary and its sidecar metadata if present.

**Flags**

* `-t, --target <name>` (repeatable) – which deployed binaries to remove
* `-o, --destination <DIR>` – destination root (default: `~/sbm-bin`)

---

## `bin`

```bash
sbm bin                 # list deployed binary names
sbm bin -d              # detailed view with metadata
sbm bin -o /custom/bin  # list a different destination
```

**Flags**

* `-o, --destination <DIR>` – destination root (default: `~/sbm-bin`)
* `-d, --detail` – show metadata details

---

## `lib` (library export)

Builds with flags for module interfaces / evolution and collects artifacts.

```bash
sbm lib -r                          # release lib build + export
sbm lib -r -p /path/to/pkg
sbm lib -r --local                  # build only; do not export
sbm lib -r -m $HOME/sbm-bin/modules # custom export root
```

**Flags**

* `-r, --release` / `-d, --debug`
* `-l, --local` – build only, skip export
* `-p, --project <DIR>`
* `-m, --modules-root <DIR>` – export root (default: `~/sbm-bin/modules`)

Exports typical artifacts found under `.build/<cfg>` (best-effort):
`.swiftmodule`, `.swiftdoc`, `.swiftinterface`, `.swiftsourceinfo`, `.abi.json`, `.dylib`, `.a`
into `modules/<PackageName>/`.

---

## `app` (optional, sapp niceties)

Constructs or refreshes an `.app` bundle wired to your `.build` products.

```bash
sbm app --wizard                          # interactive prompts
sbm app --target DiskMapper               # quick non-interactive
sbm app --build-type debug                # link from .build/debug
sbm app --plist ./Support/Info.plist      # link/copy Info.plist
sbm app --resources-bundle DiskMapper_Assets.bundle
sbm app --sym-resources                   # just fix Resources symlink and exit
```

**Defaults**

* **App name**: `--app-name` or `--target` or `<Package.name>` (via `dump-package`) or folder name.
* **Target**: `--target` or app name, or first executable target.
* **Info.plist**: link from common locations (`.sapp/Info.plist`, `Sources/<target>/Info.plist`, `Support/Info.plist`, `Info.plist`), else generate a minimal default.
* **Resources**: if `<App>_<App>.bundle` exists in `.build/<cfg>`, it will be linked as `Contents/Resources`.

**Flags**

* `-p, --project <DIR>` – project root (default: CWD)
* `--app-name <NAME>` – bundle name (default strategy above)
* `--target <NAME>` – executable target (defaults to app name)
* `--build-type debug|release` – default: release
* `--plist <PATH>` – explicit Info.plist to link/copy
* `--plist-symlink / --no-plist-symlink` – link (default) or copy the plist
* `--resources-bundle <NAME>` – override bundle name
* `--sym-resources` – repair Resources symlink and exit
* `--wizard` – step-by-step interactive inputs

---

## Exit codes & errors

* Build and package operations surface Swift tool errors; deploy and bundle steps emit rich, colorized messages.
* All internal errors are typed (no `NSError`), with helpful failure reasons and suggestions.

---

## Examples

Build & deploy all executables (release):

```bash
sbm -r
```

Build & deploy just a CLI named `diskmap`:

```bash
sbm -r --targets diskmap
```

Build but keep artifacts locally:

```bash
sbm -d --local
```

Export library artifacts to a custom directory:

```bash
sbm lib -r -m "$HOME/dev/modules"
```

List deployed binaries:

```bash
sbm bin -d
```

Create/refresh an `.app` bundle interactively:

```bash
sbm app --wizard
```

---

## Notes

* Destination directories are created on demand.
* Re-deploy replaces existing binaries atomically and preserves a simple metadata file.
* `.app` bundles created by `sbm app` are symlink-based shims intended for local development flows.

---
