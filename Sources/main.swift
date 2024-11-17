import Foundation

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

// Locate the executable target name from Package.swift based on package name or first available target
func getTargetName(from directory: String) -> String? {
    let packageSwiftPath = URL(fileURLWithPath: directory).appendingPathComponent("Package.swift").path
    guard let packageContents = try? String(contentsOfFile: packageSwiftPath) else {
        print("Error: Could not read Package.swift.".ansi(.red))
        return nil
    }
    
    // Capture the package name
    let packageNameRegex = try! NSRegularExpression(pattern: #"name:\s*"([^"]+)""#, options: [])
    var packageName: String?
    if let packageMatch = packageNameRegex.firstMatch(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.utf16.count)),
       let nameRange = Range(packageMatch.range(at: 1), in: packageContents) {
        packageName = String(packageContents[nameRange])
    }

    // Capture executable target names
    let targetNameRegex = try! NSRegularExpression(pattern: #"executableTarget\s*\(\s*name:\s*"([^"]+)""#, options: [])
    var targetNames: [String] = []
    targetNameRegex.enumerateMatches(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.utf16.count)) { match, _, _ in
        if let match = match, let targetRange = Range(match.range(at: 1), in: packageContents) {
            targetNames.append(String(packageContents[targetRange]))
        }
    }

    // Return target matching package name or the first executable target
    if let packageName = packageName, targetNames.contains(packageName) {
        return packageName
    } else if !targetNames.isEmpty {
        return targetNames.first
    }
    
    print("Error: Could not locate an executable target in Package.swift.".ansi(.red))
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


