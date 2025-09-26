import Foundation
import ArgumentParser
import plate
import Interfaces

struct Remote: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote",
        abstract: "Populate `update` with the remote build-object URL if missing."
    )

    @Flag(name: .long, help: "Overwrite an existing non-empty update URL.")
    var force = false

    func run() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let pklURL = try BuildObjectConfiguration.traverseForBuildObjectPkl(from: cwd)
        var cfg = try BuildObjectConfiguration(from: pklURL)

        if !force, !cfg.update.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("update already set; use --force to overwrite.")
            return
        }

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
