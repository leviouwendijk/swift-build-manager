import ArgumentParser
import Foundation

struct Bin: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List binaries in sbm-bin."
    )

    @Flag(name: .shortAndLong, help: "Show details.")
    var detail = false

    func run() throws {
        seeBinaries(detail ? .detailed : .list)
    }
}
