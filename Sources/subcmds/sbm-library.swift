import ArgumentParser
import Foundation

struct Lib: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build a package as a library (modules + .dylib/.a)."
    )

    @Flag(name: [.customShort("r"), .long], help: "Build in release mode.")
    var release = false

    @Flag(name: [.customShort("d"), .long], help: "Build in debug mode.")
    var debug = false

    @Flag(name: .long, help: "Keep artifacts locally (do not copy into sbm-bin/modules/<name>).")
    var local = false

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    func validate() throws {
        guard !(release && debug) else {
            throw ValidationError("Choose exactly one of --release/-r or --debug/-d.")
        }
    }

    func run() async throws {
        let dir = project ?? FileManager.default.currentDirectoryPath
        let buildType: BuildType = {
            if release { return .release }
            if debug   { return .debug }
            return .release
        }()
        try await buildLibrary(targetDirectory: dir, buildType: buildType, local: local)
    }
}
