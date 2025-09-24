import ArgumentParser
import Foundation

@main
struct SBM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sbm",
        abstract: "Swift Build Manager — build, deploy, and manage Swift binaries.",
        version: "1.0",
        subcommands: [Build.self, Clean.self, Remove.self, Bin.self, Lib.self],
        defaultSubcommand: Build.self
    )
}
