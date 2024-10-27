import Foundation

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
    case italic = "\u{001B}[3m"
    case underline = "\u{001B}[4m"
    case black = "\u{001B}[30m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case brightBlack = "\u{001B}[90m" // or gray
    case brightRed = "\u{001B}[91m"
    case brightGreen = "\u{001B}[92m"
    case brightYellow = "\u{001B}[93m"
    case brightBlue = "\u{001B}[94m"
    case brightMagenta = "\u{001B}[95m"
    case brightCyan = "\u{001B}[96m"
    case brightWhite = "\u{001B}[97m"
}

protocol StringANSIFormattable {
    func ansi(_ colors: ANSIColor...) -> String
}

extension String: StringANSIFormattable {
    func ansi(_ colors: ANSIColor...) -> String {
        let colorCodes = colors.map { $0.rawValue }.joined()
        return "\(colorCodes)\(self)\(ANSIColor.reset.rawValue)"
    }
}

enum BuildType: String {
    case debug = "-d"
    case release = "-r"
    
    static func fromArgument(_ arg: String) -> BuildType? {
        switch arg.lowercased() {
        case "-d", "-debug":
            return .debug
        case "-r", "-release":
            return .release
        default:
            return nil
        }
    }
}

// Utility to run shell commands
@discardableResult
func runShellCommand(_ command: String, in directory: String = FileManager.default.currentDirectoryPath) -> Bool {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.currentDirectoryPath = directory
    
    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = outputPipe
    
    let outputHandle = outputPipe.fileHandleForReading
    outputHandle.readabilityHandler = { fileHandle in
        // Read data as it becomes available
        let data = fileHandle.availableData
        if let output = String(data: data, encoding: .utf8)?.ansi(.brightBlack) {
            let colorizedOutput = output
                .replacingOccurrences(of: "production", with: "production".ansi(.bold))
                .replacingOccurrences(of: "debugging", with: "debugging".ansi(.bold))
                .replacingOccurrences(of: "error", with: "error".ansi(.red))
                .replacingOccurrences(of: "Build complete!", with: "Build complete!".ansi(.green))
                .replacingOccurrences(of: "warning", with: "warning".ansi(.yellow))
            print(colorizedOutput, terminator: "")
        }
    }
    
    task.launch()
    task.waitUntilExit()
    outputHandle.readabilityHandler = nil  // Remove the handler after the task exits
    
    return task.terminationStatus == 0
}

func setupSBMBinDirectory() -> String {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    let sbmBinPath = homeDirectory.appendingPathComponent("sbm-bin").path

    if !FileManager.default.fileExists(atPath: sbmBinPath) {
        do {
            try FileManager.default.createDirectory(atPath: sbmBinPath, withIntermediateDirectories: true, attributes: nil)
            print("Created sbm-bin directory at \(sbmBinPath)")
        } catch {
            print("Error: Could not create sbm-bin directory: \(error)".ansi(.red))
            exit(1)
        }
    }

    let shellConfigPath = homeDirectory.appendingPathComponent(".zshrc").path  // Adjust for bash if needed
    let exportPathLine = "export PATH=\"$HOME/sbm-bin:$PATH\"\n"
    
    if let shellConfigContents = try? String(contentsOfFile: shellConfigPath), !shellConfigContents.contains(exportPathLine) {
        // Open the file for appending and write the export line
        if let fileHandle = FileHandle(forWritingAtPath: shellConfigPath) {
            fileHandle.seekToEndOfFile()
            if let data = exportPathLine.data(using: .utf8) {
                fileHandle.write(data)
                print("Added sbm-bin to PATH in \(shellConfigPath)")
                print("Please run 'source ~/.zshrc' to update your PATH or restart your terminal.")
            }
            fileHandle.closeFile()
        } else {
            // If unable to open, fallback to simple file append
            do {
                try exportPathLine.write(toFile: shellConfigPath, atomically: true, encoding: .utf8)
                print("Added sbm-bin to PATH in \(shellConfigPath)")
                print("Please run 'source ~/.zshrc' to update your PATH or restart your terminal.")
            } catch {
                print("Error: Could not modify \(shellConfigPath): \(error)".ansi(.red))
                exit(1)
            }
        }
    }
    
    return sbmBinPath
}

// Locate the binary target name from Package.swift
func getTargetName(from directory: String) -> String? {
    let packageSwiftPath = URL(fileURLWithPath: directory).appendingPathComponent("Package.swift").path
    guard let packageContents = try? String(contentsOfFile: packageSwiftPath) else {
        print("Error: Could not read Package.swift.".ansi(.red))
        return nil
    }
    
    // A simple regex to find the first target name in Package.swift
    let targetNameRegex = try! NSRegularExpression(pattern: #"name:\s*"(\w+)""#, options: [])
    if let match = targetNameRegex.firstMatch(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.count)) {
        if let targetRange = Range(match.range(at: 1), in: packageContents) {
            return String(packageContents[targetRange])
        }
    }
    
    print("Error: Could not locate a target name in Package.swift.".ansi(.red))
    return nil
}

func buildAndDeploy(targetDirectory: String, buildType: BuildType, destinationPath: String) {
    let buildCommand = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project...")
    guard runShellCommand(buildCommand, in: targetDirectory) else {
        print("Error: Build failed.".ansi(.red))
        return
    }

    print("") 

    print("Moving binary to " + "sbm-bin".ansi(.italic) + "...")
    let projectFolderName = URL(fileURLWithPath: targetDirectory).lastPathComponent
    guard let targetName = getTargetName(from: targetDirectory) else {
        print("Error: Could not determine target name.".ansi(.red))
        return
    }
    
    let buildPath = buildType == .debug ? ".build/debug/\(targetName)" : ".build/release/\(targetName)"
    let sourceURL = URL(fileURLWithPath: targetDirectory).appendingPathComponent(buildPath)
    let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(targetName)
    
    // Step 3: Replace the binary at the destination path
    var binaryExists: Bool = false
    var binaryPlaced: Bool = false
    do {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            binaryExists = true
            print("\(destinationURL.path)".ansi(.brightBlack, .bold) + " already exists. Replacing it...".ansi(.brightBlack))
        }
        
        if let replacedURL = try FileManager.default.replaceItemAt(destinationURL, withItemAt: sourceURL) {
            print("Binary ".ansi(.brightBlack) + ( binaryExists ? "re".ansi(.brightBlack) : "" ) + "placed at ".ansi(.brightBlack) + "\(replacedURL.path)".ansi(.bold, .brightBlack))
            binaryPlaced = true
        } else {
            print("Binary replaced, but no new URL was returned.".ansi(.brightBlack))
        }
    } catch {
        print("Error: Failed to replace binary at ".ansi(.brightBlack) + "\(destinationPath.ansi(.brightBlack, .bold)): \(error)".ansi(.red))
        return
    }
    
    // Step 4: Create metadata file with project root information
    let metadataPath = destinationURL.deletingLastPathComponent().appendingPathComponent("\(targetName).metadata")
    let metadataContent = "ProjectRootPath=\(targetDirectory)\n"
    
    do {
        try metadataContent.write(to: metadataPath, atomically: true, encoding: .utf8)
        print("Metadata file created at ".ansi(.brightBlack) + "\(metadataPath.path)".ansi(.brightBlack, .bold))
    } catch {
        print("Error: Failed to write metadata file: \(error)".ansi(.red))
        print("Ensure metadata is properly written! This ensures project root path is accessible to updates.".ansi(.red))
    }

    print("")

    let successOut = "\(targetName) ".ansi(.bold) + "is now an executable binary for " + "\(projectFolderName)".ansi(.italic)
    let successOutSpaced = """
            \(successOut)
        """
    let errorOut = "Failed to move \(targetName) binary to sbm-bin, retrace steps.".ansi(.red)

    binaryPlaced ? print(successOutSpaced) : print(errorOut)

}

enum Alignment {
    case left
    case right
}

protocol Alignable {
    func align(_ side: Alignment,_ width: Int) -> String
}

extension String: Alignable {
    func align(_ side: Alignment,_ width: Int) -> String {
        let padding = max(0, width - self.count)

        switch side {
        case .left:
            let paddedText = self + String(repeating: ".", count: padding)
            return paddedText
        case .right:
            let paddedText = String(repeating: ".", count: padding) + self
            return paddedText
        }
    }
}

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


func main() {
    print("")
    let arguments = CommandLine.arguments
    let firstArg = arguments.count >= 2 ? arguments[1] : ""

    switch firstArg { 
        case "-h", "-help":
        showAvailableCommands()
        
        default: 
            guard arguments.count >= 2 else {
                print("Usage: sbm -d|-r [project-directory] [destination-path (optional)]")
                exit(1)
            }

            guard let buildType = BuildType.fromArgument(arguments[1]) else {
                print("Invalid build type. Use -d|-debug for debug or -r|-release for release.")
                exit(1)
            }

            // Determine the project directory and destination path
            let projectDirectory = arguments.count > 2 && arguments[2].first != "-" ? arguments[2] : FileManager.default.currentDirectoryPath
            let destinationPath = arguments.count > 3 ? arguments[3] : setupSBMBinDirectory()

            buildAndDeploy(targetDirectory: projectDirectory, buildType: buildType, destinationPath: destinationPath)
    }
    print("")
}

main()

// sbm -d|-r (defaults)
// sbm -d|-r /project/path (specifying another argument will be assumed as project)
// sbm -d|-r /project/path /destination/path (specifying yet another arg will be placed as destination for binaries)




