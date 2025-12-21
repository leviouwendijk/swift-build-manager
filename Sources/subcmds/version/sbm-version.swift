import Foundation
import ArgumentParser
import plate
import Interfaces
import Indentation

struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show current versions (built vs repository) and repo divergence"
    )

    func run() async throws {
        // let url = try BuildObjectConfiguration.traverseForBuildObjectPkl(
        //     from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        // )
        // let cfg = try BuildObjectConfiguration(from: url)

        let obj_url = try BuildObjectConfiguration.traverseForBuildObjectPkl(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        let obj = try BuildObjectConfiguration(from: obj_url)

        let compl_url = try CompiledLocalBuildObject.traverseForCompiledObjectPkl(
            from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )
        let compl = try CompiledLocalBuildObject(from: compl_url)

        print("name: \(obj.name)")
        print("types: \(obj.types.map(\.rawValue).joined(separator: ", "))")
        print("versions:")
        printi("compiled:   \(compl.version.string(prefixStyle: .none))")
        printi("release:    \(obj.versions.release.string(prefixStyle: .none))")

        if let div = try? await GitRepo.divergence(obj_url.deletingLastPathComponent()) {
            print("git: ahead \(div.ahead), behind \(div.behind)")
        }
    }
}
