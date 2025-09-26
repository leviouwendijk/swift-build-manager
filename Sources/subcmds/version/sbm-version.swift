import Foundation
import ArgumentParser
import plate
import Interfaces

struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show current versions (built vs repository) and repo divergence"
    )

    func run() async throws {
        let url = try BuildObjectConfiguration.traverseForBuildObjectPkl(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        let cfg = try BuildObjectConfiguration(from: url)

        print("name: \(cfg.name)")
        print("types: \(cfg.types.map(\.rawValue).joined(separator: ", "))")
        print("versions:")
        print("  built:      \(cfg.versions.built.major).\(cfg.versions.built.minor).\(cfg.versions.built.patch)")
        print("  repository: \(cfg.versions.repository.major).\(cfg.versions.repository.minor).\(cfg.versions.repository.patch)")

        if let div = try? await GitRepo.divergence(url.deletingLastPathComponent()) {
            print("git: ahead \(div.ahead), behind \(div.behind)")
        }
    }
}
