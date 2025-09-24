import ArgumentParser
import Foundation

struct Clean: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clean build artifacts (swift package clean)."
    )

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    func run() async throws {
        let dir = project ?? FileManager.default.currentDirectoryPath
        try await cleanBuild(for: dir)
    }
}
