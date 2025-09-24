import ArgumentParser
import Foundation
import Executable

struct Clean: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "swift package clean"
    )

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    func run() async throws {
        let dirURL = URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath)
        try await Executable.Build.clean(at: dirURL)
    }
}
