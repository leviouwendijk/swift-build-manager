import ArgumentParser
import Foundation
import plate
import Executable

struct BinList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List binaries in sbm-bin."
    )

    @Flag(name: .shortAndLong, help: "Show details.")
    var detail = false

    @Option(name: [.customShort("o"), .long], help: "Destination root (defaults to ~/sbm-bin).")
    var destination: String?

    func run() throws {
        let dest = URL(fileURLWithPath: destination ?? defaultSBMBin())
        let items = try Executable.DeployedList.listBinaries(at: dest, includeDetails: detail)

        if items.isEmpty {
            print("No binaries in \(dest.path)".ansi(.yellow))
            return
        }

        if !detail {
            for i in items {
                print("• \(i.name)".ansi(.bold))
            }
            return
        }

        for i in items {
            print("\n\(i.name)".ansi(.bold))
            print("  path: \(i.path.path)".ansi(.brightBlack))
            if let m = i.metadata {
                print("  project: \(m.projectRootPath)".ansi(.brightBlack))
                print("  build:   \(m.buildType)".ansi(.brightBlack))
                print("  when:    \(m.deployedAt)".ansi(.brightBlack))
                print("  dest:    \(m.destinationRoot)".ansi(.brightBlack))
            } else {
                print("  (no metadata)".ansi(.brightBlack))
            }
        }
        print("")
    }

    private func defaultSBMBin() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/sbm-bin"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
