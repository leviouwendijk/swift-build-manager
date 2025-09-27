import Foundation
import ArgumentParser
import plate

enum BumpTarget: String, ExpressibleByArgument { case release, compiled }
enum BumpLevel: String, ExpressibleByArgument { case major, minor, patch }

struct Increment: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "increment",
        abstract: "Increment the project version"
    )

    @Option(name: .shortAndLong, help: "Which version to bump: repository (default) or built")
    var target: BumpTarget = .release

    @Argument(help: "Level to bump: major | minor | patch")
    var level: BumpLevel

    func run() throws {
        let obj_url = try BuildObjectConfiguration.traverseForBuildObjectPkl(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        var obj = try BuildObjectConfiguration(from: obj_url)

        // let compl_url = try CompiledLocalBuildObject.traverseForCompiledObjectPkl(
        //     from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        // )
        // var compl = try CompiledLocalBuildObject(from: compl_url)

        func bump(_ v: inout ObjectVersion) {
            switch level {
            case .major: v = .init(major: v.major + 1, minor: 0, patch: 0)
            case .minor: v = .init(major: v.major, minor: v.minor + 1, patch: 0)
            case .patch: v = .init(major: v.major, minor: v.minor, patch: v.patch + 1)
            }
        }

        switch target {
        case .release:
            bump(&obj.versions.release)

            let cfg = BuildObjectConfiguration(
                uuid: obj.uuid,
                name: obj.name,
                types: obj.types,
                versions: obj.versions,
                compile: obj.compile,
                details: obj.details,
                author: obj.author,
                update: obj.update
            )
            try cfg.write(to: obj_url)
            // print("Updated \(target.rawValue) → \(versValue(obj.versions, target))")
            print("Updated \(target.rawValue) → \(obj.versions.release.string(prefixStyle: .short))")

        case .compiled:     
            // bump(&compl.version)

            // let cfg = BuildObjectConfiguration(
            //     uuid: obj.uuid,
            //     name: obj.name,
            //     types: obj.types,
            //     versions: obj.versions,
            //     compile: obj.compile,
            //     details: obj.details,
            //     author: obj.author,
            //     update: obj.update
            // )
            // try cfg.write(to: obj_url)
            // print("Updated \(target.rawValue) → \(versValue(obj.versions, target))")
            print("Do not manually increment compiled object, build in order to do so.")
        }
    }
}
