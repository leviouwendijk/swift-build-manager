# Swift Build Manager (`sbm`)

## Why

Doing quick back-to-back builds, testing your targets, moving them around... Did I tire you yet?

I just want the Swift compiler to build my target, and most of the time I want one of two things:
1. to immediately execute it
2. to keep it around and make an app bundle around it

For immediate execution, I don't want to dig the path up through the .build/ directory. No, if I built `sbm` as a target, I just want to invoke it with `sbm`. Thus, `sbm` moves your targets (or your specified selected target(s)) into a `<home-dir>/sbm-bin/sbm*`. We add that to our shell path once. That way all your binaries (that you want to use) live there, and you can run them immediately. No thinking about build locations.

For app bundles, you can just pass a --local flag, or (even handier) describe the package once in a `package.frame` beside `Package.swift` (`sbm config init` writes one), so a flagless `sbm` builds and deploys the way you want. You can see examples below.

It also has a very basic way to create a `<target>.app/` bundle, and a handy `sbm x` (executed) command, so that you can quickly make long-running lifecycle applications run directly from your terminal and your project. Again, no Xcode required--(yes, adding vim-mode was certainly very nice, but neovim exists.)


## What is it

`sbm` is a thin CLI over the **Executable** library for building Swift packages, deploying selected executables to a dedicated `$HOME/sbm-bin` folder, exporting libraries (module interfaces & artifacts), listing/removing deployed binaries, constructing in-repo `.app` bundles with symlinking, and build version tracking.

It simply runs Swift Package Manager under the hood.

* Keeps your own binaries in `~/sbm-bin`.
* Auto-overwrites on redeploy.
* Writes a small sidecar metadata file per deployed binary.
* Allows version tracking across builds.
* Can build with configurable flag and option overrides.

## Install & PATH

Make sure you have a recent Swift toolchain installed.

Add the binary path to your shell if needed:

```bash
export PATH="$HOME/sbm-bin:$PATH"
```

(You can pick a different destination via option flags; `~/sbm-bin` is the default.)

---

## Commands

`sbm` is subcommand-based. The default subcommand is **build**: a bare `sbm` builds the package you are in.

```text
build (default)   build; deploy what package.frame's .deploy names to ~/sbm-bin
test              run the Tests/ package's products (debug)
bench             run the Benchmarks/ package's products (release)
clean             swift package clean
wipe              delete .build and .index-build (all, main, extra; -r below a root)
wipe caches -y    purge SwiftPM's global cache
keep              packages whose caches wipe leaves alone (.config/sbm/keep.frame)
pack              swift package update (-b then builds, -t tests)
version           release tag, HEAD, and what each deployed product was built from
increment         tag HEAD with the next release (major | minor | patch) and push it
release           tag an exact release version
config init       write package.frame (and Tests/package.frame)
modernize         migrate a legacy build-object.pkl to package.frame
list / remove     binaries in ~/sbm-bin
app / x           .app bundles wired to .build
lib               export a library's module interfaces and artifacts
```

See `sbm <subcommand> --help` for the flags.

---

## package.frame

Every package sbm works with has a `package.frame` beside its `Package.swift`. Its binding says what the package is.

```frame
import Executable;

let package: Package = .{
    .build = .{ .arguments = ["--skip-products", "tool_debug"] },
    .deploy = .{ .products = ["tool"] },
    .wipe = .{ .above = .gigabytes(4) },
};
```

- A flagless `sbm` builds with `.build.arguments` and deploys the `.deploy` products. Without `.deploy`, nothing is deployed. A library is `let package: Package = .{};`.
- Build flags you pass yourself (`-d`, `--products`, `-l`, …) replace package.frame for that run. `-t`, `-b`, `--bench` and the tidy flags below don't: `sbm -t` still builds and deploys as package.frame says.
- Tests and benchmarks are nested packages, `Tests/` and `Benchmarks/`, each with its own `package.frame`: `let tests: Tests = .{ .primary = "t_tool" };`, `let benchmarks: Benchmarks = .{ … };`.

## Versions

Releases are git tags (`1.2.3`). `sbm increment patch` tags HEAD with the next one and pushes it, and `sbm release 1.3.0` tags an exact one. Both refuse a dirty or unpushed HEAD. A deploy writes `~/sbm-bin/<product>.metadata` with the release, the commit and whether the tree was dirty, and `sbm version` compares them with the repository.

## Around a build: tests, benchmarks, disk

```text
sbm -t                      run the tests first; a failure stops the build and deploy
sbm --bench                 run the benchmarks after the build (no short form)
sbm pack -b -t --bench      update, test, build, benchmark
--clean / --wipe            after the command (on build, test, bench and pack)
--clean-before / --wipe-before
```

`--wipe` deletes the `.build` and `.index-build` of the packages the command used. The build's root, plus `Tests/` with `-t` and `Benchmarks/` with `--bench`. A `.wipe = .{ .above = .gigabytes(4) }` in any package.frame does the same automatically after a successful run, once that package's caches grow past the size (`.kilobytes`, `.megabytes`, `.gigabytes`, `.terabytes`).

`sbm wipe` on its own:

```text
sbm wipe            the package with its Tests/ and Benchmarks/
sbm wipe main       the package only
sbm wipe extra      Tests/ and Benchmarks/ only (confirmed by their package.frame)
  -r [root] [-d N]  every package below root
  -n                dry run with sizes and a total
  -y                no questions
sbm wipe caches -y  SwiftPM's global cache
```

Wipe never deletes under a running SwiftPM build, and skips what the keep list names:

```frame
import Executable;

let io: Keep = .{ .packages = ["~/code/IO"], .caches = ["build"], .reason = "slow rebuilds" };
```

`sbm keep add [path]`, `sbm keep rm [name]`, `sbm keep check`, `sbm keep` (list). The file is `~/.config/sbm/keep.frame`. It is read from every configuration root.
