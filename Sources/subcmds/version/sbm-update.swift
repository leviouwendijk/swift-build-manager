import Foundation
import ArgumentParser
import Executable

struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update and rebuild the current repo"
    )

    @Flag(name: .long, help: "Abort if dirty or diverged.")
    var safe = false

    @Argument(help: "Repository directory (defaults to current working directory).")
    var directory: String?

    func run() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dir = directory.map { URL(fileURLWithPath: $0) } ?? cwd

        let obj = RenewableObject(path: dir.path)
        try await ObjectRenewer.check(object: obj, safe: safe)
    }
}
