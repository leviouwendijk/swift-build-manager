import Foundation
import ArgumentParser
import plate
import Interfaces

struct Remote: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote",
        abstract: "Remote helpers (set||open)",
        subcommands: [Set.self, Open.self]
    )

    // @Flag(name: .long, help: "Overwrite an existing non-empty update URL.")
    // var force = false

    // func run() async throws {
    //     let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    //     let pklURL = try BuildObjectConfiguration.traverseForBuildObjectPkl(from: cwd)
    //     var cfg = try BuildObjectConfiguration(from: pklURL)

    //     if !force, !cfg.update.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    //         print("update already set; use --force to overwrite.")
    //         return
    //     }

    //     let urlString = try await GitRepo.remoteRawBuildObjectURL(cwd, file: "build-object.pkl")

    //     cfg = .init(
    //         uuid: cfg.uuid,
    //         name: cfg.name,
    //         types: cfg.types,
    //         versions: cfg.versions,
    //         compile: cfg.compile,
    //         details: cfg.details,
    //         author: cfg.author,
    //         update: urlString
    //     )
    //     try cfg.write(to: pklURL)
    //     print("update set to: \(urlString)")
    // }

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Populate `update` with the remote raw build-object URL if missing (use --force to overwrite)."
        )

        @Flag(name: .long, help: "Overwrite an existing non-empty update URL.")
        var force = false

        @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
        var project: String?

        func run() async throws {
            let cwd = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
            let pklURL = try BuildObjectConfiguration.traverseForBuildObjectPkl(from: cwd)
            var cfg = try BuildObjectConfiguration(from: pklURL)

            if !force, !cfg.update.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("update already set; use --force to overwrite.")
                return
            }

            // Back-compat: use the raw file URL builder
            let urlString = try await GitRepo.remoteRawBuildObjectURL(cwd, file: "build-object.pkl")

            cfg = .init(
                uuid: cfg.uuid,
                name: cfg.name,
                types: cfg.types,
                versions: cfg.versions,
                compile: cfg.compile,
                details: cfg.details,
                author: cfg.author,
                update: urlString
            )
            try cfg.write(to: pklURL)
            print("update set to: \(urlString)")
        }
    }

    struct Open: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "open",
            abstract: "Open the repository's remote in the default browser."
        )

        @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
        var project: String?

        @Option(name: [.customShort("r"), .long], help: "Remote name (default: origin).")
        var remote: String = "origin"

        @Option(name: .long, help: "Optional repo path to open (e.g. issues, pulls).")
        var path: String?

        @Flag(name: .long, help: "Open the current branch tree page.")
        var branch = false

        @Option(name: .long, help: "Explicit ref/branch to use with --branch (overrides default).")
        var ref: String?

        mutating func run() async throws {
            let dir = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)

            let url = try await GitRepo.repoWebURL(
                directoryURL: dir,
                remoteName: remote,
                path: path.map { [$0] } ?? [],
                useBranchTree: branch,
                ref: ref
            )

            try openInBrowser(url)
            print("Opened \(url.absoluteString)")
        }

        private func openInBrowser(_ url: URL) throws {
            #if os(macOS)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = [url.absoluteString]
            try p.run()
            #else
            let candidates = ["/usr/bin/xdg-open", "/usr/bin/gnome-open"]
            guard let exe = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                throw ValidationError("Cannot locate a system opener for URLs.")
            }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = [url.absoluteString]
            try p.run()
            #endif
        }
    }
}
