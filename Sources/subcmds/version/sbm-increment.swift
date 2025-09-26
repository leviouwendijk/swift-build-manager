import Foundation
import ArgumentParser
import plate

enum BumpTarget: String, ExpressibleByArgument { case repository, built }
enum BumpLevel: String, ExpressibleByArgument { case major, minor, patch }

struct Increment: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "increment",
        abstract: "Increment the project version"
    )

    @Option(name: .shortAndLong, help: "Which version to bump: repository (default) or built")
    var target: BumpTarget = .repository

    @Argument(help: "Level to bump: major | minor | patch")
    var level: BumpLevel

    func run() throws {
        let url = try BuildObjectConfiguration.traverseForBuildObjectPkl(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        var cfg = try BuildObjectConfiguration(from: url)

        func bump(_ v: inout ObjectVersion) {
            switch level {
            case .major: v = .init(major: v.major + 1, minor: 0, patch: 0)
            case .minor: v = .init(major: v.major, minor: v.minor + 1, patch: 0)
            case .patch: v = .init(major: v.major, minor: v.minor, patch: v.patch + 1)
            }
        }

        var vers = cfg.versions
        switch target {
        case .repository: bump(&vers.repository)
        case .built:      bump(&vers.built)
        }
        cfg = .init(
            uuid: cfg.uuid,
            name: cfg.name,
            types: cfg.types,
            versions: vers,
            compile: cfg.compile,
            details: cfg.details,
            author: cfg.author,
            update: cfg.update
        )
        try cfg.write(to: url)
        print("Updated \(target.rawValue) → \(versValue(vers, target))")
    }

    private func versValue(_ v: ProjectVersions, _ t: BumpTarget) -> String {
        let vv = (t == .repository) ? v.repository : v.built
        return "\(vv.major).\(vv.minor).\(vv.patch)"
    }
}
