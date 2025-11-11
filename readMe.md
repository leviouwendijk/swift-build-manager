# Swift Build Manager (`sbm`)

`sbm` is a thin CLI over the **Executable** library for building Swift packages, deploying selected executables to a dedicated `$HOME/sbm-bin` folder, exporting libraries (module interfaces & artifacts), listing/removing deployed binaries, and (optionally) constructing `.app` bundles, and build version tracking.

It simply runs Swift Package Manager under the hood.

* Keeps your own binaries in `~/sbm-bin`.
* Auto-overwrites on redeploy.
* Writes a small sidecar metadata file per deployed binary.
* Allows version tracking across builds.
* Can build with confiruable flag and option overrides.

## Install & PATH

Make sure you have a recent Swift toolchain installed.

Add the binary path to your shell if needed:

```bash
export PATH="$HOME/sbm-bin:$PATH"
```

(You can pick a different destination via option flags; `~/sbm-bin` is the default.)

---

## Commands

`sbm` is subcommand-based. The default subcommand is **build**.

```text
$ sbm --help
OVERVIEW: Swift Build Manager (thin CLI over Executable library).

USAGE: sbm <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  app                     Create/refresh a .app bundle wired to .build.
  x                       Try to execute the app bundle in this project.
  build (default)         Build a Swift package (debug/release) and optionally
                          deploy to '~/sbm-bin/'.
  lib                     Build library with module interfaces and export artifacts.
  remove                  Remove deployed binary and its metadata.
  list                    List binaries in sbm-bin.
  setup                   Setup the sbm-bin directory
  clean                   swift package clean
  pack                    SwiftPM dependency operations (update/resolve).
  config                  Manage build-object.pkl
  increment               Increment the project version
  update                  Update and rebuild the current repo
  modernize               Upgrade legacy build-object.pkl to the new schema
  version                 Show current versions (built vs repository) and repo
                          divergence
  remote                  Remote helpers (set||open)

  See 'sbm help <subcommand>' for detailed help.
```

`sbm` will write a compiled version to the compiled.pkl.

`sbm` building auto-appends the compiled.pkl to the .gitignore if they aren't found.

This is intended for update tracking with easy CLI incrementing.

Local versions are kept purely written from builds, while the remote build-object is authoritative.

That ensures that compiled version != build-object release version when the build fails.

---

## 'build-object.pkl'

Using the `sbm config` / `increment [major | minor | patch]` methods, we are interacting with a build-object.pkl configuration file.

This looks like:

```pkl
uuid = "3003BECF-B8D2-4DB6-88AD-65B018724F5F"
name = "sbm"
types {
    "binary"
}
versions {
    release {
        major = 1
        minor = 1
        patch = 8
    }
}
compile {
    use = false
    arguments {  }
}
details = "Swift Package Manager utilities (manage build objects)"
author = "Levi Ouwendijk"
update = "https://raw.githubusercontent.com/leviouwendijk/swift-build-manager/master/build-object.pkl"
```

If you frequently pass flags or options on a project, you can set up the `compile` object:

Enable it, and add an option:

```pkl
compile {
    use = true
    arguments { "--local" "--debug" }
}
```

Running purely `sbm` will now first check the compile object for any flags, and override the plain command by re-initiating the build.

Example:

```bash
$ sbm 
Detected preconfigured build instructions, intercepting build commands.
    (You provided no overriding flags or options).

    Arguments found:
    Invocation (simulated): sbm
Building for production...
[7/7] Linking sbm
Build complete! (3.47s)
compiled == release
no compiled.pkl written

Deploying sbm → /Users/leviouwendijk/sbm-bin
/Users/leviouwendijk/sbm-bin/sbm exists — replacing...
Binary replaced at /Users/leviouwendijk/sbm-bin/sbm
Metadata written: /Users/leviouwendijk/sbm-bin/sbm.metadata

        sbm is now an executable binary for swift-build-manager
```
