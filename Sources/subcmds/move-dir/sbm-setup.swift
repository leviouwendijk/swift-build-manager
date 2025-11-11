import ArgumentParser
import Foundation
import plate

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Setup the sbm-bin directory"
    )

    @Option(name: [.customShort("o"), .long], help: "Destination root (defaults to ~/sbm-bin).")
    var destination: String?

    func run() throws {
        let fm = FileManager.default

        let home = fm.homeDirectoryForCurrentUser.path
        let path = "\(home)/sbm-bin"
        let destRoot = URL(fileURLWithPath: destination ?? path)

        
        if fm.fileExists(atPath: destRoot.path) {
            let msg =
                "'\(destRoot.path)' already exists, so " + "sbm*".ansi(.bold)
                + " is properly set up."
                + "\n"
            fputs(msg, stdout)
            return 
        }

        do {
            try fm.createDirectory(at: destRoot, withIntermediateDirectories: true)
        } catch { 
            fputs(error.localizedDescription, stderr)
        }
    }
}
