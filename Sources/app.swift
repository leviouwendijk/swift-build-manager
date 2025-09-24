import ArgumentParser
import Foundation

@main
struct SBM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sbm",
        abstract: "Swift Build Manager (thin CLI over Executable library).",
        subcommands: [
            Build.self,
            Clean.self,
            Remove.self,
            Lib.self,
            AppContent.self,
            BinList.self
        ],
        defaultSubcommand: Build.self
    )
}
