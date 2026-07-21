import ArgumentParser
import Executable
import Foundation
import plate

struct KillSwiftPM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kill-swiftpm",
        abstract: "Inspect and kill running Swift/SwiftPM processes.",
        aliases: [
            "kill",
            "killswift"
        ]
    )

    @Option(
        name: [
            .customShort("r"),
            .long
        ],
        help: "Working directory retained for command compatibility."
    )
    var root: String?

    @Flag(
        name: .long,
        help: "Use SIGKILL immediately instead of attempting SIGTERM first."
    )
    var force: Bool = false

    @Flag(
        name: .long,
        help: "Only show the processes that would be terminated."
    )
    var dryRun: Bool = false

    func run() async throws {
        let rootPath = (
            root ?? FileManager.default.currentDirectoryPath
        ) as NSString

        let expandedRootPath = rootPath.expandingTildeInPath
        let cwdURL = URL(
            fileURLWithPath: expandedRootPath,
            isDirectory: true
        )

        print("KillSwiftPM".ansi(.bold))
        print(
            "Root: \(expandedRootPath)".ansi(.brightBlack)
        )
        print(
            "Force: " +
            (
                force
                    ? "ON".ansi(.yellow)
                    : "off".ansi(.brightBlack)
            )
        )
        print(
            "Dry run: " +
            (
                dryRun
                    ? "ON".ansi(.yellow)
                    : "off".ansi(.brightBlack)
            )
        )
        print()

        let manager = SwiftPMProcesses()

        let processes = try await manager.killAll(
            force: force,
            dryRun: dryRun,
            cwd: cwdURL
        )

        guard !processes.isEmpty else {
            return
        }

        if dryRun {
            print()
            print(
                "Dry run enabled; no signals were sent."
                    .ansi(.yellow)
            )
        }
    }
}
