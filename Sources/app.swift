import ArgumentParser
import Foundation

@main
struct SBM: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sbm",
        abstract: "Swift Build Manager (thin CLI over Executable library).",
        subcommands: [
            // app-bundle/
            AppContent.self,
            AppExec.self,

            // build/
            Build.self,
            Lib.self,
            Remove.self,
            BinList.self,

            // package/
            Clean.self,
            Pack.self,
            
            // version/
            Config.self,
            Increment.self,
            Update.self,
            Modernize.self,
            Version.self,
            Remote.self
        ],
        defaultSubcommand: Build.self
    )
}
