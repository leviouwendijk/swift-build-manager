import Foundation
import ArgumentParser
import Executable
import plate

struct KillSwiftPM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kill-swiftpm",
        abstract: "Inspect and kill running Swift/SwiftPM processes.",
        aliases: ["kill", "killswift"]
    )

    @Option(
        name: [.customShort("r"), .long],
        help: "Working directory used for process listing (defaults to current working directory)."
    )
    var root: String?

    @Flag(
        name: .long,
        help: "Use SIGKILL instead of SIGTERM."
    )
    var force: Bool = false

    @Flag(
        name: .long,
        help: "Dry run: only list what would be killed, without sending any signals."
    )
    var dryRun: Bool = false

    func run() async throws {
        let fm = FileManager.default
        let rootPath = root ?? fm.currentDirectoryPath
        let expandedRootPath = (rootPath as NSString).expandingTildeInPath
        let cwdURL = URL(fileURLWithPath: expandedRootPath, isDirectory: true)

        print("KillSwiftPM".ansi(.bold))
        print("Root: \(expandedRootPath)".ansi(.brightBlack))
        print("Force: \(force ? "ON".ansi(.yellow) : "off".ansi(.brightBlack))")
        print("Dry run: \(dryRun ? "ON".ansi(.yellow) : "off".ansi(.brightBlack))")
        print()

        let manager = SwiftPMProcesses()
        let processes = try await manager.list(cwd: cwdURL)

        if processes.isEmpty {
            print("No Swift/SwiftPM processes detected.".ansi(.green))
            return
        }

        print("Detected \(processes.count) Swift/SwiftPM processes:\n".ansi(.brightBlack))
        for p in processes {
            print("• pid \(p.pid)".ansi(.brightBlack) + " – " + p.commandLine.ansi(.bold))
        }
        print()

        if dryRun {
            print("Dry run enabled; no signals will be sent.".ansi(.yellow))
            print()
            _ = try await manager.killAll(force: force, dryRun: true, cwd: cwdURL)
            return
        }

        print("Sending signals…".ansi(.brightBlack))
        print()

        _ = try await manager.killAll(force: force, dryRun: false, cwd: cwdURL)
    }
}
