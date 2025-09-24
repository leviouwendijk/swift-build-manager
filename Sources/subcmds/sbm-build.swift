import ArgumentParser
import Foundation

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Build a Swift package (debug/release) and optionally deploy to sbm-bin."
    )

    @Flag(name: [.customShort("r"), .long], help: "Build in release mode.")
    var release = false

    @Flag(name: [.customShort("d"), .long], help: "Build in debug mode.")
    var debug = false

    @Flag(name: [.customShort("l"), .long], help: "Keep artifacts in .build (no deploy).")
    var local = false

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    @Option(name: [.customShort("o"), .long], help: "Destination path for deployed binary (defaults to ~/sbm-bin).")
    var destination: String?

    func validate() throws {
        guard !(release && debug) else {
            throw ValidationError("Choose exactly one of --release/-r or --debug/-d.")
        }
    }

    func run() async throws {
        let dir = project ?? FileManager.default.currentDirectoryPath
        let dest = destination ?? setupSBMBinDirectory()

        let buildType: BuildType = {
            if release { return .release }
            if debug   { return .debug }
            return .release
        }()

        if local {
            try await buildOnly(targetDirectory: dir, buildType: buildType)
        } else {
            try await buildAndDeploy(targetDirectory: dir, buildType: buildType, destinationPath: dest)
        }
    }
}
