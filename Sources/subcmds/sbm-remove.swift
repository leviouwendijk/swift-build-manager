import ArgumentParser
import Foundation

struct Remove: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove deployed binary + metadata for the package from sbm-bin."
    )

    @Option(name: [.customShort("p"), .long], help: "Project directory (defaults to CWD).")
    var project: String?

    @Option(name: [.customShort("o"), .long], help: "Destination path (defaults to ~/sbm-bin).")
    var destination: String?

    func run() async throws {
        let dir = project ?? FileManager.default.currentDirectoryPath
        let dest = destination ?? setupSBMBinDirectory()
        await removeBinaryAndMetadata(for: dir, in: dest)
    }
}
