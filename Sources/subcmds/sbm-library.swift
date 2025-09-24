import ArgumentParser
import Foundation
import Executable

struct Lib: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lib",
        abstract: "Build library with module interfaces and export artifacts."
    )

    @Flag(name: [.customShort("r"), .long], help: "Build in release mode.")
    var release = false

    @Flag(name: [.customShort("d"), .long], help: "Build in debug mode.")
    var debug = false

    @Flag(name: [.customShort("l"), .long], help: "Keep artifacts local (.build) — no export.")
    var local = false

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    @Option(name: [.customShort("m"), .long], help: "Modules root (defaults to ~/sbm-bin/modules).")
    var modulesRoot: String?

    func validate() throws {
        guard !(release && debug) else { throw ValidationError("Choose exactly one of --release or --debug.") }
    }

    func run() async throws {
        let dirURL = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
        let mode: Executable.Build.Config.Mode = (debug ? .debug : .release)
        let config = Executable.Build.Config(mode: mode)
        let modules = URL(fileURLWithPath: modulesRoot ?? defaultModulesRoot())

        _ = try await Executable.BuildLibrary.buildAndExport(
            at: dirURL,
            config: config,
            local: local,
            modulesRoot: modules
        )
    }

    private func defaultModulesRoot() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/sbm-bin/modules"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
