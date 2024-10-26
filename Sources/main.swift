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
func runShellCommand(_ command: String, in directory: String) -> Bool {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.currentDirectoryPath = directory
    task.launch()
    task.waitUntilExit()
    
    return task.terminationStatus == 0
}

// Locate the binary target name from Package.swift
func getTargetName(from directory: String) -> String? {
    let packageSwiftPath = URL(fileURLWithPath: directory).appendingPathComponent("Package.swift").path
    guard let packageContents = try? String(contentsOfFile: packageSwiftPath) else {
        print("Error: Could not read Package.swift.")
        return nil
    }
    
    // A simple regex to find the first target name in Package.swift
    let targetNameRegex = try! NSRegularExpression(pattern: #"name:\s*"(\w+)""#, options: [])
    if let match = targetNameRegex.firstMatch(in: packageContents, options: [], range: NSRange(location: 0, length: packageContents.count)) {
        if let targetRange = Range(match.range(at: 1), in: packageContents) {
            return String(packageContents[targetRange])
        }
    }
    
    print("Error: Could not locate a target name in Package.swift.")
    return nil
}

func buildAndDeploy(targetDirectory: String, buildType: BuildType, destinationPath: String) {
    // Step 1: Build the project
    let buildCommand = buildType == .debug ? "swift build -c debug" : "swift build -c release"
    print("Building project...")
    guard runShellCommand(buildCommand, in: targetDirectory) else {
        print("Error: Build failed.")
        return
    }
    
    // Step 2: Locate the binary
    guard let targetName = getTargetName(from: targetDirectory) else {
        print("Error: Could not determine target name.")
        return
    }
    
    let buildPath = buildType == .debug ? ".build/debug/\(targetName)" : ".build/release/\(targetName)"
    let sourcePath = URL(fileURLWithPath: targetDirectory).appendingPathComponent(buildPath).path
    
    // Step 3: Copy the binary to the destination path
    do {
        let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(targetName)
        try FileManager.default.copyItem(atPath: sourcePath, toPath: destinationURL.path)
        print("Binary copied to \(destinationURL.path)")
    } catch {
        print("Error: Failed to copy binary to \(destinationPath): \(error)")
    }
}

func main() {
    // Main execution
    let arguments = CommandLine.arguments

    // Check and parse build type
    guard arguments.count >= 2 else {
        print("Usage: sbm -d|-r [project-directory] [destination-path (optional, defaults to /usr/local/bin)]")
        exit(1)
    }

    guard let buildType = BuildType.fromArgument(arguments[1]) else {
        print("Invalid build type. Use -d|-debug for debug or -r|-release for release.")
        exit(1)
    }

    // Determine the project directory and destination path
    let projectDirectory = arguments.count > 2 && arguments[2].first != "-" ? arguments[2] : FileManager.default.currentDirectoryPath
    let destinationPath = arguments.count > 3 || (arguments.count > 2 && arguments[2].first == "-") ? arguments.last! : "/usr/local/bin"

    buildAndDeploy(targetDirectory: projectDirectory, buildType: buildType, destinationPath: destinationPath)
}

// sbm -d|-r (defaults)
// sbm -d|-r /project/path (specifying another argument will be assumed as project)
// sbm -d|-r /project/path /destination/path (specifying yet another arg will be placed as destination for binaries)




