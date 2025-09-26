import Foundation
import ArgumentParser
import Interfaces
import plate

struct Config: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage build-object.pkl",
        subcommands: [Init.self]
    )

    struct Init: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "init",
            abstract: "Create build-object.pkl in the current directory"
        )

        @Flag(name: .long, help: "Create a minimal empty file quickly")
        var empty: Bool = false

        func run() async throws {
            let dst = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("build-object.pkl")

            if FileManager.default.fileExists(atPath: dst.path) {
                throw ValidationError("build-object.pkl already exists at \(dst.path)")
            }

            if empty {
                try BuildObjectConfiguration.new(to: dst)
                print("Created empty build-object.pkl")
                return
            }

            // wizard (no readline for update; auto-fetch)
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

            print("Name:")
            let name = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            print("Types (comma-separated: binary,application,script):")
            let typesLine = (readLine() ?? "")
            let typeStrings = typesLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let types = try typeStrings.map {
                guard let t = ExecutableObjectType(rawValue: $0) else {
                    throw ValidationError("Invalid type '\($0)'. Use binary/application/script.")
                }
                return t
            }

            print("Details (optional):")
            let details = (readLine() ?? "")

            print("Author (optional, default: \(NSUserName())):")
            let authLine = (readLine() ?? "")
            let author = authLine.isEmpty ? NSUserName() : authLine

            var update = ""
            do {
                update = try await GitRepo.remoteRawBuildObjectURL(cwd, file: "build-object.pkl")
                print("Detected remote build-object URL:")
                print("  \(update)")
            } catch {
                print("note: could not auto-detect remote build-object URL: \(error)")
            }

            let cfg = BuildObjectConfiguration(
                name: name.isEmpty ? (FileManager.default.currentDirectoryPath as NSString).lastPathComponent : name,
                types: types,
                versions: .init(
                    built: ObjectVersion.default_version(for: .built),
                    repository: .init(major: 0, minor: 1, patch: 0)
                ),
                compile: .init(use: false, arguments: []),
                details: details,
                author: author,
                update: update
            )
            try cfg.write(to: dst)
            print("Created build-object.pkl")
        }
    }
}
