import ArgumentParser
import Foundation
import Executable
import Interfaces
import plate

struct AppContent: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Create/refresh a .app bundle wired to .build (sapp-style)."
    )

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    @Option(name: .long, help: "App (bundle) name. Defaults to: --app-name OR --target OR <Package.name> OR folder name.")
    var appName: String?

    @Option(name: .long, help: "Executable target name (defaults to appName).")
    var target: String?

    @Option(name: .long, help: "Build type: debug|release (default: release).")
    var buildType: String = "release"

    @Option(name: .long, help: "Explicit Info.plist path to link/copy.")
    var plist: String?

    @Flag(name: .long, help: "Symlink Info.plist when --plist is provided or found (default: true). Use --no-plist-symlink to copy.")
    var plistSymlink: Bool = true

    @Option(name: .long, help: "Resources .bundle name (default: <app>_<app>.bundle if present).")
    var resourcesBundle: String?

    @Flag(name: .customLong("sym-resources"), help: "Reset Resources symlink and exit.")
    var symResources: Bool = false

    @Flag(name: .customLong("wizard"), help: "Interactive step-by-step wizard to fill in missing options.")
    var wizard: Bool = false

    func run() async throws {
        let proj = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)

        // Resolve package name (for better defaults)
        let pkgName = (try? await packageName(at: proj)) ?? proj.lastPathComponent

        // Discover executable targets (for wizard defaults / validation)
        let execTargets = (try? await awaitTargets(proj)) ?? []

        // Wizard: fill missing values interactively (only if requested)
        var (resolvedApp, resolvedTarget, resolvedMode, resolvedPlist, resolvedBundle) =
            try wizard ? runWizard(
                            project: proj, 
                            packageName: pkgName,
                            execTargets: execTargets
                        ) : 
                        resolveNonInteractive(packageName: pkgName, execTargets: execTargets)

        if let flagName = appName { resolvedApp = flagName }
        if let flagTarget = target { resolvedTarget = flagTarget }
        if let flagPlist = plist { resolvedPlist = URL(fileURLWithPath: flagPlist) }
        if let flagBundle = resourcesBundle { resolvedBundle = flagBundle }
        let mode = modeFromString(buildType) ?? resolvedMode

        let config = Executable.Build.Config(mode: mode)

        if symResources {
            try Executable.AppBundle.resetResourcesSymlink(
                appName: resolvedApp,
                at: proj,
                config: config,
                bundleName: resolvedBundle
            )
            return
        }

        let appDir = try Executable.AppBundle.createSkeleton(appName: resolvedApp, at: proj)
        let buildDir = proj.appendingPathComponent(".build/\(config.buildDirComponent)")

        try Executable.AppBundle.linkBinary(
            appName: resolvedApp,
            from: buildDir,
            into: appDir,
            targetName: resolvedTarget
        )

        try Executable.AppBundle.linkResourcesBundleIfPresent(
            appName: resolvedApp,
            from: buildDir,
            into: appDir,
            bundleName: resolvedBundle
        )

        // Info.plist
        if let explicit = resolvedPlist {
            if plistSymlink {
                try Executable.AppBundle.writeOrLinkInfoPlist(
                    appName: resolvedApp,
                    into: appDir,
                    strategy: .linkIfPresent(search: [explicit])
                )
            } else {
                // copy (by writing text would change content; we want binary-identical copy)
                // emulate "copy" by linking-or-writing with generated default OFF:
                // use a tiny utility here:
                try copyPlist(explicit, to: appDir.appendingPathComponent("Contents/Info.plist"))
                print("Copied Info.plist to \(appDir.appendingPathComponent("Contents/Info.plist").path)".ansi(.brightBlack))
            }
        } else {
            let search = [
                proj.appendingPathComponent(".sapp/Info.plist"),
                proj.appendingPathComponent("Sources/\(resolvedTarget)/Info.plist"),
                proj.appendingPathComponent("Support/Info.plist"),
                proj.appendingPathComponent("Info.plist"),
            ]
            try Executable.AppBundle.writeOrLinkInfoPlist(
                appName: resolvedApp,
                into: appDir,
                strategy: .linkOrWrite(search: search, userComponent: nil)
            )
        }

        print("\nApp bundle ready: \(proj.appendingPathComponent("\(resolvedApp).app").path)\n".ansi(.green, .bold))
    }

    private func runWizard(project: URL, packageName: String, execTargets: [String]) throws
        -> (appName: String, target: String, mode: Executable.Build.Config.Mode, plist: URL?, bundle: String?)
    {
        print("")
        print("App bundle wizard".ansi(.bold))
        print("------------------".ansi(.brightBlack))

        // App name (default: package name)
        let app = prompt("App name", default: packageName)

        // Target (default: app name if exists, else first executable, else app)
        let defaultTarget: String = {
            if execTargets.contains(app) { return app }
            return execTargets.first ?? app
        }()
        let tgt = prompt("Executable target", default: defaultTarget, suggestions: execTargets)

        // Build type
        let modeStr = prompt("Build type", default: "release", suggestions: ["release","debug"])
        let mode = modeFromString(modeStr) ?? .release

        // Resources bundle (default: <app>_<app>.bundle if exists)
        let defaultBundle = "\(app)_\(app).bundle"
        let hasDefaultBundle = FileManager.default.fileExists(atPath:
            project.appendingPathComponent(".build/\(mode == .debug ? "debug" : "release")/\(defaultBundle)").path
        )
        let bundle = prompt("Resources bundle name (optional)", default: hasDefaultBundle ? defaultBundle : "")

        // Info.plist path (optional)
        let plistPath = prompt("Explicit Info.plist path (optional)", default: "")

        print("")
        print("• app:    \(app)".ansi(.brightBlack))
        print("• target: \(tgt)".ansi(.brightBlack))
        print("• build:  \(mode == .debug ? "debug" : "release")".ansi(.brightBlack))
        if !bundle.isEmpty { print("• bundle: \(bundle)".ansi(.brightBlack)) }
        if !plistPath.isEmpty { print("• plist:  \(plistPath)".ansi(.brightBlack)) }
        print("")

        return (app, tgt, mode, plistPath.isEmpty ? nil : URL(fileURLWithPath: plistPath), bundle.isEmpty ? nil : bundle)
    }

    private func resolveNonInteractive(packageName: String, execTargets: [String])
        -> (appName: String, target: String, mode: Executable.Build.Config.Mode, plist: URL?, bundle: String?)
    {
        let name = appName ?? target ?? packageName
        let tgt = target ?? (execTargets.contains(name) ? name : (execTargets.first ?? name))
        let mode: Executable.Build.Config.Mode = .release
        return (name, tgt, mode, nil, nil)
    }

    private func awaitTargets(_ project: URL) async throws -> [String] {
        // Use library Targets if available
        do { return try await Executable.Targets.executableNames(in: project) } catch { return [] }
    }

    private func packageName(at dir: URL) async throws -> String {
        // Lightweight capture of swift package dump → name (kept local to CLI to avoid expanding Executable API)
        var opt = Shell.Options(); opt.cwd = dir
        let r = try await Shell(.zsh).run("/usr/bin/env", ["swift","package","dump-package"], options: opt)
        if let code = r.exitCode, code != 0 { return dir.lastPathComponent }
        let blob = SwiftPackageDumpBlob(raw: r.stdout)
        let reader = try SwiftPackageDumpReader(blob: blob)
        return reader.packageName() ?? dir.lastPathComponent
    }

    private func modeFromString(_ s: String) -> Executable.Build.Config.Mode? {
        switch s.lowercased() {
        case "debug": return .debug
        case "release": return .release
        default: return nil
        }
    }

    private func prompt(_ q: String, default def: String? = nil, suggestions: [String] = []) -> String {
        let sugg = suggestions.isEmpty ? "" : " " + suggestions.map{ $0.ansi(.brightBlack) }.joined(separator: ", ")
        let defTxt = def.map { " [\($0.ansi(.brightBlack))]" } ?? ""
        print("\(q)\(defTxt)\(sugg): ", terminator: "")
        if let line = readLine(), !line.trimmingCharacters(in: .whitespaces).isEmpty {
            return line.trimmingCharacters(in: .whitespaces)
        }
        return def ?? ""
    }

    private func copyPlist(_ src: URL, to dest: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: src, to: dest)
    }
}
