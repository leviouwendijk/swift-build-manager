import ArgumentParser
import Foundation
import Executable

struct Remove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove deployed binary and its metadata."
    )

    @Option(name: [.customShort("o"), .long], help: "Destination root (defaults to ~/sbm-bin).")
    var destination: String?

    @Option(name: [.customShort("t"), .long], parsing: .upToNextOption, help: "Target(s) to remove (repeatable).")
    var target: [String]

    func run() throws {
        let destRoot = URL(fileURLWithPath: destination ?? defaultSBMBin())
        for t in target {
            try Executable.Remove.deployedBinary(named: t, at: destRoot)
        }
    }

    private func defaultSBMBin() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/sbm-bin"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
