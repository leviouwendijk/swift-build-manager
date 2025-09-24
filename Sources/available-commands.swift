import Foundation

struct Subcommand {
    let command: String
    let details: String
}

let commandWidth = 40
let detailsWidth = 60

extension Subcommand: CustomStringConvertible {
    var description: String {
        command.align(.left, commandWidth) + details.align(.right, detailsWidth) 
    }
}

let availableCommands: [Subcommand] = [
    Subcommand(command: "sbm -r", details: "Builds in release mode, places binary in '~/sbm-bin'"),
    Subcommand(command: "sbm -d", details: "Builds in debug mode, places binary in '~/sbm-bin'"),
    Subcommand(command: "sbm -r /project/path", details: "Builds release for specific project path"),
    Subcommand(command: "sbm -d /project/path", details: "Builds debug for specific project path"),
    Subcommand(command: "sbm -r /project/path /destination/path", details: "Places release build in destination"),
    Subcommand(command: "sbm -d /project/path /destination/path", details: "Places debug build in destination"),
    // Subcommand(command: "-setup", details: "Creates sbm-bin directory if not exists"), -- isolate setup to separate func?
    Subcommand(command: "-h, -help", details: "Lists available commands and usage")
]

func showAvailableCommands() {
    for command in availableCommands {
        print(command)
    }
}

// sbm -d|-r (defaults)
// sbm -d|-r /project/path (specifying another argument will be assumed as project)
// sbm -d|-r /project/path /destination/path (specifying yet another arg will be placed as destination for binaries)

