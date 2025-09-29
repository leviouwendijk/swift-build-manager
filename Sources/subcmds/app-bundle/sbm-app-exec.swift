import ArgumentParser
import Foundation
import Executable
import Interfaces
import plate

struct AppExec: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "x",
        abstract: "Try to execute the app bundle in this project."
    )

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    @Option(name: .long, help: "App (bundle) name. Defaults to: --app-name OR --target OR <Package.name> OR folder name.")
    var appName: String?

    @Option(name: .long, help: "Executable target name (defaults to appName). (Only used for defaulting, bundle resolution still infers from repo folder if omitted.)")
    var target: String?

    @Flag(name: .long, help: "Print what would run, then exit.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Reveal the .app in Finder instead of running it.")
    var reveal: Bool = false

    @Flag(name: .long, help: "Launch by exec'ing the bundle's binary instead of `open`.")
    var exec: Bool = false

    @Flag(name: .long, help: "When using `open`, *don't* force a new instance (-n).")
    var noNewInstance: Bool = false

    @Argument(parsing: .captureForPassthrough, help: "Arguments forwarded to the app.")
    var appArgs: [String] = []

    func run() async throws {
        let proj = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)

        let pkgName = (try? await packageName(at: proj)) ?? proj.lastPathComponent
        let resolvedName = appName ?? target ?? pkgName

        let info: Executable.AppBundleInfo
        do {
            info = try Executable.AppBundleResolver().resolve(
                directoryURL: proj,
                target: appName ?? resolvedName
            )
        } catch {
            fputs("✖ \(error.localizedDescription)\n", stderr)
            throw error
        }

        let appPath = info.appBundleURL.path
        let binPath = info.appBundleURL
            .appendingPathComponent("Contents/MacOS/\(info.executableName)")
            .path

        print("""
        App bundle: \(appPath)
        Executable: \(binPath)
        Bundle ID:  \(info.bundleIdentifier ?? "<none>")
        """.ansi(.brightBlack))

        if dryRun {
            let how = exec ? "exec" : "open"
            let argStr = appArgs.map { String(reflecting: $0) }.joined(separator: " ")
            print("[dry-run] would \(how): \(resolvedName) — args: \(argStr)".ansi(.yellow))
            return
        }

        if reveal {
            try runProcess("/usr/bin/open", ["-R", appPath])
            return
        }

        if exec {
            try runProcess(binPath, appArgs) 
        } else {
            var args: [String] = []
            if !noNewInstance { args.append("-n") }          
            args.append(appPath)
            if !appArgs.isEmpty {
                args.append("--args")
                args.append(contentsOf: appArgs)
            }
            try runProcess("/usr/bin/open", args)
        }
    }

    private func packageName(at dir: URL) async throws -> String {
        var opt = Shell.Options(); opt.cwd = dir
        let r = try await Shell(.zsh).run("/usr/bin/env", ["swift","package","dump-package"], options: opt)
        if let code = r.exitCode, code != 0 { return dir.lastPathComponent }
        let blob = SwiftPackageDumpBlob(raw: r.stdout)
        let reader = try SwiftPackageDumpReader(blob: blob)
        return reader.packageName() ?? dir.lastPathComponent
    }

    private func runProcess(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardInput = FileHandle.standardInput
        p.standardOutput = FileHandle.standardOutput
        p.standardError = FileHandle.standardError

        try p.run()
        p.waitUntilExit()

        guard p.terminationStatus == 0 else {
            throw NSError(
                domain: "sbm.x",
                code: Int(p.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Process exited with code \(p.terminationStatus)"]
            )
        }
    }
}
