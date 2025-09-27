import ArgumentParser
import Foundation
import Executable

struct Pack: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pack",
        abstract: "SwiftPM dependency operations (update/resolve).",
        subcommands: [Get.self, ResolveCmd.self],
        defaultSubcommand: Get.self
    )

    @Option(name: [.short, .long], help: "Package directory (default: current directory).")
    var dir: String?

    var packageDir: URL {
        if let d = dir { return URL(fileURLWithPath: d, isDirectory: true) }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    static let div = String(repeating: "-", count: 50)

    struct Get: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Run `swift package update` (default subcommand)."
        )

        @Option(name: [.short, .long], help: "Package directory (default: current directory).")
        var dir: String?

        @Flag(name: .customShort("b"), help: "Rebuild after updates.")
        var build: Bool = false

        mutating func run() async throws {
            let pkg = dir.map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

            // print("Updating dependencies…".ansi(.brightBlack))
            print("Checking " + "dependencies…".ansi(.bold))

            print(div)
            _ = try await Resolve.get(at: pkg)
            print(div)

            print("Dependency update complete.".ansi(.green))

            if build {
                // invoke defaults
                let cmd = try Build.parse([])
                try await cmd.run()
            }
        }
    }

    struct ResolveCmd: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "resolve",
            abstract: "Run `swift package resolve`."
        )

        @Option(name: [.short, .long], help: "Package directory (default: current directory).")
        var dir: String?

        mutating func run() async throws {
            let pkg = dir.map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

            print("Resolving package graph…".ansi(.brightBlack))
            _ = try await Resolve.resolve(at: pkg)
            print("Resolve complete.".ansi(.green))
        }
    }
}
